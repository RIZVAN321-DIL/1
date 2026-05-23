from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.stats_service import StatsService
from app.repositories.booking_repo import BookingRepository
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["stats"])

@router.get("/admin/stats")
async def get_stats(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    service = StatsService(session)
    return await service.get_stats()

@router.get("/admin/today-bookings")
async def get_today_bookings(admin_telegram_id: int, master_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = BookingRepository(session)
    bookings = await repo.get_today_bookings(master_id=master_id)
    return [{"id": b.id, "client_name": b.client.first_name or b.manual_client_name or "—", "client_username": b.client.username or "—", "master": b.master.name, "service": b.service.name, "time": b.time, "price": b.service.price, "is_manual": b.is_manual} for b in bookings]

@router.get("/admin/audit-log")
async def get_audit_log(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    audit = AuditRepository(session)
    logs = await audit.get_recent()
    return [{"id": l.id, "admin_id": l.admin_id, "action": l.action, "details": l.details, "created_at": l.created_at.isoformat() if l.created_at else None} for l in logs]
