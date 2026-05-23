import logging, sys
from app.config import settings

def setup_logger():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s", handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler("bot.log", encoding="utf-8")])
    return logging.getLogger("barbershop")

logger = setup_logger()

def audit_log(action: str, admin_id: int, details: str = ""):
    logger.info(f"AUDIT | admin={admin_id} | {action} | {details}")
