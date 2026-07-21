# Ustobozor

Монорепозиторий платформы **Ustobozor** — интернет-магазин строительных материалов и сервис мастеров (Истаравшан, TJ).

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

## Домен

- Prod: `https://ustobozor.tj`
- API и PWA обслуживаются backend-ом на порту `:8000` (nginx на VPS)

## Секреты

Не коммитить: `.env`, Firebase service account, deploy-ключи. Использовать `.env.example` как шаблон.
