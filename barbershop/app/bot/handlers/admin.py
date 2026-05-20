from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder
from sqlalchemy import select, func
from datetime import date
from app.config import settings
from app.database import async_session
from app.models.booking import Booking
from app.models.client import Client

router = Router()

@router.callback_query(F.data == "admin")
async def admin_menu(callback: CallbackQuery):
    if callback.from_user.id not in settings.ADMIN_IDS:
        await callback.answer("Нет доступа", show_alert=True)
        return
    builder = InlineKeyboardBuilder()
    builder.button(text="📊 Статистика", callback_data="admin_stats")
    builder.button(text="📅 Записи", callback_data="admin_bookings")
    builder.button(text="👥 Мастера", callback_data="admin_masters")
    builder.button(text="💇 Услуги", callback_data="admin_services")
    builder.button(text="⭐ Отзывы", callback_data="admin_reviews")
    builder.button(text="📢 Рассылка", callback_data="admin_broadcast")
    builder.button(text="🔗 Поделиться", callback_data="admin_share")
    builder.button(text="◀️ Назад", callback_data="start_back")
    builder.adjust(2)
    await callback.message.edit_text(
        "<b>🔧 Админ-панель</b>\n\nВыберите действие:",
        reply_markup=builder.as_markup()
    )
    await callback.answer()

@router.callback_query(F.data == "start_back")
async def back_to_start(callback: CallbackQuery):
    from app.bot.handlers.start import cmd_start
    await cmd_start(callback.message)
    await callback.answer()

@router.callback_query(F.data == "admin_share")
async def admin_share(callback: CallbackQuery):
    bot = callback.message.bot
    bot_info = await bot.get_me()
    ref_link = f"https://t.me/{bot_info.username}"
    await callback.message.answer(f"🔗 Ссылка на бота:\n{ref_link}")
    await callback.answer()

@router.callback_query(F.data == "admin_stats")
async def admin_stats(callback: CallbackQuery):
    today = date.today().isoformat()
    async with async_session() as session:
        bookings_today = await session.scalar(
            select(func.count()).where(Booking.date == today, Booking.status == "confirmed")
        )
        total_clients = await session.scalar(select(func.count()).select_from(Client))
        masters_busy = await session.execute(
            select(Booking.master_id, func.count()).where(Booking.date == today).group_by(Booking.master_id)
        )
        busy = masters_busy.all()
    msg = f"📊 <b>Статистика</b>\n\n📅 Записей сегодня: <b>{bookings_today}</b>\n👥 Всего клиентов: <b>{total_clients}</b>\n"
    if busy:
        msg += "\n<b>Записи по мастерам:</b>\n"
        for master_id, count in busy:
            msg += f"• Мастер #{master_id}: {count} зап.\n"
    await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_bookings")
async def admin_bookings(callback: CallbackQuery):
    today = date.today().isoformat()
    async with async_session() as session:
        result = await session.execute(
            select(Booking).where(Booking.date == today, Booking.status == "confirmed").order_by(Booking.time)
        )
        bookings = result.scalars().all()
    if not bookings:
        await callback.message.answer("📅 На сегодня записей нет.")
    else:
        msg = f"📅 <b>Записи на {today}</b>\n\n"
        for b in bookings:
            msg += f"🕐 {b.time} — запись #{b.id}\n"
        await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_masters")
async def admin_masters(callback: CallbackQuery):
    await callback.message.answer("👥 Управление мастерами будет доступно в следующем обновлении")
    await callback.answer()

@router.callback_query(F.data == "admin_services")
async def admin_services(callback: CallbackQuery):
    await callback.message.answer("💇 Управление услугами будет доступно в следующем обновлении")
    await callback.answer()

@router.callback_query(F.data == "admin_reviews")
async def admin_reviews(callback: CallbackQuery):
    await callback.message.answer("⭐ Модерация отзывов будет доступна в следующем обновлении")
    await callback.answer()

@router.callback_query(F.data == "admin_broadcast")
async def admin_broadcast(callback: CallbackQuery):
    await callback.message.answer("📢 Напишите сообщение для рассылки и перешлите его сюда.")
    await callback.answer()
