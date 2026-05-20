from datetime import date, datetime
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.exc import IntegrityError
from app.models.client import Client
from app.models.master import Master
from app.models.service import Service
from app.models.booking import Booking
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.logger import logger
from app.config import settings

class BookingService:
    def __init__(self, session: AsyncSession, bot=None):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.bot = bot

    async def create_booking(self, telegram_id: int, chat_id: int, username: str | None, first_name: str | None, last_name: str | None, service_id: int, master_id: int, booking_date: str, booking_time: str):
        try:
            logger.info(f"Booking: tg={telegram_id}, slot={booking_date} {booking_time}")
            today = date.today().isoformat()
            if booking_date < today:
                raise ValueError("Нельзя записаться на прошедшую дату")
            if booking_date == today:
                now = datetime.now().strftime("%H:%M")
                if booking_time <= now:
                    raise ValueError("Нельзя записаться на прошедшее время")

            existing = await self.booking_repo.get_slot_booking(master_id=master_id, date=booking_date, time=booking_time)
            if existing:
                raise ValueError("Слот уже занят")

            client = await self.client_repo.get_by_telegram_id(telegram_id)
            if not client:
                client = Client(telegram_id=telegram_id, chat_id=chat_id, username=username, first_name=first_name, last_name=last_name)
                self.session.add(client)
                await self.session.flush()

            master = (await self.session.execute(select(Master).where(Master.id == master_id))).scalar_one_or_none()
            if not master:
                raise ValueError("Мастер не найден")
            service = (await self.session.execute(select(Service).where(Service.id == service_id))).scalar_one_or_none()
            if not service:
                raise ValueError("Услуга не найдена")

            booking = Booking(client_id=client.id, master_id=master.id, service_id=service.id, date=booking_date, time=booking_time)
            await self.booking_repo.create(booking)
            client.total_visits = (client.total_visits or 0) + 1
            await self.session.commit()

            logger.info(f"Booking created: {booking.id}")

            # Уведомление админу
            if self.bot:
                client_name = first_name or username or f"ID:{telegram_id}"
                for admin_id in settings.ADMIN_IDS:
                    try:
                        await self.bot.send_message(
                            admin_id,
                            f"🔔 <b>Новая запись!</b>\n\n"
                            f"👤 Клиент: {client_name}\n"
                            f"💇 Мастер: {master.name}\n"
                            f"✂️ Услуга: {service.name}\n"
                            f"📅 Дата: {booking_date}\n"
                            f"🕐 Время: {booking_time}\n"
                            f"💰 Цена: {service.price}₽\n"
                            f"🆔 Запись #{booking.id}"
                        )
                    except Exception as e:
                        logger.error(f"Не удалось отправить уведомление админу {admin_id}: {e}")

                # Уведомление клиенту
                try:
                    await self.bot.send_message(
                        chat_id,
                        f"✅ <b>Запись подтверждена!</b>\n\n"
                        f"💇 Мастер: {master.name}\n"
                        f"✂️ Услуга: {service.name}\n"
                        f"📅 Дата: {booking_date}\n"
                        f"🕐 Время: {booking_time}\n"
                        f"💰 Цена: {service.price}₽\n\n"
                        f"📍 ул. Чернышевского, 52Б\n"
                        f"🆔 Запись #{booking.id}"
                    )
                except Exception as e:
                    logger.error(f"Не удалось отправить уведомление клиенту: {e}")

            return {
                "ok": True, "booking_id": booking.id,
                "master": master.name, "service": service.name,
                "price": service.price, "date": booking.date, "time": booking.time
            }
        except IntegrityError:
            await self.session.rollback()
            raise ValueError("Слот уже занят")
        except ValueError:
            await self.session.rollback()
            raise
        except Exception as e:
            await self.session.rollback()
            logger.exception(e)
            raise
