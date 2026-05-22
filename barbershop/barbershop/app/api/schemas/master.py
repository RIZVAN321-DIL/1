from pydantic import BaseModel, Field

class MasterCreateSchema(BaseModel):
    admin_telegram_id: int
    name: str = Field(min_length=1, max_length=255)
    photo_url: str | None = None
    experience_years: int = Field(default=0, ge=0)

class MasterUpdateSchema(BaseModel):
    admin_telegram_id: int
    name: str | None = Field(default=None, min_length=1, max_length=255)
    photo_url: str | None = None
    experience_years: int | None = Field(default=None, ge=0)

class MasterToggleSchema(BaseModel):
    admin_telegram_id: int
    master_id: int
