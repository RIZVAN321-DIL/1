from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.service import Service

class ServiceRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self):
        result = await self.session.execute(select(Service).where(Service.is_active == True).order_by(Service.category, Service.price))
        return result.scalars().all()
