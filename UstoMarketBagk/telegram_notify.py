"""
Отправка уведомлений в Telegram через Bot API.
Красивое оформление (HTML), кнопки для смены статуса заказа.
Токен и chat_id задаются в .env (TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID).
"""

import json
import urllib.request
from typing import Optional

try:
    from config import TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
except ImportError:
    TELEGRAM_BOT_TOKEN = ""
    TELEGRAM_CHAT_ID = ""

TELEGRAM_API_BASE = "https://api.telegram.org/bot{token}"
REQUEST_TIMEOUT = 15


def _api_post(method: str, payload: dict) -> bool:
    """POST к Telegram Bot API. payload без chat_id если не нужен."""
    if not TELEGRAM_BOT_TOKEN:
        return False
    url = f"{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/{method}"
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as r:
            return r.status == 200
    except Exception as e:
        print(f"[Telegram] {method}: {e}")
        return False


def _send_to_chat(chat_id: str, text: str, reply_markup: Optional[dict] = None) -> bool:
    """Отправляет сообщение в chat_id. text может быть HTML при parse_mode=HTML."""
    if not TELEGRAM_BOT_TOKEN or not chat_id:
        return False
    payload = {
        "chat_id": chat_id,
        "text": text,
        "disable_web_page_preview": True,
        "parse_mode": "HTML",
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    return _api_post("sendMessage", payload)


def send_telegram(text: str) -> bool:
    """Отправляет сообщение в чат из TELEGRAM_CHAT_ID."""
    if not TELEGRAM_CHAT_ID:
        return False
    return _send_to_chat(TELEGRAM_CHAT_ID, text)


def send_telegram_to_chat(chat_id: str, text: str) -> bool:
    """Отправляет сообщение в произвольный chat_id."""
    return _send_to_chat(chat_id, text)


def notify_otp(phone: str, code: str) -> None:
    """Уведомление: код для входа."""
    send_telegram(
        f"<b>🔐 Код для входа</b>\n"
        f"Номер: <code>{_esc(phone)}</code>\n"
        f"Код: <b>{_esc(code)}</b>"
    )


def notify_master_authorized(name: str, phone: str) -> None:
    """Уведомление: мастер авторизовался."""
    send_telegram(
        f"<b>✅ Мастер авторизовался</b>\n"
        f"Имя: {_esc(name)}\n"
        f"Телефон: <code>{_esc(phone)}</code>"
    )


def _esc(s: str) -> str:
    """Экранирование для HTML в Telegram."""
    if not s:
        return ""
    return str(s).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def _order_inline_keyboard(order_id: int) -> dict:
    """Кнопки смены статуса заказа (callback_data до 64 байт)."""
    return {
        "inline_keyboard": [
            [
                {"text": "⚙️ В работе", "callback_data": f"order:{order_id}:processing"},
                {"text": "✅ Выполнен", "callback_data": f"order:{order_id}:completed"},
                {"text": "❌ Отменён", "callback_data": f"order:{order_id}:canceled"},
            ],
        ]
    }


def notify_new_order(
    order_id: int,
    client_name: str,
    client_phone: str,
    total_price: float,
    items_count: int,
    payment_type: Optional[str] = None,
    client_address: Optional[str] = None,
    comment: Optional[str] = None,
) -> None:
    """Уведомление о новом заказе: красивое сообщение + кнопки смены статуса."""
    pay = (payment_type or "cash").strip().lower()
    pay_label = "💳 Карта" if pay == "card" else "💵 Наличные"
    body = (
        f"<b>🛒 Новый заказ #{order_id}</b>\n\n"
        f"👤 <b>Клиент:</b> {_esc(client_name)}\n"
        f"📞 <b>Телефон:</b> <code>{_esc(client_phone)}</code>\n"
        f"💰 <b>Сумма:</b> {total_price:.0f} с.\n"
        f"📦 <b>Позиций:</b> {items_count}\n"
        f"💳 <b>Оплата:</b> {pay_label}"
    )
    if client_address and client_address.strip():
        body += f"\n📍 <b>Адрес:</b> {_esc(client_address.strip())}"
    if comment and comment.strip():
        body += f"\n💬 <b>Комментарий:</b> {_esc(comment.strip())}"
    body += "\n\n<i>Изменить статус:</i>"
    reply_markup = _order_inline_keyboard(order_id)
    _send_to_chat(TELEGRAM_CHAT_ID, body, reply_markup=reply_markup)


def answer_callback_query(callback_query_id: str, text: str = "Готово") -> bool:
    """Ответ на нажатие кнопки (убирает «часики» у пользователя)."""
    return _api_post("answerCallbackQuery", {"callback_query_id": callback_query_id, "text": text})


def edit_message_reply_markup(chat_id: str, message_id: int, reply_markup: Optional[dict] = None) -> bool:
    """Убирает кнопки под сообщением (или ставит новые)."""
    payload = {"chat_id": chat_id, "message_id": message_id}
    if reply_markup is not None:
        payload["reply_markup"] = reply_markup
    return _api_post("editMessageReplyMarkup", payload)


def edit_message_text(chat_id: str, message_id: int, text: str) -> bool:
    """Редактирует текст сообщения."""
    return _api_post("editMessageText", {
        "chat_id": chat_id,
        "message_id": message_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    })
