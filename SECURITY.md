# Ustobozor — стандарты безопасности

## 1. GitHub — что нельзя коммитить

| Запрещено | Статус |
|-----------|--------|
| `.env`, `.env.production`, реальные пароли | ✅ в `.gitignore` |
| SSH-ключи, `.pem`, `.key` | ✅ в `.gitignore` |
| Дампы БД (`.sql`, `.dump`) | ✅ в `.gitignore` |
| Firebase service account JSON | ✅ в `.gitignore` |
| `.env.example` (шаблон без секретов) | ✅ в репозитории |

Генерация prod-секретов локально: `UstoMarketBagk/scripts/generate_prod_env.py` → файл в gitignore.

## 2. Backend (FastAPI)

| Требование | Статус |
|------------|--------|
| Секреты только в `.env` на VPS (`chmod 600`) | ✅ скрипт `deploy/harden_server.sh` |
| Пароли мастеров/клиентов — bcrypt | ✅ `auth.py` |
| PIN админов — bcrypt (legacy SHA-256 поддерживается) | ✅ `auth.py` |
| JWT access 30 мин / refresh 30 дней | ✅ `config.py` |
| CORS только allowlist (не `*` в prod) | ✅ при `DEBUG=false` + `ALLOWED_ORIGINS` |
| Rate limit auth / OTP / admin login | ✅ slowapi + OTP limits |
| SQLAlchemy ORM (без конкатенации SQL) | ✅ |
| Pydantic на JSON API | ✅ |
| Postgres/Redis не наружу (Docker network) | ✅ `docker-compose.yml` |

## 3. Flutter

| Требование | Статус |
|------------|--------|
| JWT в `flutter_secure_storage` | ✅ UstomarketApp |
| `usesCleartextTraffic=false` | ✅ оба Android-приложения |
| Без `print` в release API-клиенте | ✅ `api_client.dart` + `kDebugMode` |
| Prod URL через `--dart-define=USE_LOCAL_API=false` | ✅ |
| SSL Pinning | ⏳ не внедрён (опционально позже) |

## 4. VPS / DevOps

| Требование | Статус |
|------------|--------|
| UFW: 22, 80, 443 (без 5432/6379/8000) | ✅ `deploy/harden_server.sh` |
| SSH только по ключу | ✅ `deploy/harden_server.sh` |
| Nginx → app:8000 | ✅ |
| HTTPS Let's Encrypt | ⏳ после DNS |
| pg_dump по cron | ✅ `deploy/backup_db.sh` |
| Смена SSH-порта | ⏳ по желанию |

## Быстрые команды на сервере

```bash
sudo bash /home/ubuntu/Ustobozor/deploy/harden_server.sh
sudo bash /home/ubuntu/Ustobozor/deploy/enable_https.sh   # после DNS
```

Релиз приложения:

```bash
flutter build apk --dart-define=USE_LOCAL_API=false
```
