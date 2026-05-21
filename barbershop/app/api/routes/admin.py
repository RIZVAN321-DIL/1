from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from pydantic import BaseModel
from typing import Optional
from datetime import date
from app.database import get_session
from app.models.booking import Booking
from app.models.client import Client
from app.models.master import Master
from app.models.service import Service

router = APIRouter(prefix="/api/admin", tags=["admin"])

# --- Мастера ---
class MasterCreate(BaseModel):
    name: str
    photo_url: Optional[str] = None
    experience_years: int = 0

class MasterUpdate(BaseModel):
    name: Optional[str] = None
    photo_url: Optional[str] = None
    experience_years: Optional[int] = None

@router.post("/masters")
async def create_master(data: MasterCreate, session: AsyncSession = Depends(get_session)):
    master = Master(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, is_active=True)
    session.add(master); await session.commit()
    return {"ok": True, "id": master.id}

@router.put("/masters/{master_id}")
async def update_master(master_id: int, data: MasterUpdate, session: AsyncSession = Depends(get_session)):
    master = await session.get(Master, master_id)
    if not master: raise HTTPException(404)
    if data.name is not None: master.name = data.name
    if data.photo_url is not None: master.photo_url = data.photo_url
    if data.experience_years is not None: master.experience_years = data.experience_years
    await session.commit()
    return {"ok": True}

@router.post("/masters/{master_id}/toggle")
async def toggle_master(master_id: int, session: AsyncSession = Depends(get_session)):
    master = await session.get(Master, master_id)
    if not master: raise HTTPException(404)
    master.is_active = not master.is_active; await session.commit()
    return {"ok": True}

# --- Услуги ---
class ServiceCreate(BaseModel):
    name: str; price: int; duration_minutes: int; category: Optional[str] = None

class ServiceUpdate(BaseModel):
    name: Optional[str] = None; price: Optional[int] = None; duration_minutes: Optional[int] = None; category: Optional[str] = None

@router.post("/services")
async def create_service(data: ServiceCreate, session: AsyncSession = Depends(get_session)):
    service = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category, is_active=True)
    session.add(service); await session.commit()
    return {"ok": True, "id": service.id}

@router.put("/services/{service_id}")
async def update_service(service_id: int, data: ServiceUpdate, session: AsyncSession = Depends(get_session)):
    service = await session.get(Service, service_id)
    if not service: raise HTTPException(404)
    if data.name is not None: service.name = data.name
    if data.price is not None: service.price = data.price
    if data.duration_minutes is not None: service.duration_minutes = data.duration_minutes
    if data.category is not None: service.category = data.category
    await session.commit()
    return {"ok": True}

@router.post("/services/{service_id}/toggle")
async def toggle_service(service_id: int, session: AsyncSession = Depends(get_session)):
    service = await session.get(Service, service_id)
    if not service: raise HTTPException(404)
    service.is_active = not service.is_active; await session.commit()
    return {"ok": True}

# --- Записи ---
class CancelBooking(BaseModel): booking_id: int

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
    bookings = (await session.execute(select(Booking).where(Booking.date == today, Booking.status == "confirmed"))).scalars().all()
    services = (await session.execute(select(Service))).scalars().all()
    revenue = 0
    for b in bookings:
        s = next((s for s in services if s.id == b.service_id), None)
        if s: revenue += s.price
    return {"today": bookings_today or 0, "clients": total_clients or 0, "total": total_bookings or 0, "revenue": revenue}

@router.post("/cancel-booking")
async def cancel_booking(data: CancelBooking, session: AsyncSession = Depends(get_session)):
    booking = await session.get(Booking, data.booking_id)
    if not booking: raise HTTPException(404)
    booking.status = "cancelled"; await session.commit()
    return {"ok": True}

# --- Рассылка ---
class Broadcast(BaseModel): text: str

@router.post("/broadcast")
async def broadcast(data: Broadcast, session: AsyncSession = Depends(get_session)):
    clients = (await session.execute(select(Client))).scalars().all()
    return {"ok": True, "sent": 0, "total": len(clients), "message": "Рассылка будет отправлена через бота"}
