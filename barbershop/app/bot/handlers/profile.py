from aiogram import Router, F
from aiogram.types import Message, CallbackQuery
from aiogram.utils.keyboard import InlineKeyboardBuilder

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
    await callback.message.answer("📋 История записей будет доступна в следующем обновлении")
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
        f"👥 Пригласи друга!\n\n"
        f"Твоя реферальная ссылка:\n{ref_link}\n\n"
        f"За каждого друга — бонус 100₽"
    )
    await callback.answer()
