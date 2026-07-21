"""Создание базы PostgreSQL из Python (удобно для Windows). Запуск: python create_db.py"""
import os
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(Path(__file__).resolve().parent / ".env")
except ImportError:
    pass

url = os.getenv("DATABASE_URL", "")
if "postgresql" not in url:
    print("DATABASE_URL не для PostgreSQL. Для SQLite этот скрипт не нужен.")
    sys.exit(0)

try:
    part = url.split("://", 1)[-1]
    auth, rest = part.split("@", 1)
    user, password = auth.split(":", 1)
    host_port, dbname = rest.split("/", 1)
    if "?" in dbname:
        dbname = dbname.split("?")[0]
    host, port = (host_port.rsplit(":", 1) if ":" in host_port else (host_port, "5432"))
except Exception:
    print("Неверный DATABASE_URL. Пример: postgresql://postgres:postgres@localhost:5432/market")
    sys.exit(1)

try:
    import psycopg2
    from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
except ImportError:
    print("Установите драйвер: pip install psycopg2-binary")
    sys.exit(1)

try:
    c = psycopg2.connect(host=host, port=port, user=user, password=password, database="postgres")
    c.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
    cur = c.cursor()
    cur.execute("SELECT 1 FROM pg_database WHERE datname = %s", (dbname,))
    if cur.fetchone():
        print(f"База '{dbname}' уже есть.")
    else:
        cur.execute(f'CREATE DATABASE "{dbname}"')
        print(f"База '{dbname}' создана.")
    cur.close()
    c.close()
except Exception as e:
    print("Ошибка:", e)
    print("Проверьте: PostgreSQL запущен, в .env верные логин/пароль/хост.")
    sys.exit(1)
