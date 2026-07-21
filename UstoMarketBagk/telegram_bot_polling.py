"""
Простой Telegram-бот на long polling.

Назначение:
- Реагирует на команду /start
- Отправляет текст о магазине и кнопки с ссылками:
  Telegram, WhatsApp, Instagram, TikTok, APK, PWA

Источником ссылок является таблица SiteSettingsDB (id=1).

Запуск (на сервере, в каталоге проекта):
    cd ~/backendGreen
    python telegram_bot_polling.py

Для работы нужен TELEGRAM_BOT_TOKEN в .env / config.py.
"""

import json
import os
import time
import urllib.request
import urllib.parse
import uuid
from urllib.error import HTTPError
from typing import List, Dict, Any

from database import SessionLocal, SiteSettingsDB

try:
    from config import TELEGRAM_BOT_TOKEN
except ImportError:
    TELEGRAM_BOT_TOKEN = ""

TELEGRAM_API_BASE = "https://api.telegram.org/bot{token}"
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")


def _api_post(method: str, payload: Dict[str, Any]) -> bool:
    if not TELEGRAM_BOT_TOKEN:
        print("[bot] TELEGRAM_BOT_TOKEN не задан")
        return False
    url = f"{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/{method}"
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return r.status == 200
    except HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="ignore")
        except Exception:
            body = ""
        print(f"[bot] {method} HTTPError: {e.code} {e.reason}. body={body[:500]}")
        return False
    except Exception as e:
        print(f"[bot] {method} error: {e}")
        return False


def _api_get(method: str, params: Dict[str, Any]) -> Dict[str, Any]:
    if not TELEGRAM_BOT_TOKEN:
        return {}
    qs = urllib.parse.urlencode(params)
    url = f"{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/{method}?{qs}"
    try:
        with urllib.request.urlopen(url, timeout=35) as r:
            data = r.read().decode("utf-8")
            return json.loads(data)
    except Exception as e:
        print(f"[bot] {method} error: {e}")
        return {}


def _api_post_multipart(method: str, fields: Dict[str, Any], file_field: str, file_path: str, content_type: str) -> bool:
    """Отправка multipart/form-data в Telegram (для sendDocument с локальным файлом)."""
    if not TELEGRAM_BOT_TOKEN:
        return False
    url = f"{TELEGRAM_API_BASE.format(token=TELEGRAM_BOT_TOKEN)}/{method}"
    boundary = f"----BotBoundary{uuid.uuid4().hex}"
    body = bytearray()

    for k, v in fields.items():
        body.extend(f"--{boundary}\r\n".encode("utf-8"))
        body.extend(f'Content-Disposition: form-data; name="{k}"\r\n\r\n'.encode("utf-8"))
        body.extend(str(v).encode("utf-8"))
        body.extend(b"\r\n")

    filename = os.path.basename(file_path)
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    body.extend(f"--{boundary}\r\n".encode("utf-8"))
    body.extend(
        (
            f'Content-Disposition: form-data; name="{file_field}"; filename="{filename}"\r\n'
            f"Content-Type: {content_type}\r\n\r\n"
        ).encode("utf-8")
    )
    body.extend(file_bytes)
    body.extend(b"\r\n")
    body.extend(f"--{boundary}--\r\n".encode("utf-8"))

    req = urllib.request.Request(url, data=bytes(body), method="POST")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")
    try:
        # Для крупных APK даём больше времени на отправку
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.status == 200
    except HTTPError as e:
        body = ""
        try:
            body = e.read().decode("utf-8", errors="ignore")
        except Exception:
            body = ""
        print(f"[bot] {method} multipart HTTPError: {e.code} {e.reason}. body={body[:500]}")
        return False
    except Exception as e:
        print(f"[bot] {method} multipart error: {e}")
        return False


def _answer_callback_query(callback_query_id: str, text: str = "") -> None:
    if not callback_query_id:
        return
    _api_post("answerCallbackQuery", {"callback_query_id": callback_query_id, "text": text})


def _get_settings_row():
    db = SessionLocal()
    try:
        row = db.query(SiteSettingsDB).filter(SiteSettingsDB.id == 1).first()
        if not row:
            row = SiteSettingsDB(id=1)
            db.add(row)
            db.commit()
            db.refresh(row)
        return row
    finally:
        db.close()


def _apk_url_to_download_page(apk_url: str) -> str:
    """
    Превращает прямую ссылку на .apk в ссылку на красивую страницу скачивания.
    Страница: /web/download.html?apk=<оригинальная_apk_url>
    """
    try:
        parsed = urllib.parse.urlparse(apk_url)
        base = f"{parsed.scheme}://{parsed.netloc}"
        qs = urllib.parse.urlencode({"apk": apk_url})
        return f"{base}/web/download.html?{qs}"
    except Exception:
        return apk_url


def _build_keyboard() -> Dict[str, Any]:
    """Формирует inline-кнопки на основе SiteSettingsDB(id=1)."""
    row = _get_settings_row()
    buttons: List[List[Dict[str, str]]] = []
    if row.telegram_channel_url:
        buttons.append([{"text": "📢 Канал Telegram", "url": row.telegram_channel_url}])
    if row.whatsapp_group_url:
        buttons.append([{"text": "💬 WhatsApp", "url": row.whatsapp_group_url}])
    if row.instagram_url:
        buttons.append([{"text": "📷 Instagram", "url": row.instagram_url}])
    if row.tiktok_url:
        buttons.append([{"text": "🎵 TikTok", "url": row.tiktok_url}])
    if row.apk_url:
        # Отправляем APK прямо в чат через callback, а не открываем ссылку
        buttons.append([{"text": "📲 Скачать приложение", "callback_data": "send_apk"}])
    if getattr(row, "shop_url", None):
        if row.shop_url:
            buttons.append([{"text": "🛒 Открыть магазин", "url": row.shop_url}])
    return {"inline_keyboard": buttons} if buttons else {}


def _send_apk_to_chat(chat_id: int) -> bool:
    row = _get_settings_row()
    caption = "📥 Боргирии барнома\nБарномаи Ustobozor барои шумо"

    # 1) Предпочтительно: Telegram сам скачает файл по публичной ссылке (быстрее и надёжнее)
    if row.apk_url:
        print(f"[bot] send_apk: try url document={row.apk_url}")
        ok = _api_post(
            "sendDocument",
            {"chat_id": chat_id, "caption": caption, "document": row.apk_url},
        )
        print(f"[bot] send_apk: url result ok={ok}")
        if ok:
            return True

    # 2) Fallback: отправка локального файла из web/
    apk_file = "Ustobozor.apk"
    if row.apk_url:
        parsed = urllib.parse.urlparse(row.apk_url)
        candidate = os.path.basename(parsed.path or "")
        if candidate:
            apk_file = candidate
    file_path = os.path.join(WEB_DIR, apk_file)
    if not os.path.exists(file_path):
        print(f"[bot] APK not found: {file_path}")
        return False
    print(f"[bot] send_apk: fallback multipart file_path={file_path}")
    return _api_post_multipart(
        "sendDocument",
        {"chat_id": chat_id, "caption": caption},
        "document",
        file_path,
        "application/vnd.android.package-archive",
    )


def handle_start(chat_id: int) -> None:
    welcome = (
        "Салом! 👋\n"
        "Ба боти «Ustobozor» хуш омадед!\n\n"
        "Магозаи Ustobozor хама намуди махсулотхои сохтмони бо нархи дастрас\n\n"
        "🧱 Масолеҳи сохтмонӣ бо нархи дастрас\n"
        "📲 Барои фармоиш ва тамос — тугмаҳоро истифода баред\n\n"
        "📋 Тугмаҳо\n\n"
        "📱 Instagram\n"
        "💬 Гурӯҳи Telegram\n"
        "📲 Гурӯҳи WhatsApp\n"
        "📥 Боргирии барнома\n\n"
        "Барномаи моро зеркашӣ кунед ва фармоишро осон анҷом диҳед! 🚀"
    )
    kb = _build_keyboard()
    payload: Dict[str, Any] = {
        "chat_id": chat_id,
        "text": welcome,
        "parse_mode": "HTML",
        "disable_web_page_preview": True,
    }
    if kb:
        payload["reply_markup"] = kb
    ok = _api_post("sendMessage", payload)
    print(f"[bot] /start -> {chat_id}, ok={ok}")


def run_bot() -> None:
    if not TELEGRAM_BOT_TOKEN:
        print("[bot] TELEGRAM_BOT_TOKEN не задан, бот не запущен")
        return

    print("[bot] Запуск long polling бота...")
    offset = None
    while True:
        params: Dict[str, Any] = {"timeout": 30}
        if offset is not None:
            params["offset"] = offset
        resp = _api_get("getUpdates", params)
        if not resp.get("ok"):
            # небольшая пауза, чтобы не крутить CPU при ошибках
            time.sleep(2)
            continue
        for upd in resp.get("result", []):
            upd_id = upd.get("update_id")
            if upd_id is not None:
                offset = upd_id + 1
            msg = upd.get("message") or {}
            text = (msg.get("text") or "").strip()
            chat = msg.get("chat") or {}
            chat_id = chat.get("id")
            if not chat_id or not text:
                pass
            elif text == "/start":
                handle_start(chat_id)

            cb = upd.get("callback_query") or {}
            if cb:
                cb_id = cb.get("id") or ""
                data = (cb.get("data") or "").strip()
                cb_msg = cb.get("message") or {}
                cb_chat_id = (cb_msg.get("chat") or {}).get("id")
                if data == "send_apk" and cb_chat_id:
                    # Сразу подтверждаем клик, чтобы callback не "протухал"
                    _answer_callback_query(cb_id, "Отправляю файл…")
                    ok = _send_apk_to_chat(int(cb_chat_id))
                    if not ok:
                        _api_post("sendMessage", {"chat_id": cb_chat_id, "text": "Не удалось отправить APK. Попробуйте снова."})
        # маленькая пауза между циклами
        time.sleep(0.5)


if __name__ == "__main__":
    try:
        run_bot()
    except KeyboardInterrupt:
        print("\n[bot] Остановлен пользователем")

