from datetime import datetime, timedelta
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.core.scheduler import scheduler
from app.logger import logger

reminder_jobs: dict[int, list[str]] = {}

class NotificationService:
    @staticmethod
    async def get_bot() -> Bot:
        return Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))

    @classmethod
    async def notify_admin_new_booking(cls, booking):
        try:
            bot = await cls.get_bot()
            text = f"🔔 <b>Новая запись!</b>\nКлиент: {booking.client.first_name or '—'} (@{booking.client.username or '—'})\nМастер: {booking.master.name}\nУслуга: {booking.service.name}\nДата: {booking.date}\nВремя: {booking.time}\nЦена: {booking.service.price}₽"
            for admin_id in settings.ADMIN_IDS:
                await bot.send_message(admin_id, text)
            if booking.master.telegram_id:
                try:
                    await bot.send_message(booking.master.telegram_id, text)
                except Exception as e:
                    logger.error(f"Ошибка уведомления мастеру {booking.master.telegram_id}: {e}")
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления админу: {e}")

    @classmethod
    async def notify_client_confirmation(cls, booking):
        try:
            bot = await cls.get_bot()
            text = f"✅ <b>Запись подтверждена!</b>\n\nУслуга: {booking.service.name}\nМастер: {booking.master.name}\nДата: {booking.date}\nВремя: {booking.time}\nЦена: {booking.service.price}₽\n\n📍 ул. Чернышевского, 52Б"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления клиенту: {e}")

    @classmethod
    async def notify_master_day_off(cls, booking, reason: str):
        try:
            bot = await cls.get_bot()
            text = f"😔 <b>К сожалению, мастер {booking.master.name} не сможет вас принять {booking.date} в {booking.time}.</b>\n\nПричина: {reason or 'Выходной день мастера'}\n\nПожалуйста, запишитесь на другую дату через бота.\nПриносим извинения!"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления о выходном: {e}")

    @classmethod
    async def schedule_reminders(cls, booking):
        try:
            dt = datetime.strptime(f"{booking.date} {booking.time}", "%Y-%m-%d %H:%M")
            reminder_24h = dt - timedelta(hours=24)
            reminder_2h = dt - timedelta(hours=2)
            now = datetime.now()
            job_ids = []
            if reminder_24h > now:
                job_24 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_24h, args=[booking.id, 24], misfire_grace_time=300)
                job_ids.append(job_24.id)
            if reminder_2h > now:
                job_2 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_2h, args=[booking.id, 2], misfire_grace_time=300)
                job_ids.append(job_2.id)
            if job_ids:
                reminder_jobs[booking.id] = job_ids
                logger.info(f"Напоминания для #{booking.id}: {len(job_ids)} шт.")
        except Exception as e:
            logger.error(f"Ошибка планирования напоминаний: {e}")

    @classmethod
    async def remove_reminders(cls, booking_id: int):
        job_ids = reminder_jobs.pop(booking_id, [])
        for job_id in job_ids:
            try:
                scheduler.remove_job(job_id)
            except Exception:
                pass

    @classmethod
    async def _send_reminder(cls, booking_id: int, hours: int):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            booking = await repo.get_by_id(booking_id)
            if not booking or booking.status != "confirmed":
                return
            try:
                bot = await cls.get_bot()
                if hours == 24:
                    text = f"🔔 <b>Напоминаем!</b>\n\nЗавтра в {booking.time} у вас запись к {booking.master.name}.\nУслуга: {booking.service.name}\n📍 ул. Чернышевского, 52Б"
                else:
                    text = f"⏰ <b>Запись через 2 часа!</b>\n\nСегодня в {booking.time}, мастер: {booking.master.name}\nУслуга: {booking.service.name}\n📍 ул. Чернышевского, 52Б"
                await bot.send_message(booking.client.telegram_id, text)
                await bot.session.close()
                await repo.mark_reminder_sent(booking_id)
                await session.commit()
            except Exception as e:
                logger.error(f"Ошибка отправки напоминания: {e}")

    @classmethod
    async def restore_reminders(cls):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            bookings = await repo.get_upcoming_confirmed()
            for b in bookings:
                await cls.schedule_reminders(b)
            logger.info(f"Восстановлено напоминаний для {len(bookings)} записей")
