from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from app.database import engine, Base
from app.api.routes.booking import router as booking_router
from app.api.routes.services import router as services_router
from app.api.routes.masters import router as masters_router
from app.api.routes.booked_slots import router as booked_slots_router
from app.api.routes.admin_masters import router as admin_masters_router
from app.api.routes.admin_services import router as admin_services_router
from app.api.routes.admin_bookings import router as admin_bookings_router
from app.seed import seed_database
from app.logger import logger
import app.models

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("API start")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    await seed_database()
    logger.info("API ready")
    yield
    logger.info("API stop")

app = FastAPI(title="Barbershop API", version="3.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(booking_router)
app.include_router(services_router)
app.include_router(masters_router)
app.include_router(booked_slots_router)
app.include_router(admin_masters_router)
app.include_router(admin_services_router)
app.include_router(admin_bookings_router)
app.mount("/static", StaticFiles(directory="app/static"), name="static")

@app.get("/health")
async def health():
    return {"status": "ok"}

@app.get("/mini-app")
async def mini_app():
    return FileResponse("app/static/index.html")
