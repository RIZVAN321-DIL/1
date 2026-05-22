from datetime import date as dt_date
from sqlalchemy import select, update, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.booking import Booking
from app.models.service import Service


class BookingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_slot_booking(self, master_id: int, date: str, time: str) -> Booking | None:
        result = await self.session.execute(
            select(Booking).where(
                Booking.master_id == master_id,
                Booking.date == date,
                Booking.time == time,
                Booking.status == "confirmed",
            )
        )
        return result.scalar_one_or_none()

    async def get_active_count(self, client_id: int) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(Booking).where(
                Booking.client_id == client_id,
                Booking.status == "confirmed",
                Booking.date >= dt_date.today().isoformat(),
            )
        )
        return result.scalar() or 0

    async def get_by_id(self, booking_id: int) -> Booking | None:
        result = await self.session.execute(
            select(Booking)
            .options(
                selectinload(Booking.client),
                selectinload(Booking.master),
                selectinload(Booking.service),
            )
            .where(Booking.id == booking_id)
        )
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
        result = await self.session.execute(
            select(Booking)
            .options(
                selectinload(Booking.client),
                selectinload(Booking.master),
                selectinload(Booking.service),
            )
            .where(Booking.client_id == client_id)
            .order_by(Booking.date.desc(), Booking.time.desc())
        )
        return list(result.scalars().all())

    async def get_today_bookings(self) -> list[Booking]:
        today = dt_date.today().isoformat()
        result = await self.session.execute(
            select(Booking)
            .options(
                selectinload(Booking.client),
                selectinload(Booking.master),
                selectinload(Booking.service),
            )
            .where(Booking.date == today, Booking.status == "confirmed")
            .order_by(Booking.time)
        )
        return list(result.scalars().all())

    async def get_today_revenue(self) -> int:
        today = dt_date.today().isoformat()
        result = await self.session.execute(
            select(func.sum(Service.price))
            .join(Booking, Booking.service_id == Service.id)
            .where(Booking.date == today, Booking.status == "confirmed")
        )
        return result.scalar() or 0

    async def get_past_confirmed(self, client_id: int) -> list[Booking]:
        today = dt_date.today().isoformat()
        result = await self.session.execute(
            select(Booking)
            .options(
                selectinload(Booking.client),
                selectinload(Booking.master),
                selectinload(Booking.service),
            )
            .where(
                Booking.client_id == client_id,
                Booking.date < today,
                Booking.status == "confirmed",
            )
            .order_by(Booking.date.desc())
        )
        return list(result.scalars().all())

    async def get_upcoming_confirmed(self) -> list[Booking]:
        today = dt_date.today().isoformat()
        result = await self.session.execute(
            select(Booking)
            .options(
                selectinload(Booking.client),
                selectinload(Booking.master),
                selectinload(Booking.service),
            )
            .where(Booking.date >= today, Booking.status == "confirmed")
            .order_by(Booking.date, Booking.time)
        )
        return list(result.scalars().all())

    async def mark_reminder_sent(self, booking_id: int):
        await self.session.execute(
            update(Booking)
            .where(Booking.id == booking_id)
            .values(reminder_sent=True)
        )
        await self.session.flush()
