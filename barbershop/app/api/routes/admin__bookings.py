from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from datetime import date
from app.database import get_session
from app.models.booking import Booking
from app.models.client import Client

router = APIRouter(prefix="/api/admin", tags=["admin"])

class CancelBooking(BaseModel):
    booking_id: int

@router.get("/today-bookings")
async def today_bookings(session: AsyncSession = Depends(get_session)):
    today = date.today().isoformat()
    result = await session.execute(select(Booking).where(Booking.date == today).order_by(Booking.time))
    bookings = result.scalars().all()
    return [{"id": b.id, "date": b.date, "time": b.time, "status": b.status} for b in bookings]

@router.get("/stats")
async def stats(session: AsyncSession = Depends(get_session)):
    today = date.today().isoformat()
    bookings_today = await session.scalar(select(func.count()).where(Booking.date == today, Booking.status == "confirmed"))
    total_clients = await session.scalar(select(func.count()).select_from(Client))
    total_bookings = await session.scalar(select(func.count()).select_from(Booking))
    return {"today": bookings_today or 0, "clients": total_clients or 0, "total": total_bookings or 0}

@router.post("/cancel-booking")
async def cancel_booking(data: CancelBooking, session: AsyncSession = Depends(get_session)):
    booking = await session.get(Booking, data.booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail="Запись не найдена")
    booking.status = "cancelled"
    await session.commit()
    return {"ok": True}
