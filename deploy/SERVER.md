# Ustomarket — HTTPS API (prod)

## Base URL (Flutter)

```
https://api.ustomarket.tj
```

| Сервис   | URL |
|----------|-----|
| API      | https://api.ustomarket.tj |
| Web/PWA  | https://api.ustomarket.tj/web/ |
| Админка  | https://api.ustomarket.tj/admin/login |
| Swagger  | https://api.ustomarket.tj/docs |

---

## Шаг 1. DNS (Timeweb / регистратор домена)

Добавьте **A-запись**:

| Имя | Тип | Значение |
|-----|-----|----------|
| `api` | A | `185.185.142.229` |

Проверка (через 5–30 мин):

```bash
dig +short api.ustomarket.tj @8.8.8.8
# должно вернуть: 185.185.142.229
```

Timeweb Firewall: открыть **TCP 80** и **TCP 443**.

---

## Шаг 2. HTTPS на сервере

```bash
# Загрузить с ПК:
scp deploy/nginx-api-ustomarket.conf deploy/setup_https_api.sh root@185.185.142.229:/root/

# На сервере:
chmod +x /root/setup_https_api.sh
bash /root/setup_https_api.sh
```

Скрипт: Nginx → uvicorn :8000, Certbot (Let's Encrypt), редирект HTTP→HTTPS.

---

## Шаг 3. Flutter

`UstomarketApp/lib/constants.dart`:

```dart
const String baseUrl = 'https://api.ustomarket.tj';
```

```powershell
cd UstomarketApp
flutter clean
flutter pub get
flutter run
```

---

## Критерии приёмки

- [ ] `https://api.ustomarket.tj/products` открывается в браузере телефона
- [ ] Приложение загружает каталог без `Cleartext HTTP` / `TimeoutException`
- [ ] В логах: `API OK GET /products -> 200`

---

## Сервер (systemd)

```bash
systemctl status ustomarket nginx
systemctl restart ustomarket
journalctl -u ustomarket -f
```

Проект: `/root/backendGreen`
