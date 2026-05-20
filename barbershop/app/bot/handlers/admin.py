from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder
from app.config import settings

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
    await callback.message.answer("📊 Статистика будет доступна в следующем обновлении")
    await callback.answer()

@router.callback_query(F.data == "admin_bookings")
async def admin_bookings(callback: CallbackQuery):
    await callback.message.answer("📅 Управление записями будет доступно в следующем обновлении")
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
    await callback.message.answer(
        "📢 Для рассылки напишите сообщение и перешлите его сюда.\n"
        "Функция будет доработана в следующем обновлении."
    )
    await callback.answer()
