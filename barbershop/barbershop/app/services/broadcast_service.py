import asyncio
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.repositories.client_repo import ClientRepository
from app.logger import logger

class BroadcastService:
    @staticmethod
    async def send_broadcast(text: str, session):
        client_repo = ClientRepository(session)
        all_ids = await client_repo.get_all_telegram_ids()
        bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
        success = 0
        failed = 0
        for tg_id in all_ids:
            try:
                await bot.send_message(tg_id, text)
                success += 1
                await asyncio.sleep(0.05)
            except Exception as e:
                logger.error(f"Ошибка отправки {tg_id}: {e}")
                failed += 1
        await bot.session.close()
        logger.info(f"Рассылка завершена: {success} ок, {failed} ошибок")
        return {"ok": True, "sent": success, "failed": failed}
