from datetime import date, datetime
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.master_repo import MasterRepository
from app.repositories.service_repo import ServiceRepository
from app.config import settings
from app.logger import logger
from app.services.notification_service import NotificationService

class BookingService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.master_repo = MasterRepository(session)
        self.service_repo = ServiceRepository(session)

    async def create_booking(self, telegram_id: int, chat_id: int, username: str | None, first_name: str | None, last_name: str | None, service_id: int, master_id: int, booking_date: str, booking_time: str):
        today = date.today().isoformat()
        if booking_date < today:
            raise ValueError("Нельзя записаться на прошедшую дату")
        if booking_date == today:
            now = datetime.now().strftime("%H:%M")
            if booking_time <= now:
                raise ValueError("Нельзя записаться на прошедшее время")
        client = await self.client_repo.get_or_create(telegram_id=telegram_id, chat_id=chat_id, username=username, first_name=first_name, last_name=last_name)
        active_count = await self.booking_repo.get_active_count(client.id)
        if active_count >= settings.MAX_ACTIVE_BOOKINGS:
            raise ValueError(f"У вас уже {active_count} активных записей. Максимум: {settings.MAX_ACTIVE_BOOKINGS}")
        existing = await self.booking_repo.get_slot_booking(master_id, booking_date, booking_time)
        if existing:
            raise ValueError("Слот уже занят")
        master = await self.master_repo.get_by_id(master_id)
        if not master or not master.is_active:
            raise ValueError("Мастер не найден или неактивен")
        service = await self.service_repo.get_by_id(service_id)
        if not service or not service.is_active:
            raise ValueError("Услуга не найдена или неактивна")
        booking = Booking(client_id=client.id, master_id=master.id, service_id=service.id, date=booking_date, time=booking_time)
        await self.booking_repo.create(booking)
        await self.client_repo.increment_visits(client.id)
        await self.session.commit()
        await self.session.refresh(booking)
        await self.session.refresh(booking, ["client", "master", "service"])
        await NotificationService.notify_admin_new_booking(booking)
        await NotificationService.notify_client_confirmation(booking)
        await NotificationService.schedule_reminders(booking)
        logger.info(f"Запись создана: #{booking.id}, клиент: {telegram_id}")
        return {"ok": True, "booking_id": booking.id, "master": master.name, "service": service.name, "price": service.price, "date": booking.date, "time": booking.time}

    async def cancel_booking(self, booking_id: int, telegram_id: int, is_admin: bool = False):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.status != "confirmed":
            raise ValueError("Запись уже отменена")
        if not is_admin:
            client = await self.client_repo.get_by_telegram_id(telegram_id)
            if not client or booking.client_id != client.id:
                raise ValueError("Это не ваша запись")
        reason = "admin_cancel" if is_admin else "client_cancel"
        await self.booking_repo.cancel(booking_id, reason)
        await NotificationService.remove_reminders(booking_id)
        await self.session.commit()
        logger.info(f"Запись #{booking_id} отменена, причина: {reason}")
        return {"ok": True, "message": "Запись отменена"}
