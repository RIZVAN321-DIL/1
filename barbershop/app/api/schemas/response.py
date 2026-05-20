from pydantic import BaseModel

class BookingResponse(BaseModel):
    ok: bool
    booking_id: int
    master: str
    service: str
    price: int
    date: str
    time: str
