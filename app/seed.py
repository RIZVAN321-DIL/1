from sqlalchemy import select, func
from app.database import async_session
from app.models.master import Master
from app.models.service import Service
from app.logger import logger

MASTERS = [
    {"id":1,"name":"Виктор","photo_url":None,"rating":4.9,"experience_years":8,"telegram_id":None,"max_bookings_per_day":15,"is_admin":False},
    {"id":2,"name":"Алексей","photo_url":None,"rating":4.8,"experience_years":5,"telegram_id":None,"max_bookings_per_day":15,"is_admin":False},
    {"id":3,"name":"Максим","photo_url":None,"rating":4.7,"experience_years":3,"telegram_id":None,"max_bookings_per_day":15,"is_admin":False},
]
SERVICES = [
    {"id":1,"name":"Мужская стрижка","price":1200,"duration_minutes":40,"category":"haircut"},
    {"id":2,"name":"Стрижка машинкой","price":800,"duration_minutes":25,"category":"haircut"},
    {"id":3,"name":"Детская стрижка","price":700,"duration_minutes":30,"category":"haircut"},
    {"id":4,"name":"Королевское бритьё","price":1000,"duration_minutes":30,"category":"shave"},
    {"id":5,"name":"VIP-комплекс","price":2500,"duration_minutes":60,"category":"vip"},
    {"id":6,"name":"Укладка","price":500,"duration_minutes":20,"category":"styling"},
    {"id":7,"name":"Камуфляж седины","price":1500,"duration_minutes":45,"category":"color"},
]

async def seed_database():
    async with async_session() as session:
        if not await session.scalar(select(func.count()).select_from(Master)):
            for m in MASTERS:
                session.add(Master(**m))
            await session.commit()
            logger.info(f"Мастера: {len(MASTERS)}")
        if not await session.scalar(select(func.count()).select_from(Service)):
            for s in SERVICES:
                session.add(Service(**s))
            await session.commit()
            logger.info(f"Услуги: {len(SERVICES)}")
