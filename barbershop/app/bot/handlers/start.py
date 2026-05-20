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
    builder.button(text="👤 Профиль", callback_data="profile")
    if message.from_user.id in settings.ADMIN_IDS:
        builder.button(text="🔧 Админ", callback_data="admin")
    builder.adjust(2)
    await message.answer(
        "<b>💈 BARBERSHOP</b>\n\nДобро пожаловать!\nул. Чернышевского, 52Б\nЕжедневно 10:00 - 21:00",
        reply_markup=builder.as_markup()
    )
