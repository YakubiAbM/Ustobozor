"""
Точка входа: FastAPI-приложение Ustobozor.
Публичное API: товары, бренды, мастера, заказы (с авторизацией), чат-бот.
Админка и auth вынесены в роутеры (admin_routes, auth_routes).
"""

import json
import os
import time
import uuid
import random
from datetime import datetime
from typing import List, Optional, Any
import urllib.parse
import re

from fastapi import FastAPI, HTTPException, Depends, Query, Request, BackgroundTasks
from fastapi.responses import JSONResponse, RedirectResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from sqlalchemy import or_
from pydantic import BaseModel

from database import (
    SessionLocal, get_db, ProductDB, MasterDB, AdminDB, OrderDB, ChatSessionDB,
    ProductResponse, MasterResponse, OrderResponse, OrderCreate,
    ChatMessage, ChatPick, ChatAction, ChatSubmit,
    MasterNotificationDB, NotificationResponse, DeviceTokenDB, ProductStockDB, SiteSettingsDB,
)
from search_engine import (
    refresh_products_cache, TextParser, SearchEngine,
    THRESHOLD_AUTO, THRESHOLD_GAP, PRODUCTS_CACHE,
)
from admin_routes import router as admin_router
from admin_mobile_api import router as admin_mobile_router
from auth_routes import router as auth_router
from client_auth_routes import router as client_auth_router
from auth import (
    normalize_phone,
    get_current_user,
    get_master_for_me,
    get_master_for_orders_history,
    create_access_token,
    create_superadmin_session_value,
    hash_pin,
    verify_pin_hash,
    SUPERADMIN_SESSION_COOKIE,
    SUPERADMIN_SESSION_TTL_SECONDS,
)
from telegram_notify import notify_new_order, answer_callback_query, edit_message_text, edit_message_reply_markup, _send_to_chat
from order_actions import apply_order_status_change

try:
    from config import ALLOWED_ORIGINS, CORS_ALLOW_ALL, SUPERADMIN_PHONE_NORM, SUPERADMIN_PASSWORD
except ImportError:
    ALLOWED_ORIGINS = []
    CORS_ALLOW_ALL = True
    SUPERADMIN_PHONE_NORM = ""
    SUPERADMIN_PASSWORD = ""


class CalculatorEstimateRequest(BaseModel):
    length: float
    width: float
    height: float
    doors: int = 0
    windows: int = 0
    include_ceiling: bool = False
    work_types: Optional[List[str]] = None

os.makedirs("static/images", exist_ok=True)
_WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "web")
os.makedirs(_WEB_DIR, exist_ok=True)

# -----------------------------------------------------------------------------
# Приложение и middleware
# -----------------------------------------------------------------------------
app = FastAPI()
origins = list(ALLOWED_ORIGINS) if not CORS_ALLOW_ALL else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Добавляет заголовки безопасности к каждому ответу."""
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    return response


try:
    from slowapi.errors import RateLimitExceeded
    from slowapi import _rate_limit_exceeded_handler
    from rate_limit import limiter
    if limiter:
        app.state.limiter = limiter
        app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
except Exception:
    pass

app.mount("/static", StaticFiles(directory="static"), name="static")
# PWA монтируется в конец main.py (после всех API), чтобы / = магазин, /admin = админка.


@app.get("/download-apk")
def download_apk(file: str = Query("Ustobozor.apk", description="Имя APK-файла из папки web/")):
    """
    Отдаёт APK как attachment, чтобы Telegram/WebView корректно инициировал скачивание.
    """
    safe_name = os.path.basename(file or "")
    if not re.match(r"^[A-Za-z0-9._\\-]+$", safe_name):
        raise HTTPException(status_code=400, detail="Некорректное имя файла")
    path = os.path.join(_WEB_DIR, safe_name)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="Файл не найден")
    return FileResponse(
        path,
        media_type="application/vnd.android.package-archive",
        filename=safe_name,
    )
app.include_router(auth_router)
app.include_router(auth_router, prefix="/api/v1")
app.include_router(client_auth_router)
app.include_router(client_auth_router, prefix="/api/v1")
app.include_router(admin_router)
app.include_router(admin_mobile_router)
templates = Jinja2Templates(directory="templates")


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """При 403 в админке — редирект на /admin (откроется первый доступный раздел). Иначе — страница «Нет доступа»."""
    path = request.url.path
    is_admin_api = path.startswith("/admin/api")

    if exc.status_code == 403 and path.startswith("/admin/"):
        if is_admin_api:
            return JSONResponse(status_code=403, content={"detail": exc.detail})
        return RedirectResponse(url="/admin", status_code=302)
    if exc.status_code == 403:
        return templates.TemplateResponse(request, "403.html",
            {"request": request},
            status_code=403,
        )
    # Браузер без сессии на /admin → страница входа; mobile API — JSON 401
    if exc.status_code == 401:
        if is_admin_api:
            return JSONResponse(status_code=401, content={"detail": exc.detail})
        if request.method == "GET" and path.startswith("/admin") and path != "/admin/login" and not path.startswith("/admin/login/"):
            return RedirectResponse(url="/admin/login", status_code=302)
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


# -----------------------------------------------------------------------------
# Вспомогательные функции
# -----------------------------------------------------------------------------

def _parse_json_field(value: Optional[str], default: Any = None) -> Any:
    """Безопасный разбор JSON-поля из БД; при ошибке возвращает default."""
    if value is None or value == "":
        return default if default is not None else []
    try:
        return json.loads(value)
    except (json.JSONDecodeError, TypeError):
        return default if default is not None else []


def _product_to_response(p: ProductDB) -> ProductResponse:
    """Собирает ProductResponse из модели ProductDB (парсит JSON-поля)."""
    sizes = _parse_json_field(p.sizes_json, [])
    photos = _parse_json_field(p.photos_json, [])
    colors = _parse_json_field(p.colors_json, [])
    if not photos and p.image:
        photos = [p.image]
    return ProductResponse(
        id=p.id, name=p.name, price=p.price, brand=p.brand or "",
        category=p.category, subcategory=p.subcategory,
        description=p.description or "", unit=p.unit, image=p.image,
        articul=p.articul or "", photos=photos, sizes=sizes, colors=colors,
    )


def _order_phone_norm(phone: str) -> str:
    """Нормализует телефон заказа (последние 9 цифр) для индекса."""
    return normalize_phone(phone) if phone else ""


def _apply_rate_limit(limit: str):
    """Декоратор rate limit по IP; при отсутствии slowapi ограничение не применяется."""

    def decorator(f):
        try:
            from rate_limit import limiter
            if limiter:
                return limiter.limit(limit)(f)
            return f
        except Exception:
            return f

    return decorator


# -----------------------------------------------------------------------------
# Страница входа в админку и API входа (телефон → OTP или PIN, установка PIN)
# -----------------------------------------------------------------------------

@app.get("/admin/login")
def admin_login_page(request: Request):
    """Страница входа: логин + пароль (супер-админ из .env)."""
    return templates.TemplateResponse(request, "admin_login.html", {"request": request})


def _get_superadmin_credentials():
    """Логин и пароль супер-админа из .env."""
    from pathlib import Path
    try:
        from dotenv import load_dotenv
        base = Path(__file__).resolve().parent
        for path in [base / ".env", Path(os.getcwd()) / ".env", base.parent / ".env"]:
            if path.exists():
                load_dotenv(path, override=True)
                break
    except Exception:
        pass
    phone_raw = (os.getenv("SUPERADMIN_PHONE_NORM") or os.getenv("SUPERADMIN_PHONE") or "").strip()
    pwd = (os.getenv("SUPERADMIN_PASSWORD") or "").strip()
    # Если не подхватилось из dotenv — читаем .env вручную
    if not phone_raw or not pwd:
        for path in [Path(__file__).resolve().parent / ".env", Path(os.getcwd()) / ".env"]:
            if path.exists():
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            line = line.strip()
                            if line.startswith("SUPERADMIN_PHONE_NORM=") or line.startswith("SUPERADMIN_PHONE="):
                                phone_raw = line.split("=", 1)[1].strip().strip('"').strip("'")
                            elif line.startswith("SUPERADMIN_PASSWORD="):
                                pwd = line.split("=", 1)[1].strip().strip('"').strip("'")
                except Exception:
                    pass
                break
    digits = "".join(c for c in (phone_raw or "") if c.isdigit())
    phone_norm = digits[-9:] if len(digits) >= 9 else digits
    return phone_norm, pwd


@app.post("/admin/login")
async def admin_login_submit(request: Request, db: Session = Depends(get_db)):
    """Вход: супер-админ по .env или сотрудник (админ из раздела «Админы») по номеру и паролю (PIN)."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    login = str((body.get("login") or body.get("phone") or "")).strip()
    password = str((body.get("password") or body.get("pin") or "")).strip()
    login_norm = normalize_phone(login)
    if not login_norm or len(login_norm) < 9:
        raise HTTPException(status_code=400, detail="Логин: укажите номер (9 цифр)")
    if not password:
        raise HTTPException(status_code=400, detail="Введите пароль")

    # 1) Супер-админ из .env
    super_phone, super_pwd = _get_superadmin_credentials()
    if super_phone and super_pwd and login_norm == super_phone and password == super_pwd:
        response = JSONResponse({"status": "success", "redirect": "/admin"})
        response.set_cookie(
            key=SUPERADMIN_SESSION_COOKIE,
            value=create_superadmin_session_value(),
            path="/",
            max_age=SUPERADMIN_SESSION_TTL_SECONDS,
            httponly=True,
            samesite="lax",
        )
        response.delete_cookie("access_token", path="/")
        return response

    # 2) Сотрудник (админ): ищем в таблице admins по номеру, проверяем PIN
    admin = db.query(AdminDB).filter(AdminDB.phone_norm == login_norm).first()
    if not admin:
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")
    if not verify_pin_hash(admin.pin_hash, password):
        raise HTTPException(status_code=401, detail="Неверный логин или пароль")
    token = create_access_token(phone_norm=login_norm, admin_id=admin.id)
    response = JSONResponse({"status": "success", "redirect": "/admin"})
    response.set_cookie(
        key="access_token",
        value=token,
        path="/",
        max_age=2592000,
        httponly=True,
        samesite="lax",
    )
    response.delete_cookie(SUPERADMIN_SESSION_COOKIE, path="/")
    return response


@app.post("/admin/login/check_phone")
async def admin_login_check_phone(
    request: Request,
    db: Session = Depends(get_db),
):
    """По номеру телефона возвращает step: 'otp' (первый раз) или 'pin' (вход по паролю/супер-админ)."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    phone = (body.get("phone") or "").strip() if isinstance(body, dict) else ""
    if not phone:
        raise HTTPException(status_code=400, detail="phone required")
    phone_norm = normalize_phone(phone)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Invalid phone")
    # Супер-админ: логин из .env — сразу показываем поле пароля
    if SUPERADMIN_PHONE_NORM and SUPERADMIN_PASSWORD and phone_norm == SUPERADMIN_PHONE_NORM:
        return {"step": "pin"}
    # Админ из таблицы admins (вход только по PIN)
    admin = db.query(AdminDB).filter(AdminDB.phone_norm == phone_norm).first()
    if not admin:
        raise HTTPException(status_code=404, detail="User not found")
    return {"step": "pin"}


@app.post("/admin/login/verify_pin")
async def admin_login_verify_pin(
    request: Request,
    db: Session = Depends(get_db),
):
    """Вход: супер-админ по логину+паролю из .env либо обычный админ по 4-значному PIN."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    body = body or {}
    phone = str((body.get("phone") or "")).strip()
    pin = str((body.get("pin") or "")).strip()
    if not phone or len(phone_norm := normalize_phone(phone)) < 9:
        raise HTTPException(status_code=400, detail="phone required")
    # Супер-админ: логин + пароль из .env, без JWT — ставим подписанную cookie
    if SUPERADMIN_PHONE_NORM and SUPERADMIN_PASSWORD and phone_norm == SUPERADMIN_PHONE_NORM and pin == SUPERADMIN_PASSWORD:
        response = JSONResponse({"status": "success", "redirect": "/admin"})
        response.set_cookie(
            key=SUPERADMIN_SESSION_COOKIE,
            value=create_superadmin_session_value(),
            path="/",
            max_age=SUPERADMIN_SESSION_TTL_SECONDS,
            httponly=True,
            samesite="lax",
        )
        # Удалить старый JWT, чтобы не подменял супер-админа
        response.delete_cookie("access_token", path="/")
        return response
    # Обычный админ из таблицы admins: 4-значный PIN
    if not pin or len(pin) != 4 or not pin.isdigit():
        raise HTTPException(status_code=400, detail="PIN должен быть 4 цифры")
    admin = db.query(AdminDB).filter(AdminDB.phone_norm == phone_norm).first()
    if not admin:
        raise HTTPException(status_code=403, detail="Not admin")
    if not verify_pin_hash(admin.pin_hash, pin):
        raise HTTPException(status_code=401, detail="Неверный PIN")
    token = create_access_token(phone_norm=phone_norm, admin_id=admin.id)
    return {"status": "success", "access_token": token, "redirect": "/admin"}


# -----------------------------------------------------------------------------
# Публичное API: бренды и товары
# -----------------------------------------------------------------------------

@app.get("/brands")
def get_brands_api(db: Session = Depends(get_db)):
    """Список уникальных брендов (для фильтра / товары по бренду)."""
    rows = db.query(ProductDB.brand).distinct().all()
    brands = sorted([r[0] for r in rows if r[0] and str(r[0]).strip()])
    return brands


@app.get("/site/about")
def get_site_about(db: Session = Depends(get_db)):
    """Публичная информация «О нас» и ссылки на соцсети для приложения и PWA."""
    row = db.query(SiteSettingsDB).filter(SiteSettingsDB.id == 1).first()
    if not row:
        row = SiteSettingsDB(id=1)
        db.add(row)
        db.commit()
        db.refresh(row)
    return {
        "company_name": "ООО ОРОИШ 2015",
        "description": (
            "Мы уже более 20 лет занимаемся оптовой и розничной торговлей "
            "в сфере строительных материалов."
        ),
        "years_experience": 20,
        "instagram_url": (row.instagram_url or "").strip(),
        "tiktok_url": (row.tiktok_url or "").strip(),
        "telegram_url": (row.telegram_channel_url or "").strip(),
        "whatsapp_url": (row.whatsapp_group_url or "").strip(),
    }


def _out_of_stock_ids(db: Session):
    rows = db.query(ProductStockDB.product_id).filter(ProductStockDB.is_in_stock == 0).all()
    return [r[0] for r in rows if r and r[0] is not None]

class PaginatedProductsResponse(BaseModel):
    items: List[ProductResponse]
    total: int
    has_more: bool


@app.get("/products", response_model=PaginatedProductsResponse)
def get_products_api(
    brand: Optional[str] = Query(None, description="Фильтр по бренду"),
    category: Optional[str] = Query(None, description="Фильтр по категории"),
    subcategory: Optional[str] = Query(None, description="Фильтр по подкатегории"),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
):
    """Список товаров с пагинацией (limit/offset) и фильтрами.

    ⚡ v2: самые популярные (часто заказываемые) товары идут первыми.
    Основано на поле ProductDB.sales_count, которое увеличивается при проведении заказов.
    """
    q = db.query(ProductDB).order_by(ProductDB.sales_count.desc(), ProductDB.id.desc())
    out_ids = _out_of_stock_ids(db)
    if out_ids:
        q = q.filter(~ProductDB.id.in_(out_ids))
    if brand and brand.strip():
        q = q.filter(ProductDB.brand == brand.strip())
    if category and category.strip():
        q = q.filter(ProductDB.category == category.strip())
    if subcategory and subcategory.strip():
        q = q.filter(ProductDB.subcategory == subcategory.strip())

    total = q.count()
    products = q.offset(offset).limit(limit).all()
    items = [_product_to_response(p) for p in products]
    return PaginatedProductsResponse(
        items=items,
        total=total,
        has_more=(offset + len(items)) < total,
    )


@app.get("/products/recommended", response_model=List[ProductResponse])
def get_recommended_products_api(limit: int = 10, db: Session = Depends(get_db)):
    """Рекомендуемые товары (топ по продажам, sales_count)."""
    q = db.query(ProductDB).order_by(ProductDB.sales_count.desc())
    out_ids = _out_of_stock_ids(db)
    if out_ids:
        q = q.filter(~ProductDB.id.in_(out_ids))
    popular = q.limit(limit).all()
    return [_product_to_response(p) for p in popular]


@app.get("/products/search", response_model=List[ProductResponse])
@_apply_rate_limit("60/minute")
def search_products_api(
    request: Request,
    q: str = Query(..., min_length=1),
    category: Optional[str] = None,
    limit: int = 40,
    offset: int = 0,
    db: Session = Depends(get_db),
):
    """Полнотекстовый поиск товаров (по имени/категории)."""
    results = SearchEngine.search_api(q, category, limit, offset)
    out_ids = set(_out_of_stock_ids(db))
    if out_ids:
        results = [x for x in results if int(x.get("id", 0)) not in out_ids]
    for item in results:
        item.pop("_score", None)
    return [ProductResponse(**item) for item in results]


# -----------------------------------------------------------------------------
# Публичное API: мастера
# -----------------------------------------------------------------------------

@app.get("/masters", response_model=List[MasterResponse])
def get_masters_api(db: Session = Depends(get_db)):
    """Список мастеров, отсортированный по баллам (points) по убыванию."""
    masters = db.query(MasterDB).order_by(MasterDB.points.desc()).all()
    out = []
    for m in masters:
        pf = _parse_json_field(m.portfolio_json, [])
        srv = _parse_json_field(m.services_json, [])
        cats = _parse_json_field(m.categories_json, [])
        exp = m.experience if m.experience is not None else 0
        out.append(MasterResponse(
            id=m.id, name=m.name, phone=m.phone, description=m.description or "",
            experience=exp, image=m.image, rating=m.rating,
            categories=cats, portfolio=pf, services=srv,
        ))
    return out


@app.post("/api/v1/calculator/estimate-room")
def estimate_room_materials(payload: CalculatorEstimateRequest, db: Session = Depends(get_db)):
    """
    Умный калькулятор материалов по геометрии помещения.
    Расчет ориентировочный: формулы + запас 10%.
    """
    if payload.length <= 0 or payload.width <= 0 or payload.height <= 0:
        raise HTTPException(status_code=400, detail="length, width, height должны быть больше 0")
    if payload.doors < 0 or payload.windows < 0:
        raise HTTPException(status_code=400, detail="doors и windows не могут быть отрицательными")

    # 1) Площадь стен и вычет проемов
    s_total = (payload.length + payload.width) * 2.0 * payload.height
    s_netto = s_total - (payload.doors * 1.6) - (payload.windows * 2.25)
    if payload.include_ceiling:
        s_netto += payload.length * payload.width
    s_netto = max(0.0, s_netto)

    # 2) Нормативы (средние, из ТЗ) + 10% запас
    reserve = 1.10
    standards = {
        "plastering": {
            "name": "Штукатурка (Ротбанд)",
            "unit": "кг",
            "rate_per_m2": 8.5,   # при среднем слое 10 мм
            "pack_key": "bags_25kg",
            "pack_size": 25.0,
            "description": "При среднем слое 10мм",
        },
        "priming": {
            "name": "Грунтовка глубокого проникновения",
            "unit": "л",
            "rate_per_m2": 0.15,  # 1 слой
            "pack_key": "canisters_10l",
            "pack_size": 10.0,
            "description": "В один слой",
        },
        "puttying": {
            "name": "Шпаклевка финишная",
            "unit": "кг",
            "rate_per_m2": 1.8,   # 1.2 кг * 1.5 мм
            "pack_key": "bags_20kg",
            "pack_size": 20.0,
            "description": "Для подготовки под покраску",
        },
        "painting": {
            "name": "Краска моющаяся",
            "unit": "л",
            "rate_per_m2": 0.2,   # 2 слоя
            "pack_key": "canisters_5l",
            "pack_size": 5.0,
            "description": "Расчет в два слоя",
        },
    }

    selected_works = payload.work_types or ["plastering", "puttying", "priming", "painting"]
    selected_works = [w.strip().lower() for w in selected_works if w and w.strip()]

    materials = []
    for work in selected_works:
        std = standards.get(work)
        if not std:
            continue
        amount = round(s_netto * std["rate_per_m2"] * reserve, 1)
        pack_count = int((amount + std["pack_size"] - 1e-9) // std["pack_size"])
        if (pack_count * std["pack_size"]) < amount:
            pack_count += 1
        item = {
            "name": std["name"],
            "amount": amount,
            "unit": std["unit"],
            std["pack_key"]: pack_count,
            "description": std["description"],
        }
        materials.append(item)

    # 3) Рекомендации из магазина: Top-3 по продажам в целевых категориях
    recommended_products = []
    target_categories = ["Краска", "Штукатурка", "Шпаклевка", "Грунтовка"]
    for cat in target_categories:
        rows = (
            db.query(ProductDB)
            .filter(ProductDB.category.ilike(f"%{cat}%"))
            .order_by(ProductDB.sales_count.desc(), ProductDB.id.desc())
            .limit(3)
            .all()
        )
        if not rows:
            continue
        recommended_products.append({
            "category": cat,
            "items": [
                {
                    "id": p.id,
                    "name": p.name,
                    "price": p.price,
                    "unit": p.unit,
                    "image": p.image,
                    "sales_count": p.sales_count,
                }
                for p in rows
            ],
        })

    return {
        "surface_area_netto": round(s_netto, 2),
        "materials": materials,
        "message": "Расчет носит ознакомительный характер. Точные значения зависят от бренда и кривизны стен.",
        "recommended_products_title": "Мы нашли подходящие товары в нашем магазине:",
        "recommended_products": recommended_products,
        "whatsapp_cta": "Отправить смету мне в WhatsApp",
        "upsell_tip": "А вы знали, что декоративная краска 'Песок' обойдется всего на 20% дороже, но прослужит в 3 раза дольше?",
    }


# -----------------------------------------------------------------------------
# Уведомления для мастеров (акции, баллы)
# -----------------------------------------------------------------------------

@app.get("/notifications", response_model=List[NotificationResponse])
def list_notifications(
    limit: int = Query(50, ge=1, le=100),
    unread_only: bool = False,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """Список уведомлений текущего мастера (новые первыми)."""
    q = db.query(MasterNotificationDB).filter(MasterNotificationDB.master_id == master.id)
    if unread_only:
        q = q.filter(MasterNotificationDB.read_at.is_(None))
    rows = q.order_by(MasterNotificationDB.id.desc()).limit(limit).all()
    out = []
    for r in rows:
        payload = _parse_json_field(r.payload_json, {})
        out.append(NotificationResponse(
            id=r.id, master_id=r.master_id, type=r.type, title=r.title, body=r.body or "",
            payload=payload, created_at=r.created_at, read_at=r.read_at,
        ))
    return out


@app.patch("/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """Отметить уведомление как прочитанное."""
    from datetime import datetime
    row = db.query(MasterNotificationDB).filter(
        MasterNotificationDB.id == notification_id,
        MasterNotificationDB.master_id == master.id,
    ).first()
    if not row:
        raise HTTPException(status_code=404, detail="Notification not found")
    row.read_at = datetime.now().strftime("%Y-%m-%d %H:%M")
    db.commit()
    return {"status": "success"}


@app.get("/notifications/unread_count")
def unread_notifications_count(
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """Количество непрочитанных уведомлений (для бейджа в приложении)."""
    count = db.query(MasterNotificationDB).filter(
        MasterNotificationDB.master_id == master.id,
        MasterNotificationDB.read_at.is_(None),
    ).count()
    return {"count": count}


class DeviceTokenRegister(BaseModel):
    token: str
    platform: Optional[str] = "android"


@app.post("/notifications/register_token")
def register_device_token(
    payload: DeviceTokenRegister,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """
    Регистрирует или обновляет FCM-токен устройства для текущего мастера.

    Вызывается из мобильного приложения после получения FCM token:
    - token: строка токена Firebase
    - platform: "android" / "ios" (по желанию)
    """
    token = (payload.token or "").strip()
    if not token:
        raise HTTPException(status_code=400, detail="token required")

    now = int(time.time())
    row = db.query(DeviceTokenDB).filter(DeviceTokenDB.token == token).first()
    if row:
        row.master_id = master.id
        row.platform = payload.platform or row.platform
        row.is_active = 1
        row.updated_at = now
    else:
        row = DeviceTokenDB(
            master_id=master.id,
            token=token,
            platform=payload.platform or "android",
            created_at=now,
            updated_at=now,
            is_active=1,
        )
        db.add(row)
    db.commit()
    return {"status": "success"}


# -----------------------------------------------------------------------------
# API заказов (история — по токену; создание — публичное)
# -----------------------------------------------------------------------------

def _normalize_order_items(items_raw: list) -> list:
    """Приводит элементы заказа из БД (id, qty, ...) к формату OrderItem (product_id, name, qty, price)."""
    out = []
    for it in items_raw:
        if not isinstance(it, dict):
            continue
        product_id = it.get("product_id") or it.get("id")
        if product_id is None:
            continue
        out.append({
            "product_id": int(product_id) if not isinstance(product_id, int) else product_id,
            "name": it.get("name") or "",
            "qty": float(it.get("qty", 1)),
            "price": float(it.get("price", 0)),
        })
    return out


@app.get("/orders/history", response_model=List[OrderResponse])
def get_orders_history(master: MasterDB = Depends(get_master_for_orders_history), db: Session = Depends(get_db)):
    """История заказов: клиент или мастер по Bearer-токену."""
    phone_norm = getattr(master, "phone_norm", None) or normalize_phone(getattr(master, "phone", None) or "")
    is_client = getattr(master, "is_client", False) or getattr(master, "role", None) == "client"
    if is_client:
        orders = db.query(OrderDB).filter(
            OrderDB.client_phone_norm == phone_norm
        ).order_by(OrderDB.id.desc()).all()
    else:
        orders = db.query(OrderDB).filter(
            or_(OrderDB.client_phone_norm == phone_norm, OrderDB.master_id == master.id)
        ).order_by(OrderDB.id.desc()).all()
    return [
        OrderResponse(
            id=o.id, status=o.status, created_at=o.created_at,
            client_name=o.client_name, client_phone=o.client_phone,
            client_address=o.client_address, total_price=o.total_price,
            items=_normalize_order_items(_parse_json_field(o.items_json, [])),
            payment_type=getattr(o, "payment_type", None) or "cash",
        )
        for o in orders
    ]


@app.post("/orders", response_model=OrderResponse)
def create_order_api(order: OrderCreate, db: Session = Depends(get_db)):
    """Создание заказа из мобильного приложения; уведомление в Telegram."""
    items_data = [item.dict() for item in order.items]
    items_str = json.dumps(items_data, ensure_ascii=False)
    db_order = OrderDB(
        client_name=order.client_name, 
        client_phone=order.client_phone, 
        client_phone_norm=_order_phone_norm(order.client_phone),
        client_address=order.client_address, 
        total_price=order.total_price, 
        items_json=items_str, 
        payment_type=(order.payment_type or "cash").strip().lower() if order.payment_type else "cash",
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M"), 
        status="new",
    )
    db.add(db_order)
    db.commit()
    db.refresh(db_order)
    notify_new_order(
        db_order.id, order.client_name, order.client_phone, order.total_price, len(order.items),
        payment_type=order.payment_type, client_address=order.client_address,
    )
    payload = order.model_dump() if hasattr(order, "model_dump") else order.dict()
    payload["id"] = db_order.id
    payload["status"] = db_order.status
    payload["created_at"] = db_order.created_at
    payload["payment_type"] = db_order.payment_type or payload.get("payment_type") or "cash"
    return OrderResponse(**payload)
# -----------------------------------------------------------------------------
# Чат-бот API (корзина по session_id, поиск товаров, оформление заказа)
# -----------------------------------------------------------------------------

@app.post("/chat/session")
@_apply_rate_limit("30/minute")
def create_chat_session(request: Request, db: Session = Depends(get_db)):
    sid = str(uuid.uuid4())
    db.add(ChatSessionDB(session_id=sid, created_at=int(time.time()))); db.commit()
    return {"session_id": sid}

def build_chat_response(session: ChatSessionDB):
    cart = json.loads(session.cart_json)
    pending = json.loads(session.pending_items_json)
    if pending:
        task = pending[0]
        if not task['options']:
            return {"type": "pick", "prompt": f"⚠️ Товар '{task['query']}' не найден.", "item_index": task['item_index'], "options": []}
        return {"type": "pick", "prompt": f"Уточните '{task['query']}':", "item_index": task['item_index'], "options": task['options']}
    return {"type": "invoice", "draft": {"items": cart, "total_price": sum(i['line_total'] for i in cart), "currency": "TJS"}}

def generate_product_variants(candidates):
    options = []
    for c, s in candidates:
        has_sizes = c.get('sizes') and len(c['sizes']) > 0
        has_colors = c.get('colors') and len(c['colors']) > 0
        if has_sizes and has_colors:
            for size in c['sizes']:
                for color in c['colors']:
                    unique_btn_id = int(f"{c['id']}{random.randint(1000, 9999)}")
                    options.append({"id": unique_btn_id, "real_id": c["id"], "name": f"{c['name']} {size['name']} {color['name']}", "label": f"{c['name']} {size['name']} ({color['name']}) - {size['price']}с", "price": size['price'], "unit": c["unit"], "image": c["image"], "score": s})
        elif has_sizes:
            for size in c['sizes']:
                unique_btn_id = int(f"{c['id']}{random.randint(1000, 9999)}")
                options.append({"id": unique_btn_id, "real_id": c["id"], "name": f"{c['name']} {size['name']}", "label": f"{c['name']} {size['name']} ({size['price']}с)", "price": size['price'], "unit": c["unit"], "image": c["image"], "score": s})
        elif has_colors:
            for color in c['colors']:
                unique_btn_id = int(f"{c['id']}{random.randint(1000, 9999)}")
                options.append({"id": unique_btn_id, "real_id": c["id"], "name": f"{c['name']} {color['name']}", "label": f"{c['name']} ({color['name']}) - {c['price']}с", "price": c["price"], "unit": c["unit"], "image": c["image"], "score": s})
        else:
            options.append({"id": c["id"], "real_id": c["id"], "name": c["name"], "label": f"{c['name']} ({c['price']}с)", "price": c["price"], "unit": c["unit"], "image": c["image"], "score": s})
    return options

@app.post("/chat/message")
@_apply_rate_limit("30/minute")
def chat_message(request: Request, msg: ChatMessage, db: Session = Depends(get_db)):
    session = db.query(ChatSessionDB).filter(ChatSessionDB.session_id == msg.session_id).first()
    if not session: raise HTTPException(404, "Session not found")
    session.pending_items_json = "[]"
    parsed_items = TextParser.parse_text_bulk(msg.text)
    cart = json.loads(session.cart_json)
    pending = []
    for item in parsed_items:
        candidates = SearchEngine.search(item["name_query"])
        if not candidates:
            pending.append({"item_index": item["item_index"], "query": item["name_query"], "qty": item["qty"], "unit": item["unit"], "options": []})
            continue
        best_cand, best_score = candidates[0]
        has_variants = bool(best_cand.get('sizes')) or bool(best_cand.get('colors'))
        is_safe_match = False
        if best_score >= THRESHOLD_AUTO and not has_variants:
            if len(candidates) == 1: is_safe_match = True
            elif len(candidates) > 1:
                if (best_score - candidates[1][1]) >= THRESHOLD_GAP: is_safe_match = True
        if is_safe_match:
            cart.append({"product_id": best_cand["id"], "name": best_cand["name"], "qty": item['qty'], "unit": best_cand["unit"], "price": best_cand["price"], "line_total": best_cand["price"] * item['qty'], "image": best_cand["image"]})
        else:
            options = generate_product_variants(candidates)
            pending.append({"item_index": item["item_index"], "query": item["name_query"], "qty": item["qty"], "unit": item["unit"], "options": options})
    session.cart_json = json.dumps(cart); session.pending_items_json = json.dumps(pending); db.commit()
    return build_chat_response(session)

@app.post("/chat/pick")
@_apply_rate_limit("30/minute")
def chat_pick(request: Request, pick: ChatPick, db: Session = Depends(get_db)):
    session = db.query(ChatSessionDB).filter(ChatSessionDB.session_id == pick.session_id).first()
    cart = json.loads(session.cart_json); pending = json.loads(session.pending_items_json)
    if not pending: return build_chat_response(session)
    task_index = -1; task = None
    for i, t in enumerate(pending):
        if t.get("item_index") == pick.item_index: task = t; task_index = i; break
    if task:
        pending.pop(task_index)
        selected = next((o for o in task['options'] if o['id'] == pick.product_id), None)
        if selected:
            cart.append({"product_id": selected.get("real_id", selected["id"]), "name": selected["name"], "qty": task['qty'], "unit": selected["unit"], "price": selected["price"], "line_total": selected["price"] * task['qty'], "image": selected["image"]})
    else:
        if pending: pending.pop(0)
    session.cart_json = json.dumps(cart); session.pending_items_json = json.dumps(pending); db.commit()
    return build_chat_response(session)
@app.post("/chat/action")
@_apply_rate_limit("30/minute")
def chat_action(request: Request, action: ChatAction, db: Session = Depends(get_db)):
    session = db.query(ChatSessionDB).filter(ChatSessionDB.session_id == action.session_id).first()
    if not session: raise HTTPException(404, "Session not found")
    cart = json.loads(session.cart_json); pending = json.loads(session.pending_items_json) if session.pending_items_json else []
    if action.action == "reset": cart = []; pending = []
    elif action.action == "delete_item":
        idx = action.payload.get("item_index")
        if idx is not None and 0 <= idx < len(cart): cart.pop(idx)
    elif action.action == "edit_qty":
        idx = action.payload.get("item_index"); new_qty = float(action.payload.get("qty", 1))
        if idx is not None and 0 <= idx < len(cart): cart[idx]['qty'] = new_qty; cart[idx]['line_total'] = cart[idx]['price'] * new_qty
    elif action.action == "add_more":
        text = (action.payload.get("text") or "").strip()
        if text:
            parsed = TextParser.parse_line(text)
            if parsed and parsed.get("name_query"):
                candidates = SearchEngine.search(parsed["name_query"])
                if not candidates: pending.append({"item_index": 999, "query": parsed["name_query"], "qty": parsed["qty"], "unit": parsed["unit"], "options": []})
                else:
                    best_cand, best_score = candidates[0]
                    has_variants = bool(best_cand.get('sizes')) or bool(best_cand.get('colors'))
                    is_safe_match = False
                    if best_score >= THRESHOLD_AUTO and not has_variants:
                        if len(candidates) == 1: is_safe_match = True
                        elif len(candidates) > 1:
                            if (best_score - candidates[1][1]) >= THRESHOLD_GAP: is_safe_match = True
                    if is_safe_match:
                        cart.append({"product_id": best_cand["id"], "name": best_cand["name"], "qty": parsed['qty'], "unit": best_cand["unit"], "price": best_cand["price"], "line_total": best_cand["price"] * parsed['qty'], "image": best_cand["image"]})
                    else:
                        options = generate_product_variants(candidates)
                        pending.append({"item_index": 999, "query": parsed["name_query"], "qty": parsed["qty"], "unit": parsed["unit"], "options": options})
    session.cart_json = json.dumps(cart); session.pending_items_json = json.dumps(pending); db.commit()
    return build_chat_response(session)

@app.post("/chat/submit")
@_apply_rate_limit("30/minute")
def chat_submit(
    request: Request,
    submit: ChatSubmit,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
):
    session = db.query(ChatSessionDB).filter(ChatSessionDB.session_id == submit.session_id).first()
    if not session: raise HTTPException(404, "Session not found")
    try: cart = json.loads(session.cart_json); pending = json.loads(session.pending_items_json)
    except: cart = []; pending = []
    print(f"🛒 Заказ: Корзина={len(cart)}, Ожидание={len(pending)}")
    if not cart: 
        if pending: return {"error": "⚠️ У вас есть невыбранные товары!"}
        else: return {"error": "❌ Корзина пуста."}
    items_save = [{"id": i['product_id'], "name": i['name'], "qty": i['qty'], "price": i['price'], "image": i.get('image', "")} for i in cart]
    total = sum(i['line_total'] for i in cart)
    db_order = OrderDB(
        client_name=submit.client_name,
        client_phone=submit.client_phone,
        client_phone_norm=normalize_phone(submit.client_phone),
        client_address=submit.client_address,
        total_price=total,
        items_json=json.dumps(items_save, ensure_ascii=False),
        payment_type=submit.payment_type or "cash",
        comment=submit.comment,
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
        status="new",
    )
    db.add(db_order); session.cart_json = "[]"; session.pending_items_json = "[]"; db.commit()
    db.refresh(db_order)
    print(f"✅ Заказ #{db_order.id} создан!")
    background_tasks.add_task(
        notify_new_order,
        db_order.id,
        submit.client_name,
        submit.client_phone,
        total,
        len(cart),
        payment_type=submit.payment_type,
        client_address=submit.client_address,
        comment=submit.comment,
    )
    return {"status": "success", "order_id": db_order.id}

# -----------------------------------------------------------------------------
# Telegram webhook: обработка нажатий кнопок (смена статуса заказа)
# -----------------------------------------------------------------------------

STATUS_LABELS = {"new": "🆕 Новый", "processing": "⚙️ В работе", "completed": "✅ Выполнен", "canceled": "❌ Отменён"}


def _apk_url_to_download_page(apk_url: str) -> str:
    """
    Превращает прямую ссылку на .apk в красивую страницу скачивания.
    Страница: /web/download.html?apk=<оригинальная_apk_url>
    """
    try:
        parsed = urllib.parse.urlparse(apk_url)
        base = f"{parsed.scheme}://{parsed.netloc}"
        qs = urllib.parse.urlencode({"apk": apk_url})
        return f"{base}/download.html?{qs}"
    except Exception:
        return apk_url


@app.post("/telegram/webhook")
async def telegram_webhook(request: Request, db: Session = Depends(get_db)):
    """
    Принимает update от Telegram. При нажатии кнопки под заказом (callback_data: order:ID:STATUS)
    обновляет статус заказа в БД и редактирует сообщение в чате.
    В Telegram нужно зарегистрировать webhook: https://api.telegram.org/bot<TOKEN>/setWebhook?url=https://ВАШ_ДОМЕН/telegram/webhook
    """
    try:
        body = await request.json()
    except Exception:
        return {"ok": True}

    # Команда /start — приветствие и кнопки (канал, соцсети, APK, магазин)
    msg = body.get("message")
    if msg:
        text = (msg.get("text") or "").strip()
        chat_id = msg.get("chat", {}).get("id")
        if text == "/start" and chat_id:
            row = db.query(SiteSettingsDB).filter(SiteSettingsDB.id == 1).first()
            if not row:
                row = SiteSettingsDB(id=1)
                db.add(row)
                db.commit()
                db.refresh(row)
            buttons = []
            if row.telegram_channel_url:
                buttons.append([{"text": "📢 Канал Telegram", "url": row.telegram_channel_url}])
            if row.whatsapp_group_url:
                buttons.append([{"text": "💬 WhatsApp", "url": row.whatsapp_group_url}])
            if row.instagram_url:
                buttons.append([{"text": "📷 Instagram", "url": row.instagram_url}])
            if row.tiktok_url:
                buttons.append([{"text": "🎵 TikTok", "url": row.tiktok_url}])
            if row.apk_url:
                buttons.append([{"text": "📲 Скачать приложение", "url": _apk_url_to_download_page(row.apk_url)}])
            if row.shop_url:
                buttons.append([{"text": "🛒 Открыть магазин", "url": row.shop_url}])
            welcome = (
                "Салом! 👋\n"
                "Ба боти «Ustobozor» хуш омадед!\n\n"
                "Магозаи Ustobozor хама намуди махсулотхои сохтмони бо нархи дастрас\n\n"
                "🧱 Масолеҳи сохтмонӣ бо нархи дастрас\n"
                "📲 Барои фармоиш ва тамос — тугмаҳоро истифода баред\n\n"
                "📋 Тугмаҳо\n\n"
                "📱 Instagram\n"
                "💬 Гурӯҳи Telegram\n"
                "📲 Гурӯҳи WhatsApp\n"
                "📥 Боргирии барнома\n\n"
                "Барномаи моро зеркашӣ кунед ва фармоишро осон анҷом диҳед! 🚀"
            )
            reply_markup = {"inline_keyboard": buttons} if buttons else None
            _send_to_chat(str(chat_id), welcome, reply_markup)
        return {"ok": True}

    callback = body.get("callback_query")
    if not callback:
        return {"ok": True}
    cq_id = callback.get("id")
    data = (callback.get("data") or "").strip()
    message = callback.get("message") or {}
    chat_id = message.get("chat", {}).get("id")
    message_id = message.get("message_id")
    if not data.startswith("order:") or not cq_id:
        answer_callback_query(cq_id, "Неизвестная команда")
        return {"ok": True}
    parts = data.split(":")
    if len(parts) != 3:
        answer_callback_query(cq_id, "Ошибка формата")
        return {"ok": True}
    try:
        order_id = int(parts[1])
        new_status = parts[2].strip().lower()
    except (ValueError, IndexError):
        answer_callback_query(cq_id, "Ошибка")
        return {"ok": True}
    if new_status not in ("new", "processing", "completed", "canceled"):
        answer_callback_query(cq_id, "Неверный статус")
        return {"ok": True}
    ok = apply_order_status_change(db, order_id, new_status)
    label = STATUS_LABELS.get(new_status, new_status)
    answer_callback_query(cq_id, f"Статус: {label}")
    if chat_id and message_id:
        old_text = (message.get("text") or "").strip()
        new_text = old_text + f"\n\n✅ <b>Статус изменён:</b> {label}"
        edit_message_text(chat_id, message_id, new_text)
        edit_message_reply_markup(chat_id, message_id, {"inline_keyboard": []})
    return {"ok": True}


@app.get("/telegram/set_webhook")
def telegram_set_webhook(url: str = Query(..., description="Полный URL вашего webhook (HTTPS)")):
    """
    Регистрирует webhook в Telegram. Вызовите один раз в браузере:
    /telegram/set_webhook?url=https://ВАШ_ДОМЕН/telegram/webhook
    """
    import urllib.request
    try:
        from config import TELEGRAM_BOT_TOKEN
    except ImportError:
        TELEGRAM_BOT_TOKEN = ""
    if not TELEGRAM_BOT_TOKEN:
        return {"ok": False, "error": "TELEGRAM_BOT_TOKEN не задан"}
    api_url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/setWebhook?url={url}"
    try:
        with urllib.request.urlopen(api_url, timeout=10) as r:
            result = json.loads(r.read().decode())
            return result
    except Exception as e:
        return {"ok": False, "error": str(e)}


@app.on_event("startup")
def startup_event():
    """При старте: кеш поиска + фоновая очистка OTP (in-memory)."""
    from services.otp_cleanup import start_otp_cleanup_background

    start_otp_cleanup_background()
    db = SessionLocal()
    try:
        refresh_products_cache(db)
        print(f"✅ Загружено {len(PRODUCTS_CACHE)} товаров в кеш поиска.")
    finally:
        db.close()


# -----------------------------------------------------------------------------
# PWA на корне домена (после всех API — иначе перехватит /products и т.д.)
# -----------------------------------------------------------------------------

@app.get("/web", include_in_schema=False)
@app.get("/web/", include_in_schema=False)
def legacy_web_redirect():
    """Старые ссылки /web/ → главная."""
    return RedirectResponse(url="/", status_code=301)


app.mount("/", StaticFiles(directory=_WEB_DIR, html=True), name="pwa_root")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)