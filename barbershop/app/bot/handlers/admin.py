from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder
from sqlalchemy import select, func
from datetime import date
from app.config import settings
from app.database import async_session
from app.models.booking import Booking
from app.models.client import Client
from app.models.master import Master
from app.models.service import Service
from app.models.review import Review

router = Router()

# Храним состояние рассылки
broadcast_state = {}

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
    await callback.message.edit_text("<b>🔧 Админ-панель</b>\n\nВыберите действие:", reply_markup=builder.as_markup())
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
        bookings_today = await session.scalar(select(func.count()).where(Booking.date == today, Booking.status == "confirmed"))
        total_clients = await session.scalar(select(func.count()).select_from(Client))
        total_bookings = await session.scalar(select(func.count()).select_from(Booking))
        masters_busy = await session.execute(select(Booking.master_id, func.count()).where(Booking.date == today).group_by(Booking.master_id))
        busy = masters_busy.all()
        masters = (await session.execute(select(Master))).scalars().all()
    msg = f"📊 <b>Статистика</b>\n\n📅 Записей сегодня: <b>{bookings_today}</b>\n📋 Всего записей: <b>{total_bookings}</b>\n👥 Всего клиентов: <b>{total_clients}</b>\n"
    if busy:
        msg += "\n<b>Записи по мастерам:</b>\n"
        for master_id, count in busy:
            master_name = next((m.name for m in masters if m.id == master_id), f"Мастер #{master_id}")
            msg += f"• {master_name}: {count} зап.\n"
    await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_bookings")
async def admin_bookings(callback: CallbackQuery):
    today = date.today().isoformat()
    async with async_session() as session:
        result = await session.execute(select(Booking).where(Booking.date == today, Booking.status == "confirmed").order_by(Booking.time))
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
    async with async_session() as session:
        masters = (await session.execute(select(Master).order_by(Master.rating.desc()))).scalars().all()
    if not masters:
        await callback.message.answer("👥 Нет мастеров.")
    else:
        msg = "<b>👥 Мастера</b>\n\n"
        for m in masters:
            status = "✅ Активен" if m.is_active else "❌ Неактивен"
            msg += f"• <b>{m.name}</b> — ⭐{m.rating} | Опыт: {m.experience_years} лет | {status}\n"
        await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_services")
async def admin_services(callback: CallbackQuery):
    async with async_session() as session:
        services = (await session.execute(select(Service).order_by(Service.category, Service.price))).scalars().all()
    if not services:
        await callback.message.answer("💇 Нет услуг.")
    else:
        msg = "<b>💇 Услуги</b>\n\n"
        current_cat = None
        for s in services:
            if s.category != current_cat:
                current_cat = s.category
                msg += f"\n<b>{current_cat.upper() if current_cat else 'БЕЗ КАТЕГОРИИ'}</b>\n"
            status = "✅" if s.is_active else "❌"
            msg += f"{status} {s.name} — {s.price}₽ ({s.duration_minutes} мин)\n"
        await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_reviews")
async def admin_reviews(callback: CallbackQuery):
    async with async_session() as session:
        reviews = (await session.execute(select(Review).order_by(Review.created_at.desc()).limit(20))).scalars().all()
    if not reviews:
        await callback.message.answer("⭐ Отзывов пока нет.")
    else:
        msg = "<b>⭐ Последние отзывы</b>\n\n"
        for r in reviews:
            stars = "⭐" * r.rating
            msg += f"{stars} — запись #{r.booking_id}\n"
            if r.comment:
                msg += f"💬 {r.comment[:100]}\n"
            msg += "\n"
        await callback.message.answer(msg)
    await callback.answer()

@router.callback_query(F.data == "admin_broadcast")
async def admin_broadcast(callback: CallbackQuery):
    if callback.from_user.id not in settings.ADMIN_IDS:
        await callback.answer("Нет доступа", show_alert=True)
        return
    broadcast_state[callback.from_user.id] = "waiting"
    builder = InlineKeyboardBuilder()
    builder.button(text="❌ Отмена", callback_data="broadcast_cancel")
    await callback.message.edit_text(
        "📢 <b>Рассылка</b>\n\nОтправьте сообщение (текст, фото или видео), которое будет разослано всем клиентам.\n\nДля отмены нажмите кнопку ниже.",
        reply_markup=builder.as_markup()
    )
    await callback.answer()

@router.callback_query(F.data == "broadcast_cancel")
async def broadcast_cancel(callback: CallbackQuery):
    broadcast_state.pop(callback.from_user.id, None)
    await admin_menu(callback)
    await callback.answer("Рассылка отменена")

@router.message(F.content_type.in_({"text", "photo", "video"}))
async def handle_broadcast(message: Message):
    if message.from_user.id not in settings.ADMIN_IDS:
        return
    if broadcast_state.get(message.from_user.id) != "waiting":
        return
    broadcast_state[message.from_user.id] = "sending"
    await message.answer("📢 Начинаю рассылку...")
    async with async_session() as session:
        clients = (await session.execute(select(Client))).scalars().all()
    sent, failed = 0, 0
    for client in clients:
        if client.chat_id:
            try:
                await message.copy_to(client.chat_id)
                sent += 1
            except Exception:
                failed += 1
    broadcast_state.pop(message.from_user.id, None)
    await message.answer(f"📢 <b>Рассылка завершена!</b>\n\n✅ Отправлено: {sent}\n❌ Не доставлено: {failed}")
