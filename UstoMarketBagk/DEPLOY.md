# Деплой через GitHub — пошагово

Обновление на сервере: `git pull` → пересборка и перезапуск контейнеров. Код хранится в GitHub, на сервере только клонируем и поднимаем Docker.

---

## Часть 1: Подготовка репозитория (один раз)

### 1.1 Убедиться, что в GitHub не попадают секреты

- В корне проекта есть **`.gitignore`** (в нём указаны `.env`, `venv/`, `__pycache__/` и т.д.).
- Файл **`.env`** не должен быть в репозитории. В репо есть **`.env.example`** — шаблон для создания `.env` на сервере.

Если `.env` уже был запушен — удалите его из репо и смените пароли/токены:

```bash
git rm --cached .env
git commit -m "Remove .env from repo"
git push
```

### 1.2 Всё пушим в GitHub

```bash
cd "путь/к/UstoMarketBagk"
git add .
git commit -m "Deploy: docker-compose, .env.example, scripts"
git push origin main
```

Дальше работаем на **сервере** (Timeweb VPS).

---

## Часть 2: Первый деплой на сервере

### 2.1 Подключиться по SSH

```bash
ssh root@89.169.44.43
```

(Подставьте свой IP, если другой.)

### 2.2 Установить Docker и Docker Compose

```bash
apt update && apt install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME:-$VERSION_CODENAME}") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Проверка:

```bash
docker --version
docker compose version
```

### 2.3 Клонировать репозиторий

Подставьте свой репозиторий (HTTPS или SSH):

```bash
cd /root
git clone https://github.com/YakubiAbM/UstoMarketBagk.git
cd UstoMarketBagk
```

Если репозиторий **приватный** — на сервере должен быть настроен доступ (SSH-ключ и Deploy key в GitHub, либо токен).

### 2.4 Создать файл `.env` на сервере

Файл `.env` в репо не храним — создаём его вручную на сервере:

```bash
cp .env.example .env
nano .env
```

Заполните (пароль БД должен совпадать с `POSTGRES_PASSWORD` в `docker-compose.yml` — по умолчанию `7900`):

- `SUPERADMIN_PHONE_NORM` — ваш телефон (нормализованный, только цифры).
- `SUPERADMIN_PASSWORD` — пароль входа в админку.
- `DATABASE_URL` в `.env` можно не менять — в `docker-compose.yml` он переопределён на `postgresql://postgres:7900@db:5432/market`.

Сохраните: `Ctrl+O`, Enter, `Ctrl+X`.

### 2.4.1 Push-уведомления и штрихкоды (опционально)

- **Push (FCM):** Положите в каталог проекта на сервере файл `firebase-service-account.json` (скачать в Firebase Console → Project settings → Service accounts → Generate new private key). В `.env` добавьте строку: `FCM_SERVICE_ACCOUNT_PATH=firebase-service-account.json`. Контейнер монтирует этот файл при запуске.
- **Штрихкоды:** Для генерации штрихкодов мастеров в образе должен быть установлен Pillow (уже есть в `requirements.txt`). После обновления кода пересоберите образ: `docker compose build --no-cache app && docker compose up -d`.

### 2.5 Запустить приложение

```bash
docker compose up -d --build
```

Проверка:

```bash
docker compose ps
curl -s http://localhost:8000/docs
```

Откройте в браузере: **http://89.169.44.43:8000** (ваш IP).  
Админка: **http://89.169.44.43:8000/admin/**  
PWA: **http://89.169.44.43:8000/web/**

### 2.6 (По желанию) Открыть порт 8000 в фаерволе

В панели Timeweb: **Сеть** → правила фаервола для сервера — разрешите входящий TCP **8000**. Если порт уже открыт, шаг можно пропустить.

---

## Часть 3: Обновление через GitHub (каждый раз)

Когда вы меняете код и пушите в GitHub, на сервере делайте так.

### Вариант A: Вручную

```bash
ssh root@89.169.44.43
cd ~/backendGreen
git pull
docker compose up -d --build
```

### Вариант B: Скрипт

```bash
ssh root@89.169.44.43
cd /root/UstoMarketBagk
chmod +x scripts/update.sh
./scripts/update.sh
```

Скрипт выполняет `git pull` и `docker compose up -d --build`.

### Если `git pull` на сервере ругается на `.env` или `requirements.txt`

Иногда на сервере меняется локальный `.env` (пароли, токены) или ставятся пакеты напрямую. Тогда при обновлении может появиться ошибка вида:

```text
error: Your local changes to the following files would be overwritten by merge:
  .env
  requirements.txt
Please commit your changes or stash them before you merge.
Aborting
```

В этом случае делаем так (на сервере, в папке проекта):

```bash
cd /root/UstoMarketBagk

# 1. Сохраняем текущий .env (чтобы не потерять пароли)
cp .env /root/UstoMarketBagk.env.backup

# 2. Откатываем конфликтующие файлы для git
git restore .env requirements.txt

# 3. Подтягиваем изменения из GitHub
git pull

# 4. Возвращаем свой .env обратно
cp /root/UstoMarketBagk.env.backup .env

# 5. Пересобираем и перезапускаем контейнеры
docker compose up -d --build
```

Так вы сохраняете свои секреты на сервере, но всегда получаете свежий код и зависимости из репозитория.

---

## Краткая шпаргалка

| Действие                     | Где    | Команды                                                               |
| ---------------------------- | ------ | --------------------------------------------------------------------- |
| Обновить код и задеплоить    | Сервер | `cd /root/UstoMarketBagk && git pull && docker compose up -d --build` |
| Посмотреть логи              | Сервер | `docker compose logs -f app`                                          |
| Остановить                   | Сервер | `docker compose down`                                                 |
| Перезапустить без пересборки | Сервер | `docker compose restart app`                                          |

---

## Если что-то пошло не так

- **Нет доступа по 8000** — проверьте фаервол Timeweb и что контейнер запущен: `docker compose ps`.
- **Ошибка при сборке** — посмотрите вывод: `docker compose up --build` (без `-d`).
- **БД не поднимается** — проверьте логи: `docker compose logs db`.
- **Приложение падает** — логи приложения: `docker compose logs -f app`.

После первого успешного деплоя все дальнейшие обновления — через `git push` в GitHub и на сервере: `git pull` + `docker compose up -d --build`.
