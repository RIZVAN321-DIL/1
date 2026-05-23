from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.review import ReviewCreateSchema
from app.services.review_service import ReviewService
from app.repositories.client_repo import ClientRepository
from app.repositories.review_repo import ReviewRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["reviews"])

@router.post("/reviews")
async def create_review(data: ReviewCreateSchema, session: AsyncSession = Depends(get_session)):
    client_repo = ClientRepository(session)
    client = await client_repo.get_by_telegram_id(data.telegram_id)
    if not client:
        raise HTTPException(status_code=404, detail="Клиент не найден")
    service = ReviewService(session)
    try:
        result = await service.create_review(client_id=client.id, booking_id=data.booking_id, rating=data.rating, comment=data.comment)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.get("/my-reviews")
async def get_my_reviews(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client_repo = ClientRepository(session)
    client = await client_repo.get_by_telegram_id(telegram_id)
    if not client:
        return []
    repo = ReviewRepository(session)
    reviews = await repo.get_by_client(client.id)
    return [{"id": r.id, "booking_id": r.booking_id, "master_name": r.master.name if r.master else "—", "rating": r.rating, "comment": r.comment, "created_at": r.created_at.isoformat() if r.created_at else None} for r in reviews]

@router.get("/admin/reviews")
async def get_all_reviews(admin_telegram_id: int, master_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ReviewRepository(session)
    reviews = await repo.get_all_reviews(master_id=master_id)
    return [{"id": r.id, "client_name": r.client.first_name or "—", "client_username": r.client.username or "—", "master_name": r.master.name if r.master else "—", "rating": r.rating, "comment": r.comment, "created_at": r.created_at.isoformat() if r.created_at else None} for r in reviews]
