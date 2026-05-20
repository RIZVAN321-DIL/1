from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.booking import BookingCreateSchema
from app.services.booking_service import BookingService

router = APIRouter(prefix="/api", tags=["booking"])

@router.post("/book")
async def create_booking(data: BookingCreateSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.create_booking(
            telegram_id=data.telegram_id, chat_id=data.chat_id, username=data.username,
            first_name=data.first_name, last_name=data.last_name, service_id=data.service_id,
            master_id=data.master_id, booking_date=data.date, booking_time=data.time
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception:
        raise HTTPException(status_code=500, detail="Ошибка создания записи")
