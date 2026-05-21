from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
from app.database import get_session
from app.models.service import Service

router = APIRouter(prefix="/api/admin/services", tags=["admin_services"])

class ServiceCreate(BaseModel):
    name: str
    price: int
    duration_minutes: int
    category: Optional[str] = None

class ServiceUpdate(BaseModel):
    name: Optional[str] = None
    price: Optional[int] = None
    duration_minutes: Optional[int] = None
    category: Optional[str] = None

@router.post("")
async def create_service(data: ServiceCreate, session: AsyncSession = Depends(get_session)):
    service = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category, is_active=True)
    session.add(service)
    await session.commit()
    return {"ok": True, "id": service.id}

@router.put("/{service_id}")
async def update_service(service_id: int, data: ServiceUpdate, session: AsyncSession = Depends(get_session)):
    service = await session.get(Service, service_id)
    if not service:
        raise HTTPException(status_code=404, detail="Услуга не найдена")
    if data.name is not None:
        service.name = data.name
    if data.price is not None:
        service.price = data.price
    if data.duration_minutes is not None:
        service.duration_minutes = data.duration_minutes
    if data.category is not None:
        service.category = data.category
    await session.commit()
    return {"ok": True}

@router.post("/{service_id}/toggle")
async def toggle_service(service_id: int, session: AsyncSession = Depends(get_session)):
    service = await session.get(Service, service_id)
    if not service:
        raise HTTPException(status_code=404, detail="Услуга не найдена")
    service.is_active = not service.is_active
    await session.commit()
    return {"ok": True, "is_active": service.is_active}
