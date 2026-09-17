"""
Миграция: добавить phone_norm, role, otp_hash, otp_attempts, otp_blocked_until в masters;
client_phone_norm, master_id в orders; таблица refresh_tokens.
Для SQLite — ADD COLUMN если нет. Для PostgreSQL — то же через raw или Alembic.
"""
import os
import sys

# Добавляем текущую директорию в path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from database import Base, engine, AdminDB

def _use_sqlite(eng):
    return "sqlite" in str(eng.url)

def run_migration():
    use_sqlite = _use_sqlite(engine)
    with engine.connect() as conn:
        if use_sqlite:
            # SQLite: добавить колонки если нет
            for col, sql in [
                ("phone_norm", "ALTER TABLE masters ADD COLUMN phone_norm VARCHAR(9)"),
                ("role", "ALTER TABLE masters ADD COLUMN role VARCHAR(16) DEFAULT 'user'"),
                ("otp_hash", "ALTER TABLE masters ADD COLUMN otp_hash VARCHAR(128)"),
                ("otp_attempts", "ALTER TABLE masters ADD COLUMN otp_attempts INTEGER NOT NULL DEFAULT 0"),
                ("otp_blocked_until", "ALTER TABLE masters ADD COLUMN otp_blocked_until INTEGER"),
                ("client_phone_norm", "ALTER TABLE orders ADD COLUMN client_phone_norm VARCHAR(9)"),
                ("master_id", "ALTER TABLE orders ADD COLUMN master_id INTEGER REFERENCES masters(id)"),
                ("telegram_chat_id", "ALTER TABLE masters ADD COLUMN telegram_chat_id VARCHAR(32)"),
                ("pin_hash", "ALTER TABLE masters ADD COLUMN pin_hash VARCHAR(64)"),
                ("password_hash", "ALTER TABLE masters ADD COLUMN password_hash VARCHAR(255)"),
                ("is_password_reset", "ALTER TABLE masters ADD COLUMN is_password_reset INTEGER NOT NULL DEFAULT 0"),
                ("is_superadmin", "ALTER TABLE masters ADD COLUMN is_superadmin INTEGER NOT NULL DEFAULT 0"),
                ("admin_permissions", "ALTER TABLE masters ADD COLUMN admin_permissions TEXT"),
                ("debt", "ALTER TABLE masters ADD COLUMN debt REAL NOT NULL DEFAULT 0"),
                ("city", "ALTER TABLE masters ADD COLUMN city VARCHAR(128) DEFAULT ''"),
                ("payment_type", "ALTER TABLE orders ADD COLUMN payment_type VARCHAR(16)"),
                ("comment", "ALTER TABLE orders ADD COLUMN comment TEXT"),
                ("user_kind", "ALTER TABLE refresh_tokens ADD COLUMN user_kind VARCHAR(16) NOT NULL DEFAULT 'master'"),
                ("moderation_status", "ALTER TABLE masters ADD COLUMN moderation_status VARCHAR(16) DEFAULT 'approved'"),
                ("moderation_note", "ALTER TABLE masters ADD COLUMN moderation_note VARCHAR(255) DEFAULT ''"),
            ]:
                try:
                    conn.execute(text(sql))
                    conn.commit()
                    print(f"  + {col}")
                except Exception as e:
                    if "duplicate column" in str(e).lower() or "already exists" in str(e).lower():
                        print(f"  (skip {col})")
                    else:
                        print(f"  ? {col}: {e}")
        else:
            # PostgreSQL
            for col, sql in [
                ("phone_norm", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS phone_norm VARCHAR(9)"),
                ("role", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS role VARCHAR(16) NOT NULL DEFAULT 'user'"),
                ("otp_hash", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS otp_hash VARCHAR(128)"),
                ("otp_attempts", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS otp_attempts INTEGER NOT NULL DEFAULT 0"),
                ("otp_blocked_until", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS otp_blocked_until INTEGER"),
                ("client_phone_norm", "ALTER TABLE orders ADD COLUMN IF NOT EXISTS client_phone_norm VARCHAR(9)"),
                ("master_id", "ALTER TABLE orders ADD COLUMN IF NOT EXISTS master_id INTEGER REFERENCES masters(id)"),
                ("telegram_chat_id", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS telegram_chat_id VARCHAR(32)"),
                ("pin_hash", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS pin_hash VARCHAR(64)"),
                ("password_hash", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255)"),
                ("is_password_reset", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS is_password_reset INTEGER NOT NULL DEFAULT 0"),
                ("is_superadmin", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS is_superadmin INTEGER NOT NULL DEFAULT 0"),
                ("admin_permissions", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS admin_permissions TEXT"),
                ("debt", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS debt DOUBLE PRECISION NOT NULL DEFAULT 0"),
                ("city", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS city VARCHAR(128) DEFAULT ''"),
                ("payment_type", "ALTER TABLE orders ADD COLUMN IF NOT EXISTS payment_type VARCHAR(16)"),
                ("comment", "ALTER TABLE orders ADD COLUMN IF NOT EXISTS comment TEXT"),
                ("user_kind", "ALTER TABLE refresh_tokens ADD COLUMN IF NOT EXISTS user_kind VARCHAR(16) NOT NULL DEFAULT 'master'"),
                ("moderation_status", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS moderation_status VARCHAR(16) DEFAULT 'approved'"),
                ("moderation_note", "ALTER TABLE masters ADD COLUMN IF NOT EXISTS moderation_note VARCHAR(255) DEFAULT ''"),
            ]:
                try:
                    conn.execute(text(sql))
                    conn.commit()
                    print(f"  + {col}")
                except Exception as e:
                    print(f"  ? {col}: {e}")

    # Таблицы refresh_tokens, master_notifications, admins создаются через create_all
    Base.metadata.create_all(bind=engine)
    print("  + refresh_tokens, master_notifications, admins (if missing)")

    # Заполнить phone_norm из phone (в Python — совместимо с SQLite и PG)
    from sqlalchemy.orm import Session
    from database import SessionLocal, MasterDB, OrderDB
    db = SessionLocal()
    try:
        for m in db.query(MasterDB).all():
            if m.phone:
                digits = "".join(c for c in m.phone if c.isdigit())
                if len(digits) >= 9:
                    m.phone_norm = digits[-9:]
        for o in db.query(OrderDB).all():
            if getattr(o, "client_phone", None) and not getattr(o, "client_phone_norm", None):
                digits = "".join(c for c in o.client_phone if c.isdigit())
                if len(digits) >= 9:
                    o.client_phone_norm = digits[-9:]
        db.commit()
        print("  Updated phone_norm / client_phone_norm")

        # Существующие мастера без статуса → approved (уже в каталоге)
        fixed = 0
        for m in db.query(MasterDB).all():
            st = getattr(m, "moderation_status", None)
            if st is None or str(st).strip() == "":
                m.moderation_status = "approved"
                fixed += 1
        if fixed:
            db.commit()
            print(f"  Backfilled moderation_status=approved for {fixed} masters")
    except Exception as e:
        print(f"  Update norms: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    print("Running auth migration...")
    run_migration()
    print("Done.")
