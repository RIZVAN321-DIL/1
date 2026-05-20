from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder
from sqlalchemy import select
from app.database import async_session
from app.models.booking import Booking

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
    await callback.message.edit_text(
        "<b>👤 Профиль</b>\n\nВыберите действие:",
        reply_markup=builder.as_markup()
    )
    await callback.answer()

@router.callback_query(F.data == "my_bookings")
async def my_bookings(callback: CallbackQuery):
    user_id = callback.from_user.id
    async with async_session() as session:
        from app.models.client import Client
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
    await callback.message.answer("⭐ Отзывы будут доступны после завершения визита")
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
    await callback.message.answer(
        f"👥 Пригласи друга!\n\nТвоя ссылка:\n{ref_link}\n\nЗа каждого друга — бонус 100₽"
    )
    await callback.answer()
