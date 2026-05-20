from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.models.booking import Booking

router = APIRouter(prefix="/api", tags=["booked"])

@router.get("/booked-slots")
async def get_booked_slots(
    date: str = Query(..., description="Дата YYYY-MM-DD"),
    master_id: int = Query(..., description="ID мастера"),
    session: AsyncSession = Depends(get_session)
):
    result = await session.execute(
        select(Booking.time).where(
            Booking.master_id == master_id,
            Booking.date == date,
            Booking.status == "confirmed"
        )
    )
    times = result.scalars().all()
    return [{"time": t} for t in times]
