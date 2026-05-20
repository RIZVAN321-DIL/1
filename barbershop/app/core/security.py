import hmac
import hashlib
from app.config import settings

def verify_telegram_data(init_data: str) -> bool:
    """Проверяет подлинность данных от Telegram Mini App"""
    try:
        parsed = {}
        for item in init_data.split("&"):
            if "=" in item:
                key, value = item.split("=", 1)
                parsed[key] = value
        
        received_hash = parsed.pop("hash", None)
        if not received_hash:
            return False
        
        data_check_string = "\n".join(f"{k}={v}" for k, v in sorted(parsed.items()))
        secret_key = hmac.new("WebAppData".encode(), settings.BOT_TOKEN.encode(), hashlib.sha256).digest()
        calculated_hash = hmac.new(secret_key, data_check_string.encode(), hashlib.sha256).hexdigest()
        
        return hmac.compare_digest(calculated_hash, received_hash)
    except Exception:
        return False
