from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.review import Review

class ReviewRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_by_booking_id(self, booking_id: int) -> Review | None:
        result = await self.session.execute(select(Review).where(Review.booking_id == booking_id))
        return result.scalar_one_or_none()
    async def create(self, review: Review) -> Review:
        self.session.add(review)
        await self.session.flush()
        return review
    async def count_by_client(self, client_id: int) -> int:
        result = await self.session.execute(select(func.count()).select_from(Review).where(Review.client_id == client_id))
        return result.scalar() or 0
    async def get_by_client(self, client_id: int) -> list[Review]:
        result = await self.session.execute(select(Review).where(Review.client_id == client_id).order_by(Review.created_at.desc()))
        return list(result.scalars().all())
