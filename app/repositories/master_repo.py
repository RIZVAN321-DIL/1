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
