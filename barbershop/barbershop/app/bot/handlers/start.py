from aiogram import Router
from aiogram.filters import CommandStart
from aiogram.types import Message, WebAppInfo
from aiogram.utils.keyboard import InlineKeyboardBuilder
from app.config import settings

router = Router()

@router.message(CommandStart())
async def cmd_start(message: Message):
    builder = InlineKeyboardBuilder()
    builder.button(text="✂️ Записаться", web_app=WebAppInfo(url=f"{settings.BASE_URL}/mini-app?mode=booking"))
    builder.button(text="👤 Профиль", web_app=WebAppInfo(url=f"{settings.BASE_URL}/mini-app?mode=profile"))
    builder.adjust(2)
    await message.answer("<b>BARBERSHOP</b>\n\nДобро пожаловать!\nул. Чернышевского, 52Б\nЕжедневно 10:00 – 21:00\n\n<i>Выберите действие:</i>", reply_markup=builder.as_markup())
