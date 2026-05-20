from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking

class BookingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_slot_booking(self, master_id: int, date: str, time: str):
        query = select(Booking).where(Booking.master_id == master_id, Booking.date == date, Booking.time == time, Booking.status == "confirmed")
        result = await self.session.execute(query)
        return result.scalar_one_or_none()
    async def create(self, booking: Booking):
        self.session.add(booking)
        await self.session.flush()
        return booking
