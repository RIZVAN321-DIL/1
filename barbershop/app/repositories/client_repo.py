from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_by_telegram_id(self, telegram_id: int):
        result = await self.session.execute(select(Client).where(Client.telegram_id == telegram_id))
        return result.scalar_one_or_none()
    async def create(self, client: Client):
        self.session.add(client)
        await self.session.flush()
        return client
