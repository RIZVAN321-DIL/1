from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.master_repo import MasterRepository

router = APIRouter(prefix="/api", tags=["masters"])

@router.get("/masters")
async def get_masters(session: AsyncSession = Depends(get_session)):
    repo = MasterRepository(session)
    masters = await repo.get_all_active()
    return [{"id": m.id, "name": m.name, "photo": m.photo_url, "rating": m.rating, "experience": m.experience_years} for m in masters]
