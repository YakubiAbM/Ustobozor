# Ustobozor

Монорепозиторий платформы **Ustobozor** — интернет-магазин строительных материалов и сервис мастеров по всему Таджикистану.

## Структура

| Папка | Описание |
|-------|----------|
| `UstomarketApp/` | Flutter-приложение для клиентов и мастеров |
| `admin_app/` | Flutter-приложение админ-панели |
| `UstoMarketBagk/` | Backend (FastAPI), PWA (`web/`), Telegram-бот |
| `deploy/` | Скрипты деплоя (nginx, VPS, SEO) |

## Быстрый старт

### Backend + PWA (локально)

```bash
cd UstoMarketBagk
pip install -r requirements.txt
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

PWA для разработки с прокси API:

```bash
cd UstoMarketBagk/web
python dev_server.py
# → http://127.0.0.1:8765/
```

### Flutter-приложение

```bash
cd UstomarketApp
flutter pub get
flutter run -d windows   # или android / ios
```

### Админка

```bash
cd admin_app
flutter pub get
flutter run
```

## Домен / VPS

- Prod: `https://ustobozor.tj`
- VPS: `92.119.185.114`
- API и PWA: backend на `:8000` за nginx

## Секреты

Не коммитить: `.env`, `.env.production`, Firebase service account, deploy-ключи.

```bash
cd UstoMarketBagk
python3 scripts/generate_prod_env.py   # пишет .env.production (gitignore)
# на сервере: скопировать как .env
```

Шаблон без паролей: `.env.example`.
