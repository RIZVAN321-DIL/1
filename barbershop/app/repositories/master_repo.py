from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.master import Master

class MasterRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self):
        result = await self.session.execute(select(Master).where(Master.is_active == True).order_by(Master.rating.desc()))
        return result.scalars().all()
