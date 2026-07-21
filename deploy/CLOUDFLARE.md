# Cloudflare Tunnel (быстрый способ HTTPS для Flutter)

## 1. Проверка на сервере

```bash
scp deploy/cloudflare_tunnel.sh root@185.185.142.229:/root/
bash /root/cloudflare_tunnel.sh check
```

## 2. Запуск (одна команда)

```bash
bash /root/cloudflare_tunnel.sh run
```

URL в выводе: `https://xxxx.trycloudflare.com` → вставить в `baseUrl`.

## 3. Flutter

```dart
const String baseUrl = 'https://xxxx.trycloudflare.com';
```

```powershell
flutter clean && flutter pub get && flutter run
```

## 4. Автозапуск

```bash
bash /root/cloudflare_tunnel.sh install
journalctl -u cloudflared-ustobozor -f
```

Quick Tunnel URL меняется после перезапуска. Для постоянного домена — named tunnel в Cloudflare Dashboard.
