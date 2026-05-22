from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.master import Master
from app.models.review import Review

class MasterRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self) -> list[Master]:
        result = await self.session.execute(select(Master).where(Master.is_active == True).order_by(Master.rating.desc()))
        return list(result.scalars().all())
    async def get_all(self) -> list[Master]:
        result = await self.session.execute(select(Master).order_by(Master.id))
        return list(result.scalars().all())
    async def get_by_id(self, master_id: int) -> Master | None:
        result = await self.session.execute(select(Master).where(Master.id == master_id))
        return result.scalar_one_or_none()
    async def create(self, master: Master) -> Master:
        self.session.add(master)
        await self.session.flush()
        return master
    async def update_fields(self, master_id: int, **kwargs):
        await self.session.execute(update(Master).where(Master.id == master_id).values(**kwargs))
        await self.session.flush()
    async def toggle_active(self, master_id: int) -> Master | None:
        master = await self.get_by_id(master_id)
        if master:
            master.is_active = not master.is_active
            await self.session.flush()
        return master
    async def update_rating(self, master_id: int):
        result = await self.session.execute(select(func.avg(Review.rating), func.count(Review.id)).where(Review.master_id == master_id))
        avg_rating, total = result.one()
        await self.session.execute(update(Master).where(Master.id == master_id).values(rating=round(float(avg_rating or 5.0), 1), total_reviews=total or 0))
        await self.session.flush()
