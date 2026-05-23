#!/bin/bash

mkdir -p app/core app/models app/repositories app/services app/api/routes app/api/schemas app/bot/handlers app/static/uploads
touch app/static/uploads/.gitkeep

cat > .env << 'ENVEOF'
BOT_TOKEN=8649327502:AAEaG_RIjuWC0bJUSNfPxLraX019g7Kxphw
ADMIN_IDS=5724746367
DATABASE_URL=sqlite+aiosqlite:///./barbershop.db
API_HOST=0.0.0.0
API_PORT=10000
BASE_URL=https://bar-vdlc.onrender.com
SECRET_KEY=barbershop-secret-2024
MAX_ACTIVE_BOOKINGS=2
BONUS_VISITS_INTERVAL=5
BONUS_AMOUNT=200
BOT_USERNAME=Barber_Kirovsk_bot
DEFAULT_MAX_BOOKINGS_PER_DAY=15
ENVEOF

cat > runtime.txt << 'EOF'
python-3.12.0
EOF

cat > Procfile << 'EOF'
web: uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}
worker: python -m app.bot.main
EOF

cat > requirements.txt << 'EOF'
aiogram>=3.7.0
fastapi>=0.115.0
uvicorn[standard]>=0.32.0
sqlalchemy[asyncio]>=2.0.36
aiosqlite>=0.20.0
pydantic>=2.10.0
pydantic-settings>=2.6.0
python-dotenv>=1.0.0
loguru>=0.7.0
python-multipart>=0.0.12
apscheduler>=3.10.4
httpx>=0.27.0
aiofiles>=23.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN mkdir -p /app/data /app/app/static/uploads
ENV DATABASE_URL=sqlite+aiosqlite:////app/data/barbershop.db
EXPOSE 7860
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860} & python -m app.bot.main"]
EOF

cat > app/__init__.py << 'EOF'
EOF

cat > app/config.py << 'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import field_validator

class Settings(BaseSettings):
    BOT_TOKEN: str
    DATABASE_URL: str = "sqlite+aiosqlite:///./barbershop.db"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 7860
    BASE_URL: str = ""
    ADMIN_IDS: list[int] = []
    SECRET_KEY: str = "change-me"
    MAX_ACTIVE_BOOKINGS: int = 2
    BONUS_VISITS_INTERVAL: int = 5
    BONUS_AMOUNT: int = 200
    BOT_USERNAME: str = ""
    DEFAULT_MAX_BOOKINGS_PER_DAY: int = 15
    UPLOAD_DIR: str = "app/static/uploads"
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")
    @field_validator("ADMIN_IDS", mode="before")
    @classmethod
    def parse_admins(cls, value):
        if isinstance(value, str):
            return [int(x.strip()) for x in value.split(",") if x.strip()]
        if isinstance(value, list):
            return value
        return []

settings = Settings()
EOF

cat > app/logger.py << 'EOF'
import logging, sys

def setup_logger():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(name)s | %(message)s", handlers=[logging.StreamHandler(sys.stdout), logging.FileHandler("bot.log", encoding="utf-8")])
    return logging.getLogger("barbershop")

logger = setup_logger()
EOF

cat > app/database.py << 'EOF'
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from sqlalchemy.orm import DeclarativeBase
from app.config import settings

class Base(DeclarativeBase):
    pass

engine = create_async_engine(settings.DATABASE_URL, echo=False, pool_pre_ping=True, future=True)
async_session = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

async def get_session():
    async with async_session() as session:
        try:
            yield session
        finally:
            await session.close()
EOF

cat > app/seed.py << 'EOF'
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
EOF

cat > app/main.py << 'EOF'
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import engine, Base
from app.seed import seed_database
from app.logger import logger
from app.core.scheduler import scheduler
from app.services.notification_service import NotificationService
from app.api.routes.booking import router as booking_router
from app.api.routes.services import router as services_router
from app.api.routes.masters import router as masters_router
from app.api.routes.slots import router as slots_router
from app.api.routes.reviews import router as reviews_router
from app.api.routes.stats import router as stats_router
from app.api.routes.broadcast import router as broadcast_router
from app.api.routes.profile import router as profile_router
from app.api.routes.upload import router as upload_router
from app.api.routes.weekend import router as weekend_router
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API start")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_database()
    scheduler.start()
    await NotificationService.restore_reminders()
    logger.info("API ready")
    yield
    scheduler.shutdown(wait=False)
    logger.info("API stop")

app = FastAPI(title="Barbershop API", version="9.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(booking_router)
app.include_router(services_router)
app.include_router(masters_router)
app.include_router(slots_router)
app.include_router(reviews_router)
app.include_router(stats_router)
app.include_router(broadcast_router)
app.include_router(profile_router)
app.include_router(upload_router)
app.include_router(weekend_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/mini-app")
async def mini_app():
    return FileResponse("app/static/index.html")
EOF

cat > app/core/__init__.py << 'EOF'
EOF

cat > app/core/scheduler.py << 'EOF'
from apscheduler.schedulers.asyncio import AsyncIOScheduler
scheduler = AsyncIOScheduler()
EOF

cat > app/core/security.py << 'EOF'
from app.config import settings

def is_admin(telegram_id: int) -> bool:
    return telegram_id in settings.ADMIN_IDS
EOF

echo "Часть 1 готова"
cat > app/models/__init__.py << 'EOF'
from app.models.client import Client
from app.models.master import Master
from app.models.service import Service
from app.models.booking import Booking
from app.models.review import Review
from app.models.master_day_off import MasterDayOff
from app.models.audit_log import AuditLog
from app.models.weekend import Weekend
EOF

cat > app/models/client.py << 'EOF'
import secrets
from sqlalchemy import String, Integer, BigInteger, Boolean, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Client(Base):
    __tablename__ = "clients"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    telegram_id: Mapped[int] = mapped_column(BigInteger, unique=True, index=True)
    chat_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    username: Mapped[str | None] = mapped_column(String(255), nullable=True)
    first_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    phone_number: Mapped[str | None] = mapped_column(String(20), nullable=True, index=True)
    bonus_balance: Mapped[int] = mapped_column(Integer, default=0)
    total_visits: Mapped[int] = mapped_column(Integer, default=0)
    referral_code: Mapped[str] = mapped_column(String(50), unique=True, default=lambda: secrets.token_hex(4))
    referral_from: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    is_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    bookings = relationship("Booking", back_populates="client", cascade="all, delete-orphan")
    reviews = relationship("Review", back_populates="client", cascade="all, delete-orphan")
EOF

cat > app/models/master.py << 'EOF'
from sqlalchemy import String, Float, Integer, Boolean, BigInteger
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Master(Base):
    __tablename__ = "masters"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=5.0)
    total_reviews: Mapped[int] = mapped_column(Integer, default=0)
    experience_years: Mapped[int] = mapped_column(Integer, default=0)
    telegram_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    max_bookings_per_day: Mapped[int] = mapped_column(Integer, default=15)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    bookings = relationship("Booking", back_populates="master")
    reviews = relationship("Review", back_populates="master")
    days_off = relationship("MasterDayOff", back_populates="master", cascade="all, delete-orphan")
EOF

cat > app/models/service.py << 'EOF'
from sqlalchemy import String, Integer, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Service(Base):
    __tablename__ = "services"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    price: Mapped[int] = mapped_column(Integer)
    duration_minutes: Mapped[int] = mapped_column(Integer)
    category: Mapped[str | None] = mapped_column(String(100), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    bookings = relationship("Booking", back_populates="service")
EOF

cat > app/models/booking.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean, UniqueConstraint
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    master_id: Mapped[int] = mapped_column(ForeignKey("masters.id"))
    service_id: Mapped[int] = mapped_column(ForeignKey("services.id"))
    date: Mapped[str] = mapped_column(String(10))
    time: Mapped[str] = mapped_column(String(5))
    duration_minutes: Mapped[int] = mapped_column(Integer, default=30)
    status: Mapped[str] = mapped_column(String(50), default="confirmed")
    cancel_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    is_manual: Mapped[bool] = mapped_column(Boolean, default=False)
    manual_client_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    manual_phone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    reminder_sent: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    client = relationship("Client", back_populates="bookings")
    master = relationship("Master", back_populates="bookings")
    service = relationship("Service", back_populates="bookings")
EOF

cat > app/models/review.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    client_id: Mapped[int] = mapped_column(ForeignKey("clients.id"))
    master_id: Mapped[int] = mapped_column(ForeignKey("masters.id"))
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    rating: Mapped[int] = mapped_column(Integer)
    comment: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    is_approved: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    client = relationship("Client", back_populates="reviews")
    master = relationship("Master", back_populates="reviews")
EOF

cat > app/models/master_day_off.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.database import Base

class MasterDayOff(Base):
    __tablename__ = "master_days_off"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    master_id: Mapped[int] = mapped_column(ForeignKey("masters.id"))
    date: Mapped[str] = mapped_column(String(10))
    reason: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    master = relationship("Master", back_populates="days_off")
EOF

cat > app/models/audit_log.py << 'EOF'
from sqlalchemy import String, Integer, DateTime, BigInteger
from sqlalchemy.sql import func
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    admin_id: Mapped[int] = mapped_column(BigInteger)
    action: Mapped[str] = mapped_column(String(255))
    details: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[DateTime] = mapped_column(DateTime(timezone=True), server_default=func.now())
EOF

cat > app/models/weekend.py << 'EOF'
from sqlalchemy import String, Integer
from sqlalchemy.orm import Mapped, mapped_column
from app.database import Base

class Weekend(Base):
    __tablename__ = "weekends"
    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    day_of_week: Mapped[int] = mapped_column(Integer, unique=True)
EOF

echo "Часть 2 готова"
cat > app/repositories/__init__.py << 'EOF'
EOF

cat > app/repositories/client_repo.py << 'EOF'
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.client import Client

class ClientRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_by_telegram_id(self, telegram_id: int) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.telegram_id == telegram_id))
        return result.scalar_one_or_none()
    async def get_by_phone(self, phone: str) -> Client | None:
        result = await self.session.execute(select(Client).where(Client.phone_number == phone))
        return result.scalar_one_or_none()
    async def get_or_create(self, telegram_id: int, chat_id: int | None = None, username: str | None = None, first_name: str | None = None, last_name: str | None = None, phone_number: str | None = None, referral_from: int | None = None) -> Client:
        client = await self.get_by_telegram_id(telegram_id)
        if not client:
            client = Client(telegram_id=telegram_id, chat_id=chat_id or telegram_id, username=username, first_name=first_name, last_name=last_name, phone_number=phone_number, referral_from=referral_from)
            self.session.add(client)
            await self.session.flush()
        return client
    async def get_or_create_manual(self, first_name: str, phone_number: str | None = None) -> Client:
        if phone_number:
            client = await self.get_by_phone(phone_number)
            if client:
                return client
        client = Client(telegram_id=0, first_name=first_name, phone_number=phone_number)
        self.session.add(client)
        await self.session.flush()
        return client
    async def get_all_telegram_ids(self) -> list[int]:
        result = await self.session.execute(select(Client.telegram_id))
        return [row[0] for row in result.all() if row[0] != 0]
    async def get_total_count(self) -> int:
        result = await self.session.execute(select(func.count()).select_from(Client))
        return result.scalar() or 0
    async def add_bonus(self, client_id: int, amount: int):
        await self.session.execute(update(Client).where(Client.id == client_id).values(bonus_balance=Client.bonus_balance + amount))
        await self.session.flush()
    async def increment_visits(self, client_id: int):
        await self.session.execute(update(Client).where(Client.id == client_id).values(total_visits=Client.total_visits + 1))
        await self.session.flush()
EOF

cat > app/repositories/master_repo.py << 'EOF'
from sqlalchemy import select, update, func
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.master import Master
from app.models.review import Review
from app.models.master_day_off import MasterDayOff

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
    async def add_day_off(self, master_id: int, date: str, reason: str | None = None) -> MasterDayOff:
        day_off = MasterDayOff(master_id=master_id, date=date, reason=reason)
        self.session.add(day_off)
        await self.session.flush()
        return day_off
    async def is_day_off(self, master_id: int, date: str) -> bool:
        result = await self.session.execute(select(MasterDayOff).where(MasterDayOff.master_id == master_id, MasterDayOff.date == date))
        return result.scalar_one_or_none() is not None
    async def get_available_masters_for_slot(self, date: str, time: str, service_id: int, exclude_master_id: int) -> list[Master]:
        from app.models.booking import Booking
        from app.models.service import Service
        service = await self.session.execute(select(Service).where(Service.id == service_id))
        svc = service.scalar_one_or_none()
        if not svc:
            return []
        slots_needed = max(1, (svc.duration_minutes + 29) // 30)
        hour, minute = map(int, time.split(":"))
        slot_times = []
        for i in range(slots_needed):
            m = minute + i * 30
            h = hour + m // 60
            m = m % 60
            slot_times.append(f"{h:02d}:{m:02d}")
        booked_masters = set()
        for t in slot_times:
            result = await self.session.execute(select(Booking.master_id).where(Booking.date == date, Booking.time == t, Booking.status == "confirmed"))
            booked_masters.update(row[0] for row in result.all())
        booked_masters.add(exclude_master_id)
        result = await self.session.execute(select(Master).where(Master.is_active == True, Master.id.notin_(booked_masters)).order_by(Master.rating.desc()).limit(3))
        return list(result.scalars().all())
EOF

cat > app/repositories/service_repo.py << 'EOF'
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.service import Service

class ServiceRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all_active(self) -> list[Service]:
        result = await self.session.execute(select(Service).where(Service.is_active == True).order_by(Service.category, Service.price))
        return list(result.scalars().all())
    async def get_all(self) -> list[Service]:
        result = await self.session.execute(select(Service).order_by(Service.id))
        return list(result.scalars().all())
    async def get_by_id(self, service_id: int) -> Service | None:
        result = await self.session.execute(select(Service).where(Service.id == service_id))
        return result.scalar_one_or_none()
    async def create(self, service: Service) -> Service:
        self.session.add(service)
        await self.session.flush()
        return service
    async def update_fields(self, service_id: int, **kwargs):
        await self.session.execute(update(Service).where(Service.id == service_id).values(**kwargs))
        await self.session.flush()
    async def toggle_active(self, service_id: int) -> Service | None:
        service = await self.get_by_id(service_id)
        if service:
            service.is_active = not service.is_active
            await self.session.flush()
        return service
EOF

cat > app/repositories/booking_repo.py << 'EOF'
from datetime import date as dt_date, datetime
from sqlalchemy import select, update, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.models.service import Service

class BookingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def check_slot_available(self, master_id: int, date: str, time: str, duration_minutes: int) -> tuple[bool, list[str]]:
        slots_needed = max(1, (duration_minutes + 29) // 30)
        hour, minute = map(int, time.split(":"))
        slot_times = []
        for i in range(slots_needed):
            m = minute + i * 30
            h = hour + m // 60
            m = m % 60
            slot_times.append(f"{h:02d}:{m:02d}")
        for t in slot_times:
            result = await self.session.execute(select(Booking).where(Booking.master_id == master_id, Booking.date == date, Booking.time == t, Booking.status == "confirmed"))
            if result.scalar_one_or_none():
                return False, slot_times
        return True, slot_times
    async def get_active_count(self, client_id: int) -> int:
        result = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.client_id == client_id, Booking.status == "confirmed", Booking.date >= dt_date.today().isoformat()))
        return result.scalar() or 0
    async def get_by_id(self, booking_id: int) -> Booking | None:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.id == booking_id))
        return result.scalar_one_or_none()
    async def create(self, booking: Booking) -> Booking:
        self.session.add(booking)
        await self.session.flush()
        return booking
    async def cancel(self, booking_id: int, reason: str = "client_cancel") -> Booking | None:
        booking = await self.get_by_id(booking_id)
        if booking and booking.status == "confirmed":
            booking.status = "cancelled"
            booking.cancel_reason = reason
            await self.session.flush()
        return booking
    async def get_client_bookings(self, client_id: int) -> list[Booking]:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.client_id == client_id).order_by(Booking.date.desc(), Booking.time.desc()))
        return list(result.scalars().all())
    async def get_today_bookings(self, master_id: int | None = None) -> list[Booking]:
        today = dt_date.today().isoformat()
        query = select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.date == today, Booking.status == "confirmed")
        if master_id:
            query = query.where(Booking.master_id == master_id)
        result = await self.session.execute(query.order_by(Booking.time))
        return list(result.scalars().all())
    async def get_today_revenue(self) -> int:
        today = dt_date.today().isoformat()
        result = await self.session.execute(select(func.sum(Service.price)).join(Booking, Booking.service_id == Service.id).where(Booking.date == today, Booking.status == "confirmed"))
        return result.scalar() or 0
    async def get_past_confirmed(self, client_id: int) -> list[Booking]:
        today = dt_date.today().isoformat()
        now_time = datetime.now().strftime("%H:%M")
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.client_id == client_id, Booking.status == "confirmed").where((Booking.date < today) | ((Booking.date == today) & (Booking.time < now_time))).order_by(Booking.date.desc()))
        return list(result.scalars().all())
    async def get_upcoming_confirmed(self) -> list[Booking]:
        today = dt_date.today().isoformat()
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.date >= today, Booking.status == "confirmed").order_by(Booking.date, Booking.time))
        return list(result.scalars().all())
    async def mark_reminder_sent(self, booking_id: int):
        await self.session.execute(update(Booking).where(Booking.id == booking_id).values(reminder_sent=True))
        await self.session.flush()
    async def get_master_day_bookings_count(self, master_id: int, date: str) -> int:
        result = await self.session.execute(select(func.count()).select_from(Booking).where(Booking.master_id == master_id, Booking.date == date, Booking.status == "confirmed"))
        return result.scalar() or 0
    async def cancel_all_for_master_date(self, master_id: int, date: str, reason: str):
        await self.session.execute(update(Booking).where(Booking.master_id == master_id, Booking.date == date, Booking.status == "confirmed").values(status="cancelled", cancel_reason=reason))
        await self.session.flush()
    async def get_confirmed_for_master_date(self, master_id: int, date: str) -> list[Booking]:
        result = await self.session.execute(select(Booking).options(selectinload(Booking.client), selectinload(Booking.master), selectinload(Booking.service)).where(Booking.master_id == master_id, Booking.date == date, Booking.status == "confirmed"))
        return list(result.scalars().all())
    async def get_booked_slots(self, master_id: int, date: str) -> list[str]:
        result = await self.session.execute(select(Booking.time, Booking.duration_minutes).where(Booking.master_id == master_id, Booking.date == date, Booking.status == "confirmed"))
        blocked = set()
        for time_str, dur in result.all():
            slots_needed = max(1, (dur + 29) // 30)
            hour, minute = map(int, time_str.split(":"))
            for i in range(slots_needed):
                m = minute + i * 30
                h = hour + m // 60
                m = m % 60
                blocked.add(f"{h:02d}:{m:02d}")
        return sorted(blocked)
EOF

cat > app/repositories/review_repo.py << 'EOF'
from sqlalchemy import select, func
from sqlalchemy.orm import selectinload
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
        result = await self.session.execute(select(Review).options(selectinload(Review.master)).where(Review.client_id == client_id).order_by(Review.created_at.desc()))
        return list(result.scalars().all())
    async def get_all_reviews(self, master_id: int | None = None, limit: int = 100) -> list[Review]:
        query = select(Review).options(selectinload(Review.client), selectinload(Review.master))
        if master_id:
            query = query.where(Review.master_id == master_id)
        result = await self.session.execute(query.order_by(Review.created_at.desc()).limit(limit))
        return list(result.scalars().all())
EOF

cat > app/repositories/audit_repo.py << 'EOF'
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.audit_log import AuditLog

class AuditRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def log(self, admin_id: int, action: str, details: str = ""):
        log_entry = AuditLog(admin_id=admin_id, action=action, details=details)
        self.session.add(log_entry)
        await self.session.flush()
    async def get_recent(self, limit: int = 50) -> list[AuditLog]:
        result = await self.session.execute(select(AuditLog).order_by(AuditLog.created_at.desc()).limit(limit))
        return list(result.scalars().all())
EOF

cat > app/repositories/weekend_repo.py << 'EOF'
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.weekend import Weekend

class WeekendRepository:
    def __init__(self, session: AsyncSession):
        self.session = session
    async def get_all(self) -> list[int]:
        result = await self.session.execute(select(Weekend.day_of_week))
        return [row[0] for row in result.all()]
    async def set(self, days: list[int]):
        await self.session.execute(delete(Weekend))
        for d in days:
            self.session.add(Weekend(day_of_week=d))
        await self.session.flush()
EOF

echo "Часть 3 готова"
cat > app/services/__init__.py << 'EOF'
EOF

cat > app/services/notification_service.py << 'EOF'
from datetime import datetime, timedelta
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.core.scheduler import scheduler
from app.logger import logger

reminder_jobs: dict[int, list[str]] = {}

class NotificationService:
    @staticmethod
    async def get_bot() -> Bot:
        return Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))

    @classmethod
    async def notify_admin_new_booking(cls, booking):
        try:
            bot = await cls.get_bot()
            client_display = booking.client.first_name or booking.manual_client_name or "—"
            text = f"🔔 <b>Новая запись!</b>\nКлиент: {client_display}\nМастер: {booking.master.name}\nУслуга: {booking.service.name}\nДата: {booking.date}\nВремя: {booking.time}\nДлительность: {booking.duration_minutes} мин\nЦена: {booking.service.price}₽"
            for admin_id in settings.ADMIN_IDS:
                await bot.send_message(admin_id, text)
            if booking.master.telegram_id:
                try:
                    await bot.send_message(booking.master.telegram_id, text)
                except Exception as e:
                    logger.error(f"Ошибка уведомления мастеру: {e}")
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления админу: {e}")

    @classmethod
    async def notify_client_confirmation(cls, booking):
        try:
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            bot = await cls.get_bot()
            text = f"✅ <b>Запись подтверждена!</b>\n\nУслуга: {booking.service.name}\nМастер: {booking.master.name}\nДата: {booking.date}\nВремя: {booking.time}\nДлительность: {booking.duration_minutes} мин\nЦена: {booking.service.price}₽\n\n📍 ул. Чернышевского, 52Б"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления клиенту: {e}")

    @classmethod
    async def notify_manual_booking(cls, booking, client):
        try:
            if client.telegram_id == 0:
                return
            bot = await cls.get_bot()
            text = f"📞 <b>Вас записали по звонку!</b>\n\nУслуга: {booking.service.name}\nМастер: {booking.master.name}\nДата: {booking.date}\nВремя: {booking.time}\nЦена: {booking.service.price}₽\n\n📍 ул. Чернышевского, 52Б"
            await bot.send_message(client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления о ручной записи: {e}")

    @classmethod
    async def notify_master_day_off(cls, booking, reason: str):
        try:
            if booking.is_manual:
                return
            bot = await cls.get_bot()
            text = f"😔 <b>Мастер {booking.master.name} не сможет вас принять {booking.date} в {booking.time}.</b>\n\nПричина: {reason or 'Выходной день'}\n\nЗапишитесь на другую дату через бота.\nПриносим извинения!"
            await bot.send_message(booking.client.telegram_id, text)
            await bot.session.close()
        except Exception as e:
            logger.error(f"Ошибка уведомления о выходном: {e}")

    @classmethod
    async def schedule_reminders(cls, booking):
        try:
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            dt = datetime.strptime(f"{booking.date} {booking.time}", "%Y-%m-%d %H:%M")
            reminder_24h = dt - timedelta(hours=24)
            reminder_2h = dt - timedelta(hours=2)
            now = datetime.now()
            job_ids = []
            if reminder_24h > now:
                job_24 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_24h, args=[booking.id, 24], misfire_grace_time=300)
                job_ids.append(job_24.id)
            if reminder_2h > now:
                job_2 = scheduler.add_job(cls._send_reminder, "date", run_date=reminder_2h, args=[booking.id, 2], misfire_grace_time=300)
                job_ids.append(job_2.id)
            if job_ids:
                reminder_jobs[booking.id] = job_ids
                logger.info(f"Напоминания для #{booking.id}: {len(job_ids)} шт.")
        except Exception as e:
            logger.error(f"Ошибка планирования напоминаний: {e}")

    @classmethod
    async def remove_reminders(cls, booking_id: int):
        job_ids = reminder_jobs.pop(booking_id, [])
        for job_id in job_ids:
            try:
                scheduler.remove_job(job_id)
            except Exception:
                pass

    @classmethod
    async def _send_reminder(cls, booking_id: int, hours: int):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            booking = await repo.get_by_id(booking_id)
            if not booking or booking.status != "confirmed":
                return
            if booking.is_manual and (not booking.client or booking.client.telegram_id == 0):
                return
            try:
                bot = await cls.get_bot()
                if hours == 24:
                    text = f"🔔 <b>Напоминаем!</b>\n\nЗавтра в {booking.time} у вас запись к {booking.master.name}.\nУслуга: {booking.service.name}\n📍 ул. Чернышевского, 52Б"
                else:
                    text = f"⏰ <b>Запись через 2 часа!</b>\n\nСегодня в {booking.time}, мастер: {booking.master.name}\nУслуга: {booking.service.name}\n📍 ул. Чернышевского, 52Б"
                await bot.send_message(booking.client.telegram_id, text)
                await bot.session.close()
                await repo.mark_reminder_sent(booking_id)
                await session.commit()
            except Exception as e:
                logger.error(f"Ошибка отправки напоминания: {e}")

    @classmethod
    async def restore_reminders(cls):
        from app.database import async_session
        from app.repositories.booking_repo import BookingRepository
        async with async_session() as session:
            repo = BookingRepository(session)
            bookings = await repo.get_upcoming_confirmed()
            count = 0
            for b in bookings:
                if not b.is_manual or (b.client and b.client.telegram_id != 0):
                    await cls.schedule_reminders(b)
                    count += 1
            logger.info(f"Восстановлено напоминаний для {count} записей")
EOF

cat > app/services/booking_service.py << 'EOF'
from datetime import date, datetime
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.master_repo import MasterRepository
from app.repositories.service_repo import ServiceRepository
from app.repositories.weekend_repo import WeekendRepository
from app.config import settings
from app.logger import logger
from app.services.notification_service import NotificationService

class BookingService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.master_repo = MasterRepository(session)
        self.service_repo = ServiceRepository(session)
        self.weekend_repo = WeekendRepository(session)

    async def create_booking(self, telegram_id: int, chat_id: int, username: str | None, first_name: str | None, last_name: str | None, service_id: int, master_id: int, booking_date: str, booking_time: str):
        today = date.today().isoformat()
        if booking_date < today:
            raise ValueError("Нельзя записаться на прошедшую дату")
        if booking_date == today:
            now = datetime.now().strftime("%H:%M")
            if booking_time <= now:
                raise ValueError("Нельзя записаться на прошедшее время")
        dt = datetime.strptime(booking_date, "%Y-%m-%d")
        weekend_days = await self.weekend_repo.get_all()
        if dt.weekday() in weekend_days:
            raise ValueError("Барбершоп не работает в этот день недели")
        service = await self.service_repo.get_by_id(service_id)
        if not service or not service.is_active:
            raise ValueError("Услуга не найдена или неактивна")
        master = await self.master_repo.get_by_id(master_id)
        if not master or not master.is_active:
            raise ValueError("Мастер не найден или неактивен")
        if await self.master_repo.is_day_off(master_id, booking_date):
            raise ValueError("У мастера выходной в этот день")
        client = await self.client_repo.get_or_create(telegram_id=telegram_id, chat_id=chat_id, username=username, first_name=first_name, last_name=last_name)
        active_count = await self.booking_repo.get_active_count(client.id)
        if active_count >= settings.MAX_ACTIVE_BOOKINGS:
            raise ValueError(f"У вас уже {active_count} активных записей. Максимум: {settings.MAX_ACTIVE_BOOKINGS}")
        available, slot_times = await self.booking_repo.check_slot_available(master_id, booking_date, booking_time, service.duration_minutes)
        if not available:
            raise ValueError("Слот уже занят")
        day_count = await self.booking_repo.get_master_day_bookings_count(master_id, booking_date)
        if day_count >= (master.max_bookings_per_day or settings.DEFAULT_MAX_BOOKINGS_PER_DAY):
            alternatives = await self.master_repo.get_available_masters_for_slot(booking_date, booking_time, service_id, master_id)
            if alternatives:
                names = ", ".join([f"{m.name} (⭐{m.rating})" for m in alternatives[:3]])
                raise ValueError(f"alternatives|{names}")
            raise ValueError(f"Мастер {master.name} полностью занят на этот день. Других свободных мастеров нет.")
        booking = Booking(client_id=client.id, master_id=master.id, service_id=service.id, date=booking_date, time=booking_time, duration_minutes=service.duration_minutes)
        await self.booking_repo.create(booking)
        await self.client_repo.increment_visits(client.id)
        await self.session.commit()
        await self.session.refresh(booking)
        await self.session.refresh(booking, ["client", "master", "service"])
        await NotificationService.notify_admin_new_booking(booking)
        await NotificationService.notify_client_confirmation(booking)
        await NotificationService.schedule_reminders(booking)
        logger.info(f"Запись создана: #{booking.id}, клиент: {telegram_id}")
        return {"ok": True, "booking_id": booking.id, "master": master.name, "service": service.name, "price": service.price, "date": booking.date, "time": booking.time}

    async def create_manual_booking(self, client_name: str, phone: str | None, service_id: int, master_id: int, booking_date: str, booking_time: str, admin_id: int):
        today = date.today().isoformat()
        if booking_date < today:
            raise ValueError("Нельзя записаться на прошедшую дату")
        if booking_date == today:
            now = datetime.now().strftime("%H:%M")
            if booking_time <= now:
                raise ValueError("Нельзя записаться на прошедшее время")
        dt = datetime.strptime(booking_date, "%Y-%m-%d")
        weekend_days = await self.weekend_repo.get_all()
        if dt.weekday() in weekend_days:
            raise ValueError("Барбершоп не работает в этот день недели")
        service = await self.service_repo.get_by_id(service_id)
        if not service or not service.is_active:
            raise ValueError("Услуга не найдена или неактивна")
        master = await self.master_repo.get_by_id(master_id)
        if not master or not master.is_active:
            raise ValueError("Мастер не найден или неактивен")
        if await self.master_repo.is_day_off(master_id, booking_date):
            raise ValueError("У мастера выходной в этот день")
        available, slot_times = await self.booking_repo.check_slot_available(master_id, booking_date, booking_time, service.duration_minutes)
        if not available:
            raise ValueError("Слот уже занят")
        day_count = await self.booking_repo.get_master_day_bookings_count(master_id, booking_date)
        if day_count >= (master.max_bookings_per_day or settings.DEFAULT_MAX_BOOKINGS_PER_DAY):
            raise ValueError(f"Мастер {master.name} полностью занят на этот день")
        client = await self.client_repo.get_or_create_manual(first_name=client_name, phone_number=phone)
        booking = Booking(client_id=client.id, master_id=master.id, service_id=service.id, date=booking_date, time=booking_time, duration_minutes=service.duration_minutes, is_manual=True, manual_client_name=client_name, manual_phone=phone)
        await self.booking_repo.create(booking)
        await self.client_repo.increment_visits(client.id)
        await self.session.commit()
        await self.session.refresh(booking)
        await self.session.refresh(booking, ["client", "master", "service"])
        await NotificationService.notify_admin_new_booking(booking)
        if phone:
            tg_client = await self.client_repo.get_by_phone(phone)
            if tg_client and tg_client.telegram_id and tg_client.telegram_id != 0:
                try:
                    await NotificationService.notify_manual_booking(booking, tg_client)
                except Exception as e:
                    logger.error(f"Ошибка уведомления по телефону: {e}")
        await NotificationService.schedule_reminders(booking)
        logger.info(f"Ручная запись создана: #{booking.id}, админ: {admin_id}")
        return {"ok": True, "booking_id": booking.id, "master": master.name, "service": service.name, "price": service.price, "date": booking.date, "time": booking.time, "client_name": client_name}

    async def cancel_booking(self, booking_id: int, telegram_id: int, is_admin: bool = False):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.status != "confirmed":
            raise ValueError("Запись уже отменена")
        if not is_admin:
            client = await self.client_repo.get_by_telegram_id(telegram_id)
            if not client or booking.client_id != client.id:
                raise ValueError("Это не ваша запись")
        reason = "admin_cancel" if is_admin else "client_cancel"
        await self.booking_repo.cancel(booking_id, reason)
        await NotificationService.remove_reminders(booking_id)
        await self.session.commit()
        logger.info(f"Запись #{booking_id} отменена, причина: {reason}")
        return {"ok": True, "message": "Запись отменена"}

    async def set_master_day_off(self, master_id: int, date_str: str, reason: str | None, admin_id: int):
        master = await self.master_repo.get_by_id(master_id)
        if not master:
            raise ValueError("Мастер не найден")
        await self.master_repo.add_day_off(master_id, date_str, reason)
        bookings = await self.booking_repo.get_confirmed_for_master_date(master_id, date_str)
        for b in bookings:
            if not b.is_manual:
                await NotificationService.notify_master_day_off(b, reason or "Выходной день мастера")
            await NotificationService.remove_reminders(b.id)
        await self.booking_repo.cancel_all_for_master_date(master_id, date_str, "master_day_off")
        await self.session.commit()
        logger.info(f"Выходной мастера #{master_id} на {date_str}, отменено записей: {len(bookings)}")
        return {"ok": True, "cancelled_bookings": len(bookings)}
EOF

echo "Часть 4 готова"
cat > app/services/review_service.py << 'EOF'
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.review import Review
from app.repositories.review_repo import ReviewRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository
from app.repositories.master_repo import MasterRepository
from app.config import settings

class ReviewService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.review_repo = ReviewRepository(session)
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)
        self.master_repo = MasterRepository(session)

    async def create_review(self, client_id: int, booking_id: int, rating: int, comment: str | None = None):
        booking = await self.booking_repo.get_by_id(booking_id)
        if not booking:
            raise ValueError("Запись не найдена")
        if booking.client_id != client_id:
            raise ValueError("Это не ваша запись")
        existing = await self.review_repo.get_by_booking_id(booking_id)
        if existing:
            raise ValueError("Отзыв уже оставлен")
        review = Review(client_id=client_id, master_id=booking.master_id, booking_id=booking_id, rating=rating, comment=comment)
        await self.review_repo.create(review)
        await self.master_repo.update_rating(booking.master_id)
        total_reviews = await self.review_repo.count_by_client(client_id)
        if total_reviews % settings.BONUS_VISITS_INTERVAL == 0:
            await self.client_repo.add_bonus(client_id, settings.BONUS_AMOUNT)
            await self.session.commit()
            return {"ok": True, "review_id": review.id, "bonus_added": True, "bonus_amount": settings.BONUS_AMOUNT}
        await self.session.commit()
        return {"ok": True, "review_id": review.id, "bonus_added": False}
EOF

cat > app/services/stats_service.py << 'EOF'
from sqlalchemy.ext.asyncio import AsyncSession
from app.repositories.booking_repo import BookingRepository
from app.repositories.client_repo import ClientRepository

class StatsService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.booking_repo = BookingRepository(session)
        self.client_repo = ClientRepository(session)

    async def get_stats(self):
        today_bookings = await self.booking_repo.get_today_bookings()
        total_clients = await self.client_repo.get_total_count()
        today_revenue = await self.booking_repo.get_today_revenue()
        return {"today_bookings": len(today_bookings), "total_clients": total_clients, "today_revenue": today_revenue}
EOF

cat > app/services/broadcast_service.py << 'EOF'
import asyncio, os
from aiogram import Bot
from aiogram.client.default import DefaultBotProperties
from aiogram.types import BufferedInputFile
from app.config import settings
from app.repositories.client_repo import ClientRepository
from app.logger import logger

class BroadcastService:
    @staticmethod
    async def send_broadcast(text: str, session, photo_path: str | None = None):
        client_repo = ClientRepository(session)
        all_ids = await client_repo.get_all_telegram_ids()
        bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
        success = 0
        failed = 0
        photo_bytes = None
        if photo_path:
            full_path = os.path.join(photo_path.lstrip("/"))
            if os.path.exists(full_path):
                with open(full_path, "rb") as f:
                    photo_bytes = f.read()
        for tg_id in all_ids:
            try:
                if photo_bytes:
                    photo = BufferedInputFile(photo_bytes, filename="broadcast.jpg")
                    await bot.send_photo(tg_id, photo, caption=text or "")
                else:
                    await bot.send_message(tg_id, text or "")
                success += 1
                await asyncio.sleep(0.05)
            except Exception as e:
                logger.error(f"Ошибка отправки {tg_id}: {e}")
                failed += 1
        await bot.session.close()
        return {"ok": True, "sent": success, "failed": failed}
EOF

cat > app/api/__init__.py << 'EOF'
EOF

cat > app/api/schemas/__init__.py << 'EOF'
EOF

cat > app/api/schemas/booking.py << 'EOF'
from pydantic import BaseModel, Field

class BookingCreateSchema(BaseModel):
    telegram_id: int
    chat_id: int
    username: str | None = None
    first_name: str | None = None
    last_name: str | None = None
    service_id: int = Field(gt=0)
    master_id: int = Field(gt=0)
    date: str
    time: str

class ManualBookingSchema(BaseModel):
    admin_telegram_id: int
    client_name: str = Field(min_length=1, max_length=255)
    phone: str | None = None
    service_id: int = Field(gt=0)
    master_id: int = Field(gt=0)
    date: str
    time: str

class BookingCancelSchema(BaseModel):
    telegram_id: int
    booking_id: int

class AdminCancelSchema(BaseModel):
    admin_telegram_id: int
    booking_id: int

class MasterDayOffSchema(BaseModel):
    admin_telegram_id: int
    master_id: int
    date: str
    reason: str | None = None
EOF

cat > app/api/schemas/master.py << 'EOF'
from pydantic import BaseModel, Field

class MasterCreateSchema(BaseModel):
    admin_telegram_id: int
    name: str = Field(min_length=1, max_length=255)
    photo_url: str | None = None
    experience_years: int = Field(default=0, ge=0)
    telegram_id: int | None = None
    max_bookings_per_day: int = Field(default=15, ge=1)
    is_admin: bool = False

class MasterUpdateSchema(BaseModel):
    admin_telegram_id: int
    name: str | None = Field(default=None, min_length=1, max_length=255)
    photo_url: str | None = None
    experience_years: int | None = Field(default=None, ge=0)
    telegram_id: int | None = None
    max_bookings_per_day: int | None = Field(default=None, ge=1)
    is_admin: bool | None = None

class MasterToggleSchema(BaseModel):
    admin_telegram_id: int
    master_id: int
EOF

cat > app/api/schemas/service.py << 'EOF'
from pydantic import BaseModel, Field

class ServiceCreateSchema(BaseModel):
    admin_telegram_id: int
    name: str = Field(min_length=1, max_length=255)
    price: int = Field(gt=0)
    duration_minutes: int = Field(gt=0)
    category: str | None = None

class ServiceUpdateSchema(BaseModel):
    admin_telegram_id: int
    name: str | None = Field(default=None, min_length=1, max_length=255)
    price: int | None = Field(default=None, gt=0)
    duration_minutes: int | None = Field(default=None, gt=0)
    category: str | None = None

class ServiceToggleSchema(BaseModel):
    admin_telegram_id: int
    service_id: int
EOF

cat > app/api/schemas/review.py << 'EOF'
from pydantic import BaseModel, Field

class ReviewCreateSchema(BaseModel):
    telegram_id: int
    booking_id: int
    rating: int = Field(ge=1, le=5)
    comment: str | None = None
EOF

cat > app/api/schemas/response.py << 'EOF'
from pydantic import BaseModel

class BookingResponse(BaseModel):
    ok: bool
    booking_id: int | None = None
    master: str | None = None
    service: str | None = None
    price: int | None = None
    date: str | None = None
    time: str | None = None
    message: str | None = None
    client_name: str | None = None
    alternatives: str | None = None

class ReviewResponse(BaseModel):
    ok: bool
    review_id: int | None = None
    bonus_added: bool = False
    bonus_amount: int = 0

class StatsResponse(BaseModel):
    today_bookings: int
    total_clients: int
    today_revenue: int

class BroadcastSchema(BaseModel):
    admin_telegram_id: int
    text: str = ""
    photo_path: str | None = None
EOF

echo "Часть 5 готова"
cat > app/api/routes/__init__.py << 'EOF'
EOF

cat > app/api/routes/upload.py << 'EOF'
import uuid, os
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form
from app.core.security import is_admin
from app.config import settings

router = APIRouter(prefix="/api", tags=["upload"])

@router.post("/admin/upload-photo")
async def upload_photo(admin_telegram_id: int = Form(...), photo: UploadFile = File(...)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    if not photo.content_type or not photo.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Только изображения")
    ext = os.path.splitext(photo.filename or "photo.jpg")[1] or ".jpg"
    filename = f"{uuid.uuid4().hex}{ext}"
    upload_dir = settings.UPLOAD_DIR
    os.makedirs(upload_dir, exist_ok=True)
    filepath = os.path.join(upload_dir, filename)
    content = await photo.read()
    with open(filepath, "wb") as f:
        f.write(content)
    return {"ok": True, "path": f"/static/uploads/{filename}"}
EOF

cat > app/api/routes/weekend.py << 'EOF'
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
EOF

cat > app/api/routes/booking.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.booking import BookingCreateSchema, ManualBookingSchema, BookingCancelSchema, AdminCancelSchema, MasterDayOffSchema
from app.services.booking_service import BookingService
from app.core.security import is_admin
from app.repositories.audit_repo import AuditRepository

router = APIRouter(prefix="/api", tags=["booking"])

@router.post("/book")
async def create_booking(data: BookingCreateSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.create_booking(telegram_id=data.telegram_id, chat_id=data.chat_id, username=data.username, first_name=data.first_name, last_name=data.last_name, service_id=data.service_id, master_id=data.master_id, booking_date=data.date, booking_time=data.time)
        return result
    except ValueError as e:
        msg = str(e)
        if msg.startswith("alternatives|"):
            return {"ok": False, "detail": msg}
        raise HTTPException(status_code=400, detail=msg)

@router.post("/admin/manual-booking")
async def create_manual_booking(data: ManualBookingSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.create_manual_booking(client_name=data.client_name, phone=data.phone, service_id=data.service_id, master_id=data.master_id, booking_date=data.date, booking_time=data.time, admin_id=data.admin_telegram_id)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "manual_booking", f"client={data.client_name}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/cancel")
async def cancel_booking(data: BookingCancelSchema, session: AsyncSession = Depends(get_session)):
    try:
        service = BookingService(session)
        result = await service.cancel_booking(booking_id=data.booking_id, telegram_id=data.telegram_id, is_admin=False)
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/cancel")
async def admin_cancel_booking(data: AdminCancelSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.cancel_booking(booking_id=data.booking_id, telegram_id=data.admin_telegram_id, is_admin=True)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "cancel_booking", f"booking_id={data.booking_id}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.post("/admin/master-day-off")
async def set_master_day_off(data: MasterDayOffSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    try:
        service = BookingService(session)
        result = await service.set_master_day_off(data.master_id, data.date, data.reason, data.admin_telegram_id)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "master_day_off", f"master_id={data.master_id} date={data.date}")
        await session.commit()
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
EOF

cat > app/api/routes/slots.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.booking_repo import BookingRepository

router = APIRouter(prefix="/api", tags=["slots"])

@router.get("/booked-slots")
async def get_booked_slots(date: str = Query(...), master_id: int = Query(...), session: AsyncSession = Depends(get_session)):
    repo = BookingRepository(session)
    times = await repo.get_booked_slots(master_id, date)
    return [{"time": t} for t in times]
EOF

cat > app/api/routes/services.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.service_repo import ServiceRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.service import ServiceCreateSchema, ServiceUpdateSchema, ServiceToggleSchema
from app.models.service import Service
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["services"])

@router.get("/services")
async def get_services(session: AsyncSession = Depends(get_session)):
    repo = ServiceRepository(session)
    services = await repo.get_all_active()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category} for s in services]

@router.get("/admin/services")
async def get_all_services(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    services = await repo.get_all()
    return [{"id": s.id, "name": s.name, "price": s.price, "duration": s.duration_minutes, "category": s.category, "is_active": s.is_active} for s in services]

@router.post("/admin/services")
async def create_service(data: ServiceCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    service = Service(name=data.name, price=data.price, duration_minutes=data.duration_minutes, category=data.category)
    result = await repo.create(service)
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "create_service", f"name={data.name}")
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/services/{service_id}")
async def update_service(service_id: int, data: ServiceUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await repo.update_fields(service_id, **updates)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "update_service", f"service_id={service_id} {updates}")
        await session.commit()
    return {"ok": True}

@router.post("/admin/services/{service_id}/toggle")
async def toggle_service(service_id: int, data: ServiceToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = ServiceRepository(session)
    service = await repo.toggle_active(service_id)
    if not service:
        raise HTTPException(status_code=404, detail="Услуга не найдена")
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "toggle_service", f"service_id={service_id}")
    await session.commit()
    return {"ok": True, "is_active": service.is_active}
EOF

cat > app/api/routes/masters.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.master_repo import MasterRepository
from app.repositories.audit_repo import AuditRepository
from app.api.schemas.master import MasterCreateSchema, MasterUpdateSchema, MasterToggleSchema
from app.models.master import Master
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["masters"])

@router.get("/masters")
async def get_masters(session: AsyncSession = Depends(get_session)):
    repo = MasterRepository(session)
    masters = await repo.get_all_active()
    return [{"id": m.id, "name": m.name, "photo": m.photo_url, "rating": m.rating, "experience": m.experience_years, "max_bookings": m.max_bookings_per_day} for m in masters]

@router.get("/admin/masters")
async def get_all_masters(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    masters = await repo.get_all()
    return [{"id": m.id, "name": m.name, "photo": m.photo_url, "rating": m.rating, "experience": m.experience_years, "telegram_id": m.telegram_id, "max_bookings": m.max_bookings_per_day, "is_admin": m.is_admin, "is_active": m.is_active} for m in masters]

@router.post("/admin/masters")
async def create_master(data: MasterCreateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    master = Master(name=data.name, photo_url=data.photo_url, experience_years=data.experience_years, telegram_id=data.telegram_id, max_bookings_per_day=data.max_bookings_per_day, is_admin=data.is_admin)
    result = await repo.create(master)
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "create_master", f"name={data.name}")
    await session.commit()
    return {"ok": True, "id": result.id}

@router.put("/admin/masters/{master_id}")
async def update_master(master_id: int, data: MasterUpdateSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    updates = {k: v for k, v in data.model_dump(exclude={"admin_telegram_id"}).items() if v is not None}
    if updates:
        await repo.update_fields(master_id, **updates)
        audit = AuditRepository(session)
        await audit.log(data.admin_telegram_id, "update_master", f"master_id={master_id} {updates}")
        await session.commit()
    return {"ok": True}

@router.post("/admin/masters/{master_id}/toggle")
async def toggle_master(master_id: int, data: MasterToggleSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = MasterRepository(session)
    master = await repo.toggle_active(master_id)
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "toggle_master", f"master_id={master_id}")
    await session.commit()
    return {"ok": True, "is_active": master.is_active}
EOF

echo "Часть 6 готова"
cat > app/api/routes/reviews.py << 'EOF'
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
EOF

cat > app/api/routes/stats.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.stats_service import StatsService
from app.repositories.booking_repo import BookingRepository
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["stats"])

@router.get("/admin/stats")
async def get_stats(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    return await StatsService(session).get_stats()

@router.get("/admin/today-bookings")
async def get_today_bookings(admin_telegram_id: int, master_id: int | None = Query(default=None), session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    repo = BookingRepository(session)
    bookings = await repo.get_today_bookings(master_id=master_id)
    return [{"id": b.id, "client_name": b.client.first_name or b.manual_client_name or "—", "client_username": b.client.username or "—", "master": b.master.name, "service": b.service.name, "time": b.time, "price": b.service.price, "is_manual": b.is_manual} for b in bookings]

@router.get("/admin/audit-log")
async def get_audit_log(admin_telegram_id: int, session: AsyncSession = Depends(get_session)):
    if not is_admin(admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    logs = await AuditRepository(session).get_recent()
    return [{"id": l.id, "admin_id": l.admin_id, "action": l.action, "details": l.details, "created_at": l.created_at.isoformat() if l.created_at else None} for l in logs]
EOF

cat > app/api/routes/broadcast.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.api.schemas.response import BroadcastSchema
from app.services.broadcast_service import BroadcastService
from app.repositories.audit_repo import AuditRepository
from app.core.security import is_admin

router = APIRouter(prefix="/api", tags=["broadcast"])

@router.post("/admin/broadcast")
async def send_broadcast(data: BroadcastSchema, session: AsyncSession = Depends(get_session)):
    if not is_admin(data.admin_telegram_id):
        raise HTTPException(status_code=403, detail="Нет доступа")
    result = await BroadcastService.send_broadcast(data.text, session, data.photo_path)
    audit = AuditRepository(session)
    await audit.log(data.admin_telegram_id, "broadcast", f"sent={result['sent']}")
    await session.commit()
    return result
EOF

cat > app/api/routes/profile.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.repositories.client_repo import ClientRepository
from app.repositories.booking_repo import BookingRepository
from app.repositories.review_repo import ReviewRepository
from app.repositories.master_repo import MasterRepository
from app.config import settings

router = APIRouter(prefix="/api", tags=["profile"])

@router.get("/profile")
async def get_profile(telegram_id: int, session: AsyncSession = Depends(get_session)):
    client = await ClientRepository(session).get_by_telegram_id(telegram_id)
    if not client:
        return {"exists": False}
    booking_repo = BookingRepository(session)
    review_repo = ReviewRepository(session)
    master_repo = MasterRepository(session)
    bookings = await booking_repo.get_client_bookings(client.id)
    past_bookings = await booking_repo.get_past_confirmed(client.id)
    reviews = await review_repo.get_by_client(client.id)
    all_masters = await master_repo.get_all()
    master_info = None
    for m in all_masters:
        if m.telegram_id == telegram_id:
            master_info = {"master_id": m.id, "is_admin": m.is_admin, "name": m.name}
            break
    return {"exists": True, "first_name": client.first_name, "username": client.username, "bonus_balance": client.bonus_balance, "total_visits": client.total_visits, "referral_code": client.referral_code, "visits_to_next_bonus": settings.BONUS_VISITS_INTERVAL - (client.total_visits % settings.BONUS_VISITS_INTERVAL), "master_info": master_info, "bookings": [{"id": b.id, "master": b.master.name, "service": b.service.name, "date": b.date, "time": b.time, "price": b.service.price, "status": b.status, "is_manual": b.is_manual} for b in bookings], "past_bookings_for_review": [{"id": b.id, "master": b.master.name, "service": b.service.name, "date": b.date, "time": b.time} for b in past_bookings], "my_reviews": [{"id": r.id, "booking_id": r.booking_id, "master_name": r.master.name if r.master else "—", "rating": r.rating, "comment": r.comment} for r in reviews]}
EOF

cat > app/bot/__init__.py << 'EOF'
EOF

cat > app/bot/main.py << 'EOF'
import asyncio, sys
from aiogram import Bot, Dispatcher
from aiogram.client.default import DefaultBotProperties
from app.config import settings
from app.bot.handlers.start import router as start_router
from app.logger import logger

async def main():
    logger.info("Bot starting...")
    bot = Bot(token=settings.BOT_TOKEN, default=DefaultBotProperties(parse_mode="HTML"))
    dp = Dispatcher()
    dp.include_router(start_router)
    logger.info("Bot ready")
    await dp.start_polling(bot, drop_pending_updates=True)

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Bot stopped")
    except Exception as e:
        logger.exception(f"Fatal error: {e}")
        sys.exit(1)
EOF

cat > app/bot/handlers/__init__.py << 'EOF'
EOF

cat > app/bot/handlers/start.py << 'EOF'
from aiogram import Router
from aiogram.filters import CommandStart
from aiogram.types import Message, WebAppInfo
from aiogram.utils.keyboard import InlineKeyboardBuilder
from app.config import settings

router = Router()

@router.message(CommandStart())
async def cmd_start(message: Message):
    builder = InlineKeyboardBuilder()
    builder.button(text="✂️ Записаться", web_app=WebAppInfo(url=f"{settings.BASE_URL}/mini-app"))
    builder.button(text="🔗 Поделиться ботом", switch_inline_query=f"Запись в BARBERSHOP: https://t.me/{settings.BOT_USERNAME}")
    builder.adjust(1)
    await message.answer("<b>BARBERSHOP</b>\n\nДобро пожаловать!\nул. Чернышевского, 52Б\nЕжедневно 10:00 – 21:00\n\n<i>Нажмите кнопку ниже, чтобы записаться:</i>", reply_markup=builder.as_markup())
EOF

echo "Часть 7 готова"
cat > app/static/index.html << 'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <title>Barbershop</title>
    <script src="https://telegram.org/js/telegram-web-app.js"></script>
    <link rel="stylesheet" href="/static/styles.css">
</head>
<body>
    <div class="header"><h1>BARBERSHOP</h1><p>Премиум-запись</p></div>
    <div id="app"></div>
    <div class="footer">ул. Чернышевского, 52Б | 10:00 – 21:00</div>
    <script src="/static/app.js"></script>
</body>
</html>
EOF

cat > app/static/styles.css << 'EOF'
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0d0d0d;color:#f5f5f5;padding:16px;min-height:100vh;display:flex;flex-direction:column}
.header{text-align:center;padding:24px 0 16px;border-bottom:1px solid #222;margin-bottom:20px}
.header h1{font-size:26px;color:#c9a96e;letter-spacing:1px}
.header p{color:#888;font-size:13px;margin-top:4px}
#app{flex:1}
h2{margin-bottom:16px;color:#c9a96e;font-size:20px;font-weight:600}
.menu-grid{display:grid;grid-template-columns:repeat(2,1fr);gap:12px}
.menu-item{background:#1a1a1a;padding:20px 16px;border-radius:16px;cursor:pointer;transition:all 0.2s;text-align:center;border:2px solid transparent;display:flex;flex-direction:column;align-items:center;gap:8px}
.menu-item:hover{background:#222;border-color:#333}
.menu-item .icon{font-size:32px}
.menu-item .label{font-size:14px;color:#ccc;font-weight:500}
.option{background:#1a1a1a;padding:14px;margin:8px 0;border-radius:14px;cursor:pointer;transition:all 0.2s;border:2px solid transparent;display:flex;align-items:center;gap:12px}
.option:hover{background:#222;border-color:#333}
.option.selected{border-color:#c9a96e;background:#1a1a1a;box-shadow:0 0 20px rgba(201,169,110,0.15)}
.option img{width:52px;height:52px;border-radius:50%;object-fit:cover}
.option .info{flex:1}
.option .info b{display:block;font-size:15px;margin-bottom:2px}
.option .info span{font-size:13px;color:#999}
.btn-group{display:flex;gap:10px;margin-top:16px}
button{padding:14px 20px;border:none;border-radius:14px;font-size:15px;font-weight:600;cursor:pointer;transition:all 0.2s;flex:1}
.btn-next{background:#c9a96e;color:#0d0d0d}
.btn-back{background:#222;color:#ccc}
.btn-confirm{background:#4CAF50;color:#fff;font-size:16px}
.btn-cancel{background:#c0392b;color:#fff}
.btn-admin{background:#c9a96e;color:#0d0d0d;font-size:13px;padding:10px 16px}
.btn-send{background:#4CAF50;color:#fff;font-size:16px}
.btn-dayoff{background:#e67e22;color:#fff;font-size:13px;padding:8px 12px}
.btn-photo{background:#8e44ad;color:#fff;font-size:14px;padding:12px;width:100%;text-align:center;border-radius:14px;cursor:pointer;margin-top:8px}
.btn-manual{background:#3498db;color:#fff;font-size:16px;padding:14px 20px;width:100%;border-radius:14px;cursor:pointer;margin-top:8px}
.btn-alt{background:#f39c12;color:#fff;font-size:14px;padding:10px 14px;border-radius:14px;cursor:pointer;margin-top:8px;width:100%}
.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:16px 0}
.grid div{background:#1a1a1a;padding:14px 8px;border-radius:12px;text-align:center;cursor:pointer;transition:all 0.2s;border:2px solid transparent;font-size:14px}
.grid div:hover{background:#222;border-color:#333}
.grid div.selected{border-color:#c9a96e;background:#1a1a1a;box-shadow:0 0 15px rgba(201,169,110,0.2)}
.grid div.booked{background:#1a0a0a;color:#666;cursor:not-allowed;text-decoration:line-through}
.grid div.weekend{background:#1a0a0a;color:#c0392b;cursor:not-allowed}
.summary{background:#1a1a1a;padding:20px;border-radius:16px;margin:8px 0}
.summary-item{display:flex;justify-content:space-between;padding:12px 0;border-bottom:1px solid #222}
.summary-item:last-child{border-bottom:none}
.summary-item span{color:#888;font-size:14px}
.summary-item strong{color:#f5f5f5;font-size:15px}
.summary-item.total strong{color:#c9a96e;font-size:20px}
.card{background:#1a1a1a;padding:16px;margin:8px 0;border-radius:14px}
.card .row{display:flex;justify-content:space-between;align-items:center;margin:6px 0}
.card .label{color:#888;font-size:13px}
.card .value{color:#f5f5f5;font-size:15px;font-weight:500}
.card .value.green{color:#4CAF50}
.stars{display:flex;gap:4px;justify-content:center;margin:12px 0}
.star{font-size:32px;cursor:pointer;color:#555;transition:0.2s}
.star.active{color:#f1c40f}
.star.readonly{cursor:default}
.form-group{margin:12px 0}
.form-group label{display:block;color:#888;font-size:13px;margin-bottom:4px}
.form-group input,.form-group textarea{width:100%;padding:12px;background:#1a1a1a;border:1px solid #333;border-radius:12px;color:#f5f5f5;font-size:15px;resize:vertical}
.form-group textarea{min-height:80px}
.status-badge{display:inline-block;padding:4px 10px;border-radius:20px;font-size:12px;font-weight:600}
.status-active{background:#1a3a1a;color:#4CAF50}
.status-inactive{background:#3a1a1a;color:#c0392b}
.status-manual{background:#1a2a3a;color:#3498db}
.footer{text-align:center;padding:16px 0;color:#555;font-size:12px;border-top:1px solid #222;margin-top:auto}
select{width:100%;padding:12px;background:#1a1a1a;border:1px solid #333;border-radius:12px;color:#f5f5f5;font-size:15px}
.preview-img{width:80px;height:80px;border-radius:12px;object-fit:cover;margin:8px 0;border:2px solid #333}
.file-selected{color:#4CAF50;font-size:13px;margin-top:4px}
EOF

echo "Часть 8 готова"
cat > app/static/app.js << 'EOF'
const tg = window.Telegram?.WebApp;
tg?.expand?.();
tg?.ready?.();
tg?.setHeaderColor?.('#0d0d0d');
tg?.setBackgroundColor?.('#0d0d0d');

const user = tg?.initDataUnsafe?.user || null;
const ADMIN_IDS = [5724746367];
const isAdmin = user && ADMIN_IDS.includes(user.id);

let state = {
    screen: 'menu', svc: null, mst: null, date: null, time: null,
    services: [], masters: [], bookings: [], pastBookings: [], myReviews: [],
    profile: null, masterInfo: null, isMaster: false, isMasterAdmin: false,
    stats: null, todayBookings: [], allServices: [], allMasters: [], allReviews: [],
    isSubmitting: false, todayFilterMaster: null,
    selectedPhotoFile: null, selectedPhotoPath: null, broadcastPhotoFile: null,
    manualSvc: null, manualMst: null, manualDate: null, manualTime: null,
    manualClientName: '', manualPhone: '', weekendDays: []
};

async function api(url, options = {}) {
    try { const res = await fetch(url, options); return await res.json(); }
    catch (e) { console.error(e); return { error: true }; }
}

async function uploadPhoto(file) {
    if (!file) return { ok: false };
    const fd = new FormData(); fd.append('photo', file); fd.append('admin_telegram_id', user?.id || 0);
    try { const res = await fetch('/api/admin/upload-photo', { method: 'POST', body: fd }); return await res.json(); }
    catch { return { ok: false }; }
}

async function ld() {
    try {
        state.services = await api('/api/services') || [];
        state.masters = await api('/api/masters') || [];
        state.weekendDays = await api('/api/weekend-days') || [];
        if (user) {
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) {
                state.profile = p;
                state.bookings = p.bookings || [];
                state.pastBookings = p.past_bookings_for_review || [];
                state.myReviews = p.my_reviews || [];
                state.masterInfo = p.master_info || null;
                state.isMaster = !!state.masterInfo;
                state.isMasterAdmin = state.masterInfo?.is_admin || false;
            }
        }
        if (isAdmin || state.isMasterAdmin) {
            state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`) || [];
            state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user?.id}`) || [];
            state.stats = await api(`/api/admin/stats?admin_telegram_id=${user?.id}`);
            state.todayBookings = await api(`/api/admin/today-bookings?admin_telegram_id=${user?.id}`) || [];
            state.allReviews = await api(`/api/admin/reviews?admin_telegram_id=${user?.id}`) || [];
        }
    } catch (e) { console.error(e); }
    rn(state.screen);
}

function rn(screen) {
    state.screen = screen;
    const app = document.getElementById('app');
    if (!app) return;
    app.innerHTML = '';
    const screens = {
        menu: renderMenu, booking_service: renderBookingService, booking_master: renderBookingMaster,
        booking_date: renderBookingDate, booking_time: renderBookingTime, booking_confirm: renderBookingConfirm,
        my_bookings: renderMyBookings, reviews: renderReviews, my_reviews_history: renderMyReviewsHistory,
        bonuses: renderBonuses, admin_stats: renderAdminStats, admin_today: renderAdminToday,
        admin_masters: renderAdminMasters, admin_services: renderAdminServices,
        admin_broadcast: renderAdminBroadcast, admin_audit: renderAdminAudit, admin_reviews: renderAdminReviews,
        admin_manual_booking: renderAdminManualBooking, manual_service: renderManualService,
        manual_master: renderManualMaster, manual_date: renderManualDate, manual_time: renderManualTime,
        manual_confirm: renderManualConfirm, admin_weekend: renderAdminWeekend
    };
    if (screens[screen]) screens[screen](app);
    else renderMenu(app);
}

function renderMenu(app) {
    app.innerHTML = '<h2>Меню</h2><div class="menu-grid"></div>';
    const grid = app.querySelector('.menu-grid');
    const items = [];
    const hasAdmin = isAdmin || state.isMasterAdmin;
    if (!hasAdmin) {
        items.push({ icon: '✂️', label: 'Записаться', action: () => rn('booking_service') });
        items.push({ icon: '📋', label: 'Мои записи', action: () => rn('my_bookings') });
        items.push({ icon: '⭐', label: 'Отзывы', action: () => rn('reviews') });
        items.push({ icon: '📝', label: 'Мои отзывы', action: () => rn('my_reviews_history') });
        items.push({ icon: '🎁', label: 'Бонусы', action: () => rn('bonuses') });
    } else {
        items.push({ icon: '📞', label: 'Запись по звонку', action: () => rn('admin_manual_booking') });
        items.push({ icon: '📊', label: 'Статистика', action: () => rn('admin_stats') });
        items.push({ icon: '📅', label: 'Записи сегодня', action: () => rn('admin_today') });
        items.push({ icon: '👥', label: 'Мастера', action: () => rn('admin_masters') });
        items.push({ icon: '💇', label: 'Услуги', action: () => rn('admin_services') });
        items.push({ icon: '👁️', label: 'Отзывы клиентов', action: () => rn('admin_reviews') });
        items.push({ icon: '📢', label: 'Рассылка', action: () => rn('admin_broadcast') });
        items.push({ icon: '📜', label: 'Аудит', action: () => rn('admin_audit') });
        items.push({ icon: '📅', label: 'Выходные дни', action: () => rn('admin_weekend') });
    }
    items.forEach(item => {
        const div = document.createElement('div'); div.className = 'menu-item';
        div.innerHTML = `<div class="icon">${item.icon}</div><div class="label">${item.label}</div>`;
        div.onclick = item.action; grid.appendChild(div);
    });
}

function renderBookingService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="svc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('svc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.svc = x; rn('booking_master'); }; c.appendChild(e);
    });
}

function renderBookingMaster(app) {
    app.innerHTML = '<h2>Выберите мастера</h2><div id="mst"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_service\')">← Назад</button></div>';
    const c = document.getElementById('mst');
    state.masters.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.mst = x; rn('booking_date'); }; c.appendChild(e);
    });
}

function renderBookingDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="dt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_master\')">← Назад</button></div>';
    const g = document.getElementById('dt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.date = ds; rn('booking_time'); }; }
        g.appendChild(b);
    }
}

async function renderBookingTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="tm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_date\')">← Назад</button></div>';
    const g = document.getElementById('tm');
    const bk = await api(`/api/booked-slots?date=${state.date}&master_id=${state.mst.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 10; h < 21; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.date === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.time = tm; rn('booking_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderBookingConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Услуга</span><strong id="sm_svc"></strong></div><div class="summary-item"><span>Мастер</span><strong id="sm_mst"></strong></div><div class="summary-item"><span>Дата</span><strong id="sm_dt"></strong></div><div class="summary-item"><span>Время</span><strong id="sm_tm"></strong></div><div class="summary-item total"><span>Цена</span><strong id="sm_pr"></strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'booking_time\')">← Назад</button><button class="btn-confirm" id="cfbtn" onclick="cf()">Подтвердить</button></div>';
    document.getElementById('sm_svc').textContent = state.svc?.name || '';
    document.getElementById('sm_mst').textContent = state.mst?.name || '';
    document.getElementById('sm_dt').textContent = state.date || '';
    document.getElementById('sm_tm').textContent = state.time || '';
    document.getElementById('sm_pr').textContent = (state.svc?.price || '') + '₽';
}

async function cf() {
    if (state.isSubmitting || !user) return;
    state.isSubmitting = true;
    const btn = document.getElementById('cfbtn'); btn.textContent = 'Создаём...'; btn.disabled = true;
    const payload = { telegram_id: user.id, chat_id: user.id, username: user.username || null, first_name: user.first_name || null, last_name: user.last_name || null, service_id: state.svc?.id, master_id: state.mst?.id, date: state.date, time: state.time };
    try {
        const res = await api('/api/book', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись подтверждена!\n\n${res.service}\nМастер: ${res.master}\n${res.date} в ${res.time}\nЦена: ${res.price}₽`);
            const p = await api(`/api/profile?telegram_id=${user.id}`);
            if (p?.exists) { state.profile = p; state.bookings = p.bookings || []; state.pastBookings = p.past_bookings_for_review || []; }
            rn('my_bookings');
        } else if (res.detail?.startsWith('alternatives|')) {
            const names = res.detail.split('|')[1];
            tg?.showAlert?.(`Мастер занят на этот день.\n\nСвободные мастера:\n${names}\n\nВыберите другого мастера.`);
            rn('booking_master');
        } else { tg?.showAlert?.(res.detail || 'Ошибка записи'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false; btn.textContent = 'Подтвердить'; btn.disabled = false;
}

function renderAdminManualBooking(app) {
    app.innerHTML = '<h2>📞 Запись по звонку</h2><div class="form-group"><label>Имя клиента</label><input id="mclient" value="' + (state.manualClientName || '') + '"></div><div class="form-group"><label>Телефон</label><input id="mphone" value="' + (state.manualPhone || '') + '"></div><button class="btn-manual" onclick="state.manualClientName=document.getElementById(\'mclient\').value;state.manualPhone=document.getElementById(\'mphone\').value;rn(\'manual_service\')">Далее: выбор услуги</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function renderManualService(app) {
    app.innerHTML = '<h2>Выберите услугу</h2><div id="msvc"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'admin_manual_booking\')">← Назад</button></div>';
    const c = document.getElementById('msvc');
    state.services.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<div class="info"><b>${x.name}</b><span>${x.duration} мин</span></div><strong style="color:#c9a96e">${x.price}₽</strong>`;
        e.onclick = () => { state.manualSvc = x; rn('manual_master'); }; c.appendChild(e);
    });
}

function renderManualMaster(app) {
    app.innerHTML = '<h2>Выберите мастера</h2><div id="mmst"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_service\')">← Назад</button></div>';
    const c = document.getElementById('mmst');
    state.masters.forEach(x => {
        const e = document.createElement('div'); e.className = 'option';
        e.innerHTML = `<img src="${x.photo || ''}" onerror="this.style.display=\'none\'"><div class="info"><b>${x.name}</b><span>⭐${x.rating} | Опыт ${x.experience} лет</span></div>`;
        e.onclick = () => { state.manualMst = x; rn('manual_date'); }; c.appendChild(e);
    });
}

function renderManualDate(app) {
    app.innerHTML = '<h2>Выберите дату</h2><div class="grid" id="mdt"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_master\')">← Назад</button></div>';
    const g = document.getElementById('mdt'); const t = new Date();
    for (let i = 0; i < 14; i++) {
        const d = new Date(t); d.setDate(t.getDate() + i);
        const ds = d.toISOString().split('T')[0]; const dow = d.getDay();
        const b = document.createElement('div');
        b.textContent = d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'short', weekday: 'short' });
        if (state.weekendDays.includes(dow)) { b.className = 'weekend'; b.textContent += ' (вых)'; }
        else { b.onclick = () => { state.manualDate = ds; rn('manual_time'); }; }
        g.appendChild(b);
    }
}

async function renderManualTime(app) {
    app.innerHTML = '<h2>Выберите время</h2><div class="grid" id="mtm"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_date\')">← Назад</button></div>';
    const g = document.getElementById('mtm');
    const bk = await api(`/api/booked-slots?date=${state.manualDate}&master_id=${state.manualMst?.id}`);
    const bt = (bk || []).map(x => x.time);
    const now = new Date(); const today = now.toISOString().split('T')[0];
    const curH = now.getHours(); const curM = now.getMinutes();
    for (let h = 10; h < 21; h++) {
        for (let m = 0; m < 60; m += 30) {
            const tm = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
            const b = document.createElement('div');
            const isPast = state.manualDate === today && (h < curH || (h === curH && m <= curM));
            if (bt.includes(tm) || isPast) { b.className = 'booked'; b.textContent = tm; }
            else { b.textContent = tm; b.onclick = () => { state.manualTime = tm; rn('manual_confirm'); }; }
            g.appendChild(b);
        }
    }
}

function renderManualConfirm(app) {
    app.innerHTML = '<h2>Подтверждение</h2><div class="summary"><div class="summary-item"><span>Клиент</span><strong>' + (state.manualClientName || '—') + '</strong></div><div class="summary-item"><span>Телефон</span><strong>' + (state.manualPhone || '—') + '</strong></div><div class="summary-item"><span>Услуга</span><strong>' + (state.manualSvc?.name || '') + '</strong></div><div class="summary-item"><span>Мастер</span><strong>' + (state.manualMst?.name || '') + '</strong></div><div class="summary-item"><span>Дата</span><strong>' + (state.manualDate || '') + '</strong></div><div class="summary-item"><span>Время</span><strong>' + (state.manualTime || '') + '</strong></div><div class="summary-item total"><span>Цена</span><strong>' + (state.manualSvc?.price || '') + '₽</strong></div></div><div class="btn-group"><button class="btn-back" onclick="rn(\'manual_time\')">← Назад</button><button class="btn-confirm" onclick="manualCf()">Подтвердить</button></div>';
}

async function manualCf() {
    if (state.isSubmitting) return;
    state.isSubmitting = true;
    const payload = { admin_telegram_id: user?.id, client_name: state.manualClientName, phone: state.manualPhone || null, service_id: state.manualSvc?.id, master_id: state.manualMst?.id, date: state.manualDate, time: state.manualTime };
    try {
        const res = await api('/api/admin/manual-booking', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) });
        if (res.ok) {
            tg?.showAlert?.(`Запись создана!\n\nКлиент: ${res.client_name}\n${res.service}\nМастер: ${res.master}\n${res.date} в ${res.time}`);
            rn('menu');
        } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
    } catch (e) { tg?.showAlert?.('Ошибка соединения'); }
    state.isSubmitting = false;
}

function renderMyBookings(app) {
    app.innerHTML = '<h2>Мои записи</h2><div id="bklist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bklist');
    if (!state.bookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.bookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span><span class="status-badge ${b.status==='confirmed'?'status-active':'status-inactive'} ${b.is_manual?'status-manual':''}">${b.is_manual?'📞 Ручная':b.status==='confirmed'?'✅ Активна':'❌ Отменена'}</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="row"><span class="label">Цена:</span><span class="value">${b.price}₽</span></div>`;
        if (b.status === 'confirmed' && !b.is_manual) {
            const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
            btn.onclick = async () => {
                const res = await api('/api/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id }) });
                if (res.ok) { tg?.showAlert?.('Запись отменена'); const p = await api(`/api/profile?telegram_id=${user?.id}`); state.bookings = p?.bookings || []; rn('my_bookings'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            }; card.appendChild(btn);
        }
        c.appendChild(card);
    });
}

function renderReviews(app) {
    app.innerHTML = '<h2>Оставить отзыв</h2><div id="rvlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('rvlist');
    if (!state.pastBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет прошедших записей</p>'; return; }
    state.pastBookings.forEach(b => {
        if (b.is_manual) return;
        const card = document.createElement('div'); card.className = 'card'; card.id = 'rv_' + b.id;
        card.innerHTML = `<div class="row"><span class="label">${b.date} в ${b.time}</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service}</span></div><div class="stars" id="stars_${b.id}">${[1,2,3,4,5].map(n => `<span class="star" data-n="${n}">★</span>`).join('')}</div>`;
        c.appendChild(card);
        const stars = document.querySelectorAll(`#stars_${b.id} .star`);
        stars.forEach(s => {
            s.onmouseenter = () => { const n = parseInt(s.dataset.n); stars.forEach((ss, i) => ss.classList.toggle('active', i < n)); };
            s.onclick = async () => {
                const rating = parseInt(s.dataset.n);
                const res = await api('/api/reviews', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ telegram_id: user?.id, booking_id: b.id, rating }) });
                if (res.ok) { tg?.showAlert?.(res.bonus_added ? `Спасибо! +${res.bonus_amount}₽ бонус!` : 'Спасибо за отзыв!'); const p = await api(`/api/profile?telegram_id=${user?.id}`); if (p?.exists) { state.profile = p; state.pastBookings = p.past_bookings_for_review || []; } rn('reviews'); }
                else { tg?.showAlert?.(res.detail || 'Ошибка'); }
            };
        });
    });
}

function renderMyReviewsHistory(app) {
    app.innerHTML = '<h2>Мои отзывы</h2><div id="myrv"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('myrv');
    if (!state.myReviews || !state.myReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.myReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">Мастер: ${r.master_name}</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}`;
        c.appendChild(card);
    });
}

function renderBonuses(app) {
    app.innerHTML = '<h2>Бонусы</h2><div id="bn"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const c = document.getElementById('bn');
    if (!state.profile) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет данных</p>'; return; }
    c.innerHTML = `<div class="card"><div class="row"><span class="label">Всего визитов:</span><span class="value">${state.profile.total_visits}</span></div><div class="row"><span class="label">Бонусный баланс:</span><span class="value green">${state.profile.bonus_balance}₽</span></div><div class="row"><span class="label">До следующего бонуса:</span><span class="value">${state.profile.visits_to_next_bonus} визитов</span></div></div>`;
}

function renderAdminStats(app) {
    app.innerHTML = '<h2>Статистика</h2><div id="st"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const s = state.stats || {};
    document.getElementById('st').innerHTML = `<div class="card"><div class="row"><span class="label">Записей сегодня:</span><span class="value">${s.today_bookings||0}</span></div><div class="row"><span class="label">Всего клиентов:</span><span class="value">${s.total_clients||0}</span></div><div class="row"><span class="label">Выручка сегодня:</span><span class="value green">${s.today_revenue||0}₽</span></div></div>`;
}

async function renderAdminToday(app) {
    app.innerHTML = '<h2>Записи на сегодня</h2><div class="form-group"><label>Фильтр по мастеру</label><select id="mfilter" onchange="loadTodayFiltered()"><option value="">Все мастера</option>' + state.allMasters.map(m => `<option value="${m.id}" ${state.todayFilterMaster==m.id?'selected':''}>${m.name}</option>`).join('') + '</select></div><div id="tdlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadTodayFiltered();
}

async function loadTodayFiltered() {
    const mid = document.getElementById('mfilter')?.value || '';
    state.todayFilterMaster = mid || null;
    const url = mid ? `/api/admin/today-bookings?admin_telegram_id=${user?.id}&master_id=${mid}` : `/api/admin/today-bookings?admin_telegram_id=${user?.id}`;
    state.todayBookings = await api(url);
    const c = document.getElementById('tdlist'); c.innerHTML = '';
    if (!state.todayBookings.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    state.todayBookings.forEach(b => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${b.time}</span><span class="value">${b.client_name} ${b.is_manual?'📞':''}</span></div><div class="row"><span class="label">Мастер:</span><span class="value">${b.master}</span></div><div class="row"><span class="label">Услуга:</span><span class="value">${b.service} (${b.price}₽)</span></div>`;
        const btn = document.createElement('button'); btn.className = 'btn-cancel'; btn.textContent = '❌ Отменить'; btn.style.marginTop = '8px'; btn.style.width = '100%';
        btn.onclick = async () => {
            const res = await api('/api/admin/cancel', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, booking_id: b.id }) });
            if (res.ok) { tg?.showAlert?.('Запись отменена'); await loadTodayFiltered(); } else { tg?.showAlert?.(res.detail || 'Ошибка'); }
        }; card.appendChild(btn); c.appendChild(card);
    });
}

function renderAdminMasters(app) {
    app.innerHTML = '<h2>Мастера</h2><div id="mlist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showMasterForm()">➕ Добавить мастера</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderMastersList();
}

function renderMastersList() {
    const c = document.getElementById('mlist'); c.innerHTML = '';
    state.allMasters.forEach(m => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${m.name}</span><span class="status-badge ${m.is_active?'status-active':'status-inactive'}">${m.is_active?'Активен':'Неактивен'}${m.is_admin?' | Админ':''}</span></div><div class="row"><span class="label">Рейтинг: ${m.rating} | Опыт: ${m.experience} лет | Лимит: ${m.max_bookings} зап/день</span></div>${m.photo?`<img src="${m.photo}" style="width:60px;height:60px;border-radius:12px;object-fit:cover;margin-top:8px">`:''}<div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap"><button class="btn-admin" onclick="editMaster(${m.id},'${m.name}','${m.photo||''}',${m.experience},${m.telegram_id||0},${m.max_bookings||15},${m.is_admin||false})">✏️</button><button class="btn-admin" onclick="toggleMaster(${m.id})">${m.is_active?'⏸️ Отключить':'▶️ Включить'}</button><button class="btn-dayoff" onclick="showDayOffForm(${m.id},'${m.name}')">🚫 Выходной</button></div>`;
        c.appendChild(card);
    });
}

function showMasterForm(editData = null) {
    const app = document.getElementById('app'); state.selectedPhotoFile = null; state.selectedPhotoPath = editData?.photo || null;
    app.innerHTML = `<h2>${editData?'Изменить мастера':'Добавить мастера'}</h2><div class="form-group"><label>Имя</label><input id="mname" value="${editData?.name||''}"></div><div class="form-group"><label>Фото</label>${state.selectedPhotoPath?`<img src="${state.selectedPhotoPath}" class="preview-img" id="mphoto_preview"><br>`:''}<input type="file" id="mphoto_input" accept="image/*" style="display:none" onchange="onPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById('mphoto_input').click()">📷 Выбрать фото</button><span class="file-selected" id="mphoto_name">${state.selectedPhotoPath?'✅ Фото загружено':''}</span></div><div class="form-group"><label>Опыт (лет)</label><input id="mexp" type="number" value="${editData?.exp||0}"></div><div class="form-group"><label>Telegram ID мастера</label><input id="mtg" type="number" value="${editData?.tg||''}"></div><div class="form-group"><label>Лимит записей в день</label><input id="mmax" type="number" value="${editData?.max||15}"></div><div class="form-group"><label><input type="checkbox" id="misadmin" ${editData?.isAdmin?'checked':''}> Права администратора</label></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveMasterEdit(${editData.id})`:'saveMasterNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_masters')">← Назад</button></div>`;
}

function onPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.selectedPhotoFile = input.files[0];
        document.getElementById('mphoto_name').textContent = '✅ ' + input.files[0].name;
        const preview = document.getElementById('mphoto_preview');
        if (preview) preview.src = URL.createObjectURL(input.files[0]);
    }
}

async function saveMasterNew() {
    const name = document.getElementById('mname').value;
    const exp = parseInt(document.getElementById('mexp').value) || 0;
    const tgid = parseInt(document.getElementById('mtg').value) || null;
    const max = parseInt(document.getElementById('mmax').value) || 15;
    const isAdm = document.getElementById('misadmin')?.checked || false;
    let photoPath = null;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api('/api/admin/masters', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user?.id}`); rn('admin_masters');
}

function editMaster(id, name, photo, exp, tg, max, isAdm) { showMasterForm({ id, name, photo, exp, tg, max, isAdmin: isAdm }); }

async function saveMasterEdit(id) {
    const name = document.getElementById('mname').value;
    const exp = parseInt(document.getElementById('mexp').value) || 0;
    const tgid = parseInt(document.getElementById('mtg').value) || null;
    const max = parseInt(document.getElementById('mmax').value) || 15;
    const isAdm = document.getElementById('misadmin')?.checked || false;
    let photoPath = state.selectedPhotoPath;
    if (state.selectedPhotoFile) { const upRes = await uploadPhoto(state.selectedPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    await api(`/api/admin/masters/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, photo_url: photoPath, experience_years: exp, telegram_id: tgid, max_bookings_per_day: max, is_admin: isAdm }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user?.id}`); rn('admin_masters');
}

async function toggleMaster(id) {
    await api(`/api/admin/masters/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, master_id: id }) });
    state.allMasters = await api(`/api/admin/masters?admin_telegram_id=${user?.id}`); rn('admin_masters');
}

function showDayOffForm(masterId, masterName) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>Выходной мастера</h2><p style="color:#888;margin-bottom:12px">Мастер: <b>${masterName}</b></p><div class="form-group"><label>Дата</label><input id="ddate" type="date"></div><div class="form-group"><label>Причина</label><textarea id="dreason"></textarea></div><button class="btn-confirm" style="width:100%" onclick="saveDayOff(${masterId})">Установить выходной</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_masters')">← Назад</button></div>`;
}

async function saveDayOff(masterId) {
    const date = document.getElementById('ddate').value;
    const reason = document.getElementById('dreason').value;
    if (!date) { tg?.showAlert?.('Выберите дату'); return; }
    const res = await api('/api/admin/master-day-off', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, master_id: masterId, date, reason }) });
    if (res.ok) { tg?.showAlert?.(`Выходной установлен. Отменено записей: ${res.cancelled_bookings}`); rn('admin_masters'); }
    else { tg?.showAlert?.(res.detail || 'Ошибка'); }
}

function renderAdminServices(app) {
    app.innerHTML = '<h2>Услуги</h2><div id="slist"></div><button class="btn-admin" style="width:100%;margin-top:8px" onclick="showServiceForm()">➕ Добавить услугу</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    renderServicesList();
}

function renderServicesList() {
    const c = document.getElementById('slist'); c.innerHTML = '';
    state.allServices.forEach(s => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${s.name}</span><span class="status-badge ${s.is_active?'status-active':'status-inactive'}">${s.is_active?'Активна':'Неактивна'}</span></div><div class="row"><span class="label">Цена: ${s.price}₽ | Длит: ${s.duration} мин | Кат: ${s.category||'—'}</span></div><div style="display:flex;gap:8px;margin-top:8px"><button class="btn-admin" onclick="editService(${s.id},'${s.name}',${s.price},${s.duration},'${s.category||''}')">✏️</button><button class="btn-admin" onclick="toggleService(${s.id})">${s.is_active?'⏸️ Отключить':'▶️ Включить'}</button></div>`;
        c.appendChild(card);
    });
}

function showServiceForm(editData = null) {
    const app = document.getElementById('app');
    app.innerHTML = `<h2>${editData?'Изменить услугу':'Добавить услугу'}</h2><div class="form-group"><label>Название</label><input id="sname" value="${editData?.name||''}"></div><div class="form-group"><label>Цена</label><input id="sprice" type="number" value="${editData?.price||''}"></div><div class="form-group"><label>Длительность (мин)</label><input id="sdur" type="number" value="${editData?.dur||''}"></div><div class="form-group"><label>Категория</label><input id="scat" value="${editData?.cat||''}"></div><button class="btn-confirm" style="width:100%" onclick="${editData?`saveServiceEdit(${editData.id})`:'saveServiceNew()'}">Сохранить</button><div class="btn-group"><button class="btn-back" onclick="rn('admin_services')">← Назад</button></div>`;
}

async function saveServiceNew() {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api('/api/admin/services', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

function editService(id, name, price, dur, cat) { showServiceForm({ id, name, price, dur, cat }); }

async function saveServiceEdit(id) {
    const name = document.getElementById('sname').value;
    const price = parseInt(document.getElementById('sprice').value) || 0;
    const dur = parseInt(document.getElementById('sdur').value) || 0;
    const cat = document.getElementById('scat').value;
    await api(`/api/admin/services/${id}`, { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, name, price, duration_minutes: dur, category: cat }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

async function toggleService(id) {
    await api(`/api/admin/services/${id}/toggle`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, service_id: id }) });
    state.allServices = await api(`/api/admin/services?admin_telegram_id=${user?.id}`); rn('admin_services');
}

function renderAdminBroadcast(app) {
    state.broadcastPhotoFile = null;
    app.innerHTML = '<h2>Рассылка</h2><div class="form-group"><label>Текст</label><textarea id="btext"></textarea></div><div class="form-group"><label>Фото</label><input type="file" id="bphoto_input" accept="image/*" style="display:none" onchange="onBroadcastPhotoSelected(this)"><button class="btn-photo" onclick="document.getElementById(\'bphoto_input\').click()">📷 Прикрепить фото</button><span class="file-selected" id="bphoto_name"></span></div><button class="btn-send" style="width:100%" onclick="sendBroadcast()">📢 Отправить всем</button><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
}

function onBroadcastPhotoSelected(input) {
    if (input.files && input.files[0]) {
        state.broadcastPhotoFile = input.files[0];
        document.getElementById('bphoto_name').textContent = '✅ ' + input.files[0].name;
    }
}

async function sendBroadcast() {
    const text = document.getElementById('btext').value;
    if (!text && !state.broadcastPhotoFile) { tg?.showAlert?.('Введите текст или прикрепите фото'); return; }
    let photoPath = null;
    if (state.broadcastPhotoFile) { const upRes = await uploadPhoto(state.broadcastPhotoFile); if (upRes.ok) photoPath = upRes.path; }
    const res = await api('/api/admin/broadcast', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, text: text || '', photo_path: photoPath }) });
    if (res.ok) { tg?.showAlert?.(`Отправлено: ${res.sent}, ошибок: ${res.failed}`); rn('menu'); }
    else { tg?.showAlert?.('Ошибка'); }
}

async function renderAdminAudit(app) {
    app.innerHTML = '<h2>Аудит</h2><div id="alist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const logs = await api(`/api/admin/audit-log?admin_telegram_id=${user?.id}`);
    const c = document.getElementById('alist');
    if (!logs || !logs.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет записей</p>'; return; }
    logs.forEach(l => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${l.created_at?new Date(l.created_at).toLocaleString('ru-RU'):'—'}</span></div><div class="row"><span class="label">Админ ID: ${l.admin_id}</span><span class="value">${l.action}</span></div>${l.details?`<div class="row"><span class="label">Детали:</span><span class="value">${l.details}</span></div>`:''}`;
        c.appendChild(card);
    });
}

async function renderAdminReviews(app) {
    app.innerHTML = '<h2>Отзывы клиентов</h2><div class="form-group"><label>Фильтр по мастеру</label><select id="rfilter" onchange="loadAdminReviews()"><option value="">Все мастера</option>' + state.allMasters.map(m => `<option value="${m.id}">${m.name}</option>`).join('') + '</select></div><div id="arlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    await loadAdminReviews();
}

async function loadAdminReviews() {
    const mid = document.getElementById('rfilter')?.value || '';
    const url = mid ? `/api/admin/reviews?admin_telegram_id=${user?.id}&master_id=${mid}` : `/api/admin/reviews?admin_telegram_id=${user?.id}`;
    state.allReviews = await api(url);
    const c = document.getElementById('arlist'); c.innerHTML = '';
    if (!state.allReviews || !state.allReviews.length) { c.innerHTML = '<p style="color:#888;text-align:center;padding:20px">Нет отзывов</p>'; return; }
    state.allReviews.forEach(r => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="label">${r.client_name} (@${r.client_username||'—'})</span><span class="value">${'★'.repeat(r.rating)}${'☆'.repeat(5-r.rating)}</span></div><div class="row"><span class="label">Мастер: ${r.master_name}</span></div>${r.comment?`<div class="row"><span class="label">Комментарий:</span><span class="value">${r.comment}</span></div>`:''}<div class="row"><span class="label">${r.created_at?new Date(r.created_at).toLocaleString('ru-RU'):'—'}</span></div>`;
        c.appendChild(card);
    });
}

async function renderAdminWeekend(app) {
    app.innerHTML = '<h2>Выходные дни</h2><div id="wlist"></div><div class="btn-group"><button class="btn-back" onclick="rn(\'menu\')">← Назад</button></div>';
    const days = ['Вс','Пн','Вт','Ср','Чт','Пт','Сб'];
    const current = state.weekendDays || [];
    const c = document.getElementById('wlist');
    days.forEach((name, idx) => {
        const card = document.createElement('div'); card.className = 'card';
        card.innerHTML = `<div class="row"><span class="value">${name}</span><label><input type="checkbox" class="wcheck" data-day="${idx}" ${current.includes(idx)?'checked':''}> Выходной</label></div>`;
        c.appendChild(card);
    });
    const btn = document.createElement('button'); btn.className = 'btn-confirm'; btn.textContent = '💾 Сохранить'; btn.style.marginTop = '16px'; btn.style.width = '100%';
    btn.onclick = async () => {
        const selected = [];
        document.querySelectorAll('.wcheck:checked').forEach(cb => selected.push(parseInt(cb.dataset.day)));
        const res = await api('/api/admin/weekend-days', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ admin_telegram_id: user?.id, days: selected }) });
        if (res.ok) { state.weekendDays = selected; tg?.showAlert?.('Выходные дни сохранены'); rn('menu'); }
        else { tg?.showAlert?.('Ошибка'); }
    };
    c.appendChild(btn);
}

ld();
EOF

echo ""
echo "=============================================="
echo "  V9 ГОТОВА! 33 пункта."
echo "  Запусти: bash setup.sh"
echo "=============================================="