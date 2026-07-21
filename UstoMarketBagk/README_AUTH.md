# Security + Auth + Admin + Refresh Tokens

## Быстрый старт

1. **Зависимости**
   ```bash
   pip install -r requirements.txt
   ```

2. **Миграция БД** (добавляет `phone_norm`, `role`, OTP-поля, `refresh_tokens`, поля в `orders`)
   ```bash
   python migrate_auth.py
   ```

3. **Переменные окружения** (опционально, есть дефолты)
   - `DATABASE_URL` — SQLite по умолчанию, для prod: `postgresql://user:pass@host/db`
   - `JWT_SECRET` — секрет для JWT (обязательно сменить в prod)
   - `ACCESS_TOKEN_TTL_MINUTES` — срок жизни access (по умолчанию 45)
   - `REFRESH_TOKEN_TTL_DAYS` — срок жизни refresh (30)
   - `ALLOWED_ORIGINS` — CORS, список через запятую (пусто + DEBUG = разрешить все)
   - `SUPERADMIN_PHONE_NORM` — последние 9 цифр телефона первого админа (ему выставится `role=admin` после верификации)
   - `DEBUG` — `true`/`false`; в prod `false` (не логировать OTP в консоль)

4. **Запуск**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```

## Auth API

- **POST /auth/login** — тело `{ "phone": "+992901234567" }`. Генерирует OTP (в DEBUG пишет в консоль), сохраняет хэш. Лимит: 5/min по IP.
- **POST /auth/verify** — тело `{ "phone", "code", "name?" }`. При успехе возвращает `access_token`, `refresh_token`. Лимит: 10/min по IP.
- **POST /auth/refresh** — тело `{ "refresh_token": "..." }`. Rotation: старый refresh помечается отозванным, выдаётся новая пара. Лимит: 30/min по IP.
- **POST /auth/logout** — тело `{ "refresh_token" }`. Отзывает этот refresh.
- **POST /auth/logout_all** — заголовок `Authorization: Bearer <access_token>`. Отзывает все refresh текущего пользователя.
- **GET /auth/me** — заголовок `Authorization: Bearer <access_token>` (или cookie `access_token`). Возвращает данные текущего пользователя.

## Защищённые эндпоинты

- **GET /orders/history** — только по access token; возвращаются заказы текущего пользователя (по `client_phone_norm` или `master_id`).
- **GET/POST /admin/*** — только для пользователей с `role=admin`. Без токена/роли — 403.
- Страница входа в админку: **GET /admin/login** (без авторизации). После ввода телефона и кода выставляется cookie `access_token` и редирект на `/admin`.

## Роли и первый админ

- В БД у мастеров поле `role`: `user` или `admin`.
- Если задан `SUPERADMIN_PHONE_NORM` (9 цифр), при первом успешном `/auth/verify` для этого номера пользователю выставляется `role=admin`.

## Rate limit

- `/auth/login`: 5/min по IP  
- `/auth/verify`: 10/min по IP  
- `/auth/refresh`: 30/min по IP  
- `/chat/*`: 30/min по IP  
- `/products/search`: 60/min по IP  

При превышении — ответ **429**.

## Тесты

```bash
pip install pytest
pytest tests/ -v
```

Проверяется: нормализация телефона, обязательность токена для `/auth/me` и `/orders/history`, истечение OTP, блокировка после 5 неверных кодов, rotation refresh (старый не работает после обновления), logout отзывает refresh, `orders/history` только свои заказы.
