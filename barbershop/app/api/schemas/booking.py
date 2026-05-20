from pydantic import BaseModel, Field

class BookingCreateSchema(BaseModel):
    telegram_id: int
    chat_id: int
    username: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    service_id: int = Field(gt=0)
    master_id: int = Field(gt=0)
    date: str
    time: str
