from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.weekend_repo import WeekendRepository
from app.core.security import is_admin
from pydantic import BaseModel

router = APIRouter(prefix="/api", tags=["weekend"])

class WeekendSetSchema(BaseModel):
    admin_telegram_id: int
    days: list[int]

@router.get("/weekend-days")
async def get_weekend_days(session: AsyncSession = Depends(get_session)):
    repo = WeekendRepository(session)
    return await repo.get_all()

@router.post("/admin/weekend-days")
async def set_weekend_days(data: WeekendSetSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = WeekendRepository(session)
    await repo.set(data.days)
    await session.commit()
    return {"ok": True}
