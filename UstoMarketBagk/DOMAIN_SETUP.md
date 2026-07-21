# Домен ustobozor.tj — пошаговая настройка

После настройки:

| URL | Что открывается |
|-----|-----------------|
| `https://ustobozor.tj/` | Интернет-магазин (PWA) |
| `https://ustobozor.tj/admin` | Веб-админка |
| `https://ustobozor.tj/admin/login` | Вход в админку |
| `https://ustobozor.tj/products` | API товаров |
| `https://ustobozor.tj/auth/login` | API авторизации мастеров |

---

## Шаг 1. DNS у регистратора домена

В панели, где купили **ustobozor.tj**, добавьте записи:

| Тип | Имя | Значение |
|-----|-----|----------|
| **A** | `@` | IP вашего VPS |
| **A** | `www` | тот же IP |

Подождите 5–30 минут. Проверка с ПК:

```powershell
nslookup ustobozor.tj
```

Должен показать IP сервера.

---

## Шаг 2. Подключитесь к VPS

```powershell
ssh root@ВАШ_IP
```

---

## Шаг 3. Обновите код на сервере

```bash
cd /root/backendGreen
# Если есть git:
git pull origin main
# Или загрузите zip / scp с ПК
```

---

## Шаг 4. SSL-сертификат

Создайте папку и положите файлы от регистратора:

```bash
mkdir -p /etc/ssl/ustobozor.tj
chmod 700 /etc/ssl/ustobozor.tj
```

Скопируйте (имена у регистратора могут отличаться):

```bash
# Пример:
cp /path/to/certificate.crt /etc/ssl/ustobozor.tj/fullchain.pem
cp /path/to/private.key      /etc/ssl/ustobozor.tj/privkey.pem
chmod 600 /etc/ssl/ustobozor.tj/privkey.pem
```

**fullchain.pem** = ваш сертификат + промежуточные CA (склеенные в один файл).

---

## Шаг 5. Nginx + автонастройка

```bash
cd /root/backendGreen
chmod +x scripts/setup_ustobozor_domain.sh
bash scripts/setup_ustobozor_domain.sh
```

Скрипт установит nginx, подключит конфиг, обновит `.env` и перезапустит `ustobozor`.

Откройте порты в фаерволе Timeweb:

- **80** (HTTP → редирект на HTTPS)
- **443** (HTTPS)

Порт **8000** наружу можно **закрыть** — сайт идёт через nginx.

---

## Шаг 6. Проверка

```bash
curl -sI https://ustobozor.tj/ | head -5
curl -sI https://ustobozor.tj/admin/login | head -5
curl -s "https://ustobozor.tj/products?limit=1" | head -c 100
```

В браузере:

1. `https://ustobozor.tj` — магазин  
2. `https://ustobozor.tj/admin` — админка  
3. Замок HTTPS в адресной строке без ошибок  

---

## Шаг 7. Мобильные приложения

На ПК уже обновлены `baseUrl`:

- `UstomarketApp/lib/constants.dart` → `https://ustobozor.tj`
- `admin_app/lib/constants.dart` → `https://ustobozor.tj`

Пересоберите и установите APK:

```powershell
cd UstomarketApp
flutter build apk
```

---

## Шаг 8. Telegram (если используете бота)

Webhook:

```
https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://ustobozor.tj/telegram/webhook
```

---

## Если что-то не работает

| Проблема | Решение |
|----------|---------|
| DNS не резолвится | Подождите / проверьте A-запись |
| ERR_SSL | Проверьте пути к `.pem` в nginx |
| 502 Bad Gateway | `systemctl status ustobozor` — uvicorn на :8000 |
| Старый /web/ | Редирект на `/` уже в коде |
| CORS в браузере | В `.env`: `ALLOWED_ORIGINS=https://ustobozor.tj` |

Логи:

```bash
journalctl -u ustobozor -f
tail -f /var/log/nginx/error.log
```

---

## Структура (как это устроено)

```
Браузер → nginx :443 (SSL)
              ↓
         uvicorn :8000 (FastAPI)
              ├── /           → PWA (папка web/)
              ├── /admin/*    → Jinja админка
              ├── /products   → API
              ├── /auth/*     → API мастеров
              └── /static/*   → картинки
```

Cloudflare Tunnel больше не нужен — можно отключить.
