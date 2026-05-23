from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.booking import BookingCreateSchema, BookingCancelSchema, AdminCancelSchema, MasterDayOffSchema
from app.services.booking_service import BookingService
from app.core.security import is_admin
from app.repositories.audit_repo import AuditRepository

router = APIRouter(prefix="/api", tags=["booking"])

@router.post("/book")
async def create_booking(data: BookingCreateSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.create_booking(telegram_id=data.telegram_id, chat_id=data.chat_id, username=data.username, first_name=data.first_name, last_name=data.last_name, service_id=data.service_id, master_id=data.master_id, booking_date=data.date, booking_time=data.time)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/cancel")
async def cancel_booking(data: BookingCancelSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.cancel_booking(booking_id=data.booking_id, telegram_id=data.telegram_id, is_admin=False)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/cancel")
async def admin_cancel_booking(data: AdminCancelSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.cancel_booking(booking_id=data.booking_id, telegram_id=data.admin_telegram_id, is_admin=True)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "cancel_booking", f"booking_id={data.booking_id}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/master-day-off")
async def set_master_day_off(data: MasterDayOffSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.set_master_day_off(data.master_id, data.date, data.reason, data.admin_telegram_id)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "master_day_off", f"master_id={data.master_id} date={data.date}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
