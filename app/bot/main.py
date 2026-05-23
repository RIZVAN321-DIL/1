import asyncio, sys
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.bot.handlers.start import router as start_router
from app.logger import logger

async def main():
    logger.info("Bot starting...")
    bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
    dp = Dispatcher()
    dp.include_router(start_router)
    logger.info("Bot ready")
    await dp.start_polling(bot, drop_pending_updates=True)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped")
    except Exception as e:
        logger.exception(f"Fatal error: {e}")
        sys.exit(1)
