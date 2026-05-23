from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.booking_repo import BookingRepository

router = APIRouter(prefix="/api", tags=["slots"])

@router.get("/booked-slots")
async def get_booked_slots(date: str = Query(...), master_id: int = Query(...), session: AsyncSession = Depends(get_session)):
    repo = BookingRepository(session)
    times = await repo.get_booked_slots(master_id, date)
    return [{"time": t} for t in times]
