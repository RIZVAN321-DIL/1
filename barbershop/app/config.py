from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator

class Settings(BaseSettings):
    BOT_TOKEN: str
    DATABASE_URL: str = "sqlite+aiosqlite:///./barbershop.db"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 7860
    BASE_URL: str
    ADMIN_IDS: list[int] = []
    SECRET_KEY: str = "change-me"
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str):
            return [int(x.strip()) for x in value.split(",") if x.strip()]
        return value

settings = Settings()
