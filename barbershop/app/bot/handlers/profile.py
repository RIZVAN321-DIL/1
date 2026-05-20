from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder
from sqlalchemy import select
from app.database import async_session
from app.models.booking import Booking
from app.models.client import Client
from app.models.review import Review

router = Router()

@router.callback_query(F.data == "profile")
async def profile_menu(callback: CallbackQuery):
    builder = InlineKeyboardBuilder()
    builder.button(text="📋 Мои записи", callback_data="my_bookings")
    builder.button(text="⭐ Оставить отзыв", callback_data="leave_review")
    builder.button(text="🎁 Бонусы", callback_data="bonuses")
    builder.button(text="👥 Пригласить друга", callback_data="referral")
    builder.button(text="◀️ Назад", callback_data="start_back")
    builder.adjust(2)
    await callback.message.edit_text("<b>👤 Профиль</b>\n\nВыберите действие:", reply_markup=builder.as_markup())
    await callback.answer()

@router.callback_query(F.data == "my_bookings")
async def my_bookings(callback: CallbackQuery):
    user_id = callback.from_user.id
    async with async_session() as session:
        client = await session.scalar(select(Client).where(Client.telegram_id == user_id))
        if not client:
            await callback.message.answer("У вас пока нет записей.")
            await callback.answer()
            return
        result = await session.execute(
            select(Booking).where(Booking.client_id == client.id).order_by(Booking.date.desc(), Booking.time.desc()).limit(10)
        )
        bookings = result.scalars().all()
    if not bookings:
        await callback.message.answer("📋 У вас пока нет записей.")
    else:
        msg = "<b>📋 Мои записи</b>\n\n"
        for b in bookings:
            emoji = "✅" if b.status == "confirmed" else "❌"
            msg += f"{emoji} {b.date} в {b.time} (запись #{b.id})\n"
        await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "leave_review")
async def leave_review(callback: CallbackQuery):
    user_id = callback.from_user.id
    async with async_session() as session:
        client = await session.scalar(select(Client).where(Client.telegram_id == user_id))
        if not client:
            await callback.message.answer("Сначала сделайте запись.")
            await callback.answer()
            return
        result = await session.execute(
            select(Booking).where(Booking.client_id == client.id, Booking.status == "confirmed").order_by(Booking.date.desc()).limit(5)
        )
        bookings = result.scalars().all()
    if not bookings:
        await callback.message.answer("У вас нет завершённых записей для отзыва.")
        await callback.answer()
        return
    builder = InlineKeyboardBuilder()
    for b in bookings:
        builder.button(text=f"📅 {b.date} {b.time}", callback_data=f"review_{b.id}")
    builder.button(text="◀️ Назад", callback_data="profile")
    builder.adjust(1)
    await callback.message.edit_text("<b>⭐ Выберите запись для отзыва:</b>", reply_markup=builder.as_markup())
    await callback.answer()

@router.callback_query(F.data.startswith("review_"))
async def review_booking(callback: CallbackQuery):
    booking_id = int(callback.data.split("_")[1])
    async with async_session() as session:
        booking = await session.get(Booking, booking_id)
        if not booking:
            await callback.message.answer("Запись не найдена.")
            await callback.answer()
            return
        existing = await session.scalar(select(Review).where(Review.booking_id == booking_id))
        if existing:
            await callback.message.answer("Вы уже оставили отзыв на эту запись.")
            await callback.answer()
            return
    builder = InlineKeyboardBuilder()
    for star in range(1, 6):
        builder.button(text="⭐" * star, callback_data=f"rate_{booking_id}_{star}")
    builder.button(text="◀️ Назад", callback_data="leave_review")
    builder.adjust(1)
    await callback.message.edit_text(f"<b>⭐ Оцените визит:</b>\n📅 {booking.date} в {booking.time}", reply_markup=builder.as_markup())
    await callback.answer()

@router.callback_query(F.data.startswith("rate_"))
async def rate_booking(callback: CallbackQuery):
    _, booking_id, rating = callback.data.split("_")
    booking_id, rating = int(booking_id), int(rating)
    async with async_session() as session:
        booking = await session.get(Booking, booking_id)
        review = Review(client_id=booking.client_id, master_id=booking.master_id, booking_id=booking_id, rating=rating, comment=None, is_approved=True)
        session.add(review)
        await session.commit()
    await callback.message.edit_text(f"<b>⭐ Спасибо за оценку!</b>\n\nВы поставили {'⭐' * rating} за визит {booking.date}.")
    await callback.answer()

@router.callback_query(F.data == "bonuses")
async def bonuses(callback: CallbackQuery):
    await callback.message.answer("🎁 Бонусная система будет запущена в следующем обновлении")
    await callback.answer()

@router.callback_query(F.data == "referral")
async def referral(callback: CallbackQuery):
    bot = callback.message.bot
    bot_info = await bot.get_me()
    ref_link = f"https://t.me/{bot_info.username}"
    await callback.message.answer(f"👥 Пригласи друга!\n\nТвоя ссылка:\n{ref_link}\n\nЗа каждого друга — бонус 100₽")
    await callback.answer()
