from aiogram import Router
from aiogram.filters import CommandStart, CommandObject
from aiogram.types import Message, WebAppInfo
from aiogram.utils.keyboard import InlineKeyboardBuilder
from app.config import settings

router = Router()

@router.message(CommandStart())
async def cmd_start(message: Message, command: CommandObject = None):
    builder = InlineKeyboardBuilder()
    builder.button(text="✂️ Записаться", web_app=WebAppInfo(url=f"{settings.BASE_URL}/mini-app"))
    builder.button(text="🔗 Поделиться ботом", switch_inline_query=f"Запишись в BARBERSHOP через бота!\nhttps://t.me/{settings.BOT_USERNAME}")
    builder.adjust(1)
    await message.answer("<b>BARBERSHOP</b>\n\nДобро пожаловать!\nул. Чернышевского, 52Б\nЕжедневно 10:00 – 21:00\n\n<i>Нажмите кнопку ниже, чтобы записаться:</i>", reply_markup=builder.as_markup())
