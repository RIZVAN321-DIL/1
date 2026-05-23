from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.master_repo import MasterRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.master import MasterCreateSchema, MasterUpdateSchema, MasterToggleSchema
from app.models.master import Master
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["masters"])

@router.get("/masters")
async def get_masters(session: AsyncSession = Depends(get_session)):
    repo = MasterRepository(session)
    masters = await repo.get_all_active()
    return [{"id": m.id, "name": m.name, "photo": m.photo_url, "rating": m.rating, "experience": m.experience_years, "max_bookings": m.max_bookings_per_day} for m in masters]

@router.get("/admin/masters")
async def get_all_masters(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    masters = await repo.get_all()
    return [{"id": m.id, "name": m.name, "photo": m.photo_url, "rating": m.rating, "experience": m.experience_years, "telegram_id": m.telegram_id, "max_bookings": m.max_bookings_per_day, "is_admin": m.is_admin, "is_active": m.is_active} for m in masters]

@router.post("/admin/masters")
async def create_master(data: MasterCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    master = Master(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, telegram_id=data.telegram_id, max_bookings_per_day=data.max_bookings_per_day, is_admin=data.is_admin)
    result = await repo.create(master)
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "create_master", f"name={data.name}")
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/masters/{master_id}")
async def update_master(master_id: int, data: MasterUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await repo.update_fields(master_id, **updates)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "update_master", f"master_id={master_id} {updates}")
        await session.commit()
    return {"ok": True}

@router.post("/admin/masters/{master_id}/toggle")
async def toggle_master(master_id: int, data: MasterToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    master = await repo.toggle_active(master_id)
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "toggle_master", f"master_id={master_id}")
    await session.commit()
    return {"ok": True, "is_active": master.is_active}
