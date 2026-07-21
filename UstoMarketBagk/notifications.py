"""
Уведомления для мастеров: запись в БД + push через Firebase Cloud Messaging.
Все созданные уведомления (promo, points_added, points_spent, debt и др.) отправляются и как push.
Поддерживается FCM HTTP v1 (service account) и legacy Server Key.
"""

import json
import os
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import httpx
from sqlalchemy.orm import Session

from config import FCM_SERVER_KEY, FCM_SERVICE_ACCOUNT_PATH
from database import MasterNotificationDB, DeviceTokenDB

# Формат даты/времени для created_at, read_at
DATETIME_FMT = "%Y-%m-%d %H:%M"

FCM_LEGACY_URL = "https://fcm.googleapis.com/fcm/send"
FCM_V1_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"

# Кэш для access token (v1): (token, expires_timestamp)
_fcm_v1_token_cache: Optional[Tuple[str, float]] = None


def _get_fcm_v1_access_token() -> Optional[str]:
    """Получает OAuth2 access token для FCM HTTP v1 из service account JSON (с кэшем)."""
    global _fcm_v1_token_cache
    import time
    now = time.time()
    if _fcm_v1_token_cache and _fcm_v1_token_cache[1] > now:
        return _fcm_v1_token_cache[0]
    if not FCM_SERVICE_ACCOUNT_PATH:
        return None
    path = Path(FCM_SERVICE_ACCOUNT_PATH)
    if not path.is_absolute():
        path = Path(__file__).resolve().parent / path
    if not path.exists():
        print(f"[FCM] Файл не найден: {path}")
        return None
    try:
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request
        credentials = service_account.Credentials.from_service_account_file(
            str(path), scopes=[FCM_V1_SCOPE]
        )
        credentials.refresh(Request())
        _fcm_v1_token_cache = (credentials.token, now + 3300)
        return credentials.token
    except Exception as e:
        print(f"[FCM] Ошибка получения токена: {e}")
        return None


def _send_push_v1(project_id: str, token: str, title: str, body: str, data: Dict[str, str]) -> None:
    """Один запрос FCM HTTP v1 на одно устройство."""
    access_token = _get_fcm_v1_access_token()
    if not access_token:
        return
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }
    payload = {
        "message": {
            "token": token,
            "notification": {"title": title, "body": body},
            "data": data,
        }
    }
    try:
        r = httpx.post(url, json=payload, headers=headers, timeout=10.0)
        if r.status_code != 200:
            print(f"[FCM] Ответ {r.status_code}: {r.text[:200]}")
    except Exception as e:
        print(f"[FCM] Ошибка отправки: {e}")


def _send_push_legacy(tokens: List[str], title: str, body: str, payload: Dict[str, Any]) -> None:
    """Legacy FCM (registration_ids + Server key)."""
    if not FCM_SERVER_KEY or not tokens:
        return
    data = {
        "registration_ids": tokens,
        "notification": {"title": title, "body": body},
        "data": payload or {},
    }
    headers = {
        "Authorization": f"key={FCM_SERVER_KEY}",
        "Content-Type": "application/json",
    }
    try:
        httpx.post(FCM_LEGACY_URL, json=data, headers=headers, timeout=5.0)
    except Exception:
        pass


def _send_push_to_master(
    db: Session,
    master_id: int,
    title: str,
    body: str,
    payload: Optional[Dict[str, Any]] = None,
) -> None:
    """
    Отправляет push мастеру через FCM.
    Если задан FCM_SERVICE_ACCOUNT_PATH — используется HTTP v1, иначе legacy Server key.
    """
    tokens: List[str] = [
        t.token
        for t in db.query(DeviceTokenDB)
        .filter(DeviceTokenDB.master_id == master_id, DeviceTokenDB.is_active == 1)
        .all()
    ]
    if not tokens:
        return

    payload = payload or {}

    if FCM_SERVICE_ACCOUNT_PATH:
        path = Path(FCM_SERVICE_ACCOUNT_PATH)
        if not path.is_absolute():
            path = Path(__file__).resolve().parent / path
        if not path.exists():
            print(f"[FCM] Service account не найден: {path}")
        elif path.exists():
            try:
                with open(path, "r", encoding="utf-8") as f:
                    info = json.load(f)
                project_id = info.get("project_id")
                if project_id:
                    # FCM v1 требует строковые значения в data
                    data = {k: str(v) for k, v in payload.items()}
                    for token in tokens:
                        _send_push_v1(project_id, token, title, body, data)
            except Exception:
                pass
        return

    _send_push_legacy(tokens, title, body, payload)


def create_notification(
    db: Session,
    master_id: int,
    type_: str,
    title: str,
    body: str = "",
    payload: Optional[Dict[str, Any]] = None,
) -> MasterNotificationDB:
    """Создаёт уведомление для мастера, сохраняет в БД и (для нужных типов) шлёт push."""
    now = datetime.now().strftime(DATETIME_FMT)
    payload = payload or {}
    row = MasterNotificationDB(
        master_id=master_id,
        type=type_,
        title=title,
        body=body,
        payload_json=json.dumps(payload, ensure_ascii=False),
        created_at=now,
        read_at=None,
    )
    db.add(row)
    db.commit()
    db.refresh(row)

    # Все уведомления дублируем push-ом на устройство мастера (акции, баллы, долг и любые другие типы).
    _send_push_to_master(db, master_id, title, body, payload)

    return row


def create_promo_for_all(db: Session, title: str, body: str) -> int:
    """
    Рассылает уведомление-акцию (promo) всем зарегистрированным мастерам.
    Возвращает количество созданных уведомлений.
    """
    from database import MasterDB

    masters = db.query(MasterDB).all()
    count = 0
    for m in masters:
        create_notification(db, m.id, "promo", title, body, {})
        count += 1
    return count
