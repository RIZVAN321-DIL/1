from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
from typing import Optional
from app.database import get_session
from app.models.master import Master

router = APIRouter(prefix="/api/admin/masters", tags=["admin_masters"])

class MasterCreate(BaseModel):
    name: str
    photo_url: Optional[str] = None
    experience_years: int = 0

class MasterUpdate(BaseModel):
    name: Optional[str] = None
    photo_url: Optional[str] = None
    experience_years: Optional[int] = None

@router.post("")
async def create_master(data: MasterCreate, session: AsyncSession = Depends(get_session)):
    master = Master(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, is_active=True)
    session.add(master)
    await session.commit()
    return {"ok": True, "id": master.id}

@router.put("/{master_id}")
async def update_master(master_id: int, data: MasterUpdate, session: AsyncSession = Depends(get_session)):
    master = await session.get(Master, master_id)
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    if data.name is not None: master.name = data.name
    if data.photo_url is not None: master.photo_url = data.photo_url
    if data.experience_years is not None: master.experience_years = data.experience_years
    await session.commit()
    return {"ok": True}

@router.post("/{master_id}/toggle")
async def toggle_master(master_id: int, session: AsyncSession = Depends(get_session)):
    master = await session.get(Master, master_id)
    if not master: raise HTTPException(status_code=404)
    master.is_active = not master.is_active
    await session.commit()
    return {"ok": True, "is_active": master.is_active}
