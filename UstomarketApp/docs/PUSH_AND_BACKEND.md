# Push-уведомления и бэкенд

## Что сделано в приложении

- **Firebase Cloud Messaging (FCM)** — запрос разрешений, получение FCM-токена, обработка уведомлений в foreground/background/terminated.
- При **входе мастера** и при **открытии профиля** (если мастер залогинен) приложение отправляет FCM-токен на бэкенд.
- По **тапу на push** открывается экран «Уведомления».

## Что нужно на бэкенде для push

### 1. Регистрация FCM-токена

**POST /notifications/register_fcm**  
Заголовок: `Authorization: Bearer <access_token>` (токен мастера из `POST /auth/verify`).

Тело (JSON):
```json
{
  "fcm_token": "строка_токена_от_firebase"
}
```

Ответ: например `200 OK` и при необходимости `{"status": "success"}`.

Что делать на бэкенде: сохранить связку `master_id` ↔ `fcm_token` (в таблице или кэше). При смене токена (повторный вызов с тем же мастером) — обновить. По этому токену потом отправлять push через Firebase Admin SDK.

### 2. Отправка push через Firebase

- В проекте Firebase (Console) включить Cloud Messaging.
- На сервере использовать **Firebase Admin SDK** (Python/Node/др.): инициализация с `service account key`, вызов типа `send()` с `token=fcm_token` и `notification={title, body}` (и при необходимости `data` для глубоких ссылок).

Пример (Python):
```python
from firebase_admin import messaging
messaging.send(messaging.Message(
    notification=messaging.Notification(title="Акция", body="Скидка 20%"),
    token=fcm_token,
))
```

Так можно слать уведомления об акциях (`promo`), о начислении баллов (`points_added`) и т.д., используя сохранённые FCM-токены мастеров.

## iOS

В Xcode для проекта включить:
- **Signing & Capabilities** → **Push Notifications**
- **Background Modes** → **Remote notifications**

После этого push будут приходить и на iOS.
