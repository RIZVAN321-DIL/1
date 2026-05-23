from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.review_repo import ReviewRepository
from app.config import settings

router = APIRouter(prefix="/api", tags=["profile"])

@router.get("/profile")
async def get_profile(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client_repo = ClientRepository(session)
    client = await client_repo.get_by_telegram_id(telegram_id)
    if not client:
        return {"exists": False}
    booking_repo = BookingRepository(session)
    review_repo = ReviewRepository(session)
    bookings = await booking_repo.get_client_bookings(client.id)
    past_bookings = await booking_repo.get_past_confirmed(client.id)
    my_reviews = await review_repo.get_by_client(client.id)
    return {"exists": True, "first_name": client.first_name, "username": client.username, "bonus_balance": client.bonus_balance, "total_visits": client.total_visits, "referral_code": client.referral_code, "visits_to_next_bonus": settings.BONUS_VISITS_INTERVAL - (client.total_visits % settings.BONUS_VISITS_INTERVAL), "bookings": [{"id": b.id, "master": b.master.name, "service": b.service.name, "date": b.date, "time": b.time, "price": b.service.price, "status": b.status, "is_manual": b.is_manual} for b in bookings], "past_bookings_for_review": [{"id": b.id, "master": b.master.name, "service": b.service.name, "date": b.date, "time": b.time} for b in past_bookings], "my_reviews": [{"id": r.id, "booking_id": r.booking_id, "master_name": r.master.name if r.master else "—", "rating": r.rating, "comment": r.comment} for r in my_reviews]}
