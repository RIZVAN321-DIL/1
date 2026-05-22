from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.service_repo import ServiceRepository
from app.api.schemas.service import ServiceCreateSchema, ServiceUpdateSchema, ServiceToggleSchema
from app.models.service import Service
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["services"])

@router.get("/services")
async def get_services(session: AsyncSession = Depends(get_session)):
    repo = ServiceRepository(session)
    services = await repo.get_all_active()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category} for s in services]

@router.get("/admin/services")
async def get_all_services(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    services = await repo.get_all()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category, "is_active": s.is_active} for s in services]

@router.post("/admin/services")
async def create_service(data: ServiceCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    service = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category)
    result = await repo.create(service)
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/services/{service_id}")
async def update_service(service_id: int, data: ServiceUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await repo.update_fields(service_id, **updates)
        await session.commit()
    return {"ok": True}

@router.post("/admin/services/{service_id}/toggle")
async def toggle_service(service_id: int, data: ServiceToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    service = await repo.toggle_active(service_id)
    if not service:
        raise HTTPException(status_code=404, detail="Услуга не найдена")
    await session.commit()
    return {"ok": True, "is_active": service.is_active}
