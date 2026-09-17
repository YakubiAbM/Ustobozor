"""
Роуты админ-панели: дашборд, товары, мастера, заказы, касса (баллы).
Все эндпоинты защищены require_admin (JWT/cookie с role=admin).
"""

import io
import json
import math
import os
import shutil
import uuid
from datetime import datetime
from typing import List

import barcode
from barcode.writer import ImageWriter
from fastapi import APIRouter, Body, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import or_
from sqlalchemy.orm import Session

from database import AdminDB, DeviceTokenDB, MasterDB, MasterNotificationDB, OrderDB, ProductDB, ProductStockDB, RefreshTokenDB, TransactionDB, SiteSettingsDB, get_db
from search_engine import refresh_products_cache, SearchEngine
from auth import (
    ADMIN_SCOPES,
    create_access_token,
    get_admin_permissions,
    get_first_admin_page_url,
    hash_pin,
    normalize_phone,
    require_admin,
    require_admin_permission,
    require_superadmin,
)
from auth import SUPERADMIN_SESSION_COOKIE, _is_superadmin_by_phone
from notifications import create_notification, create_promo_for_all
from order_actions import apply_order_status_change
from image_utils import save_upload_as_webp
from config import MASTER_POINTS_ENABLED

try:
    import pandas as pd
except ImportError:
    pd = None

router = APIRouter()

# HTML-шаблоны Jinja удалены — старые URL редиректим в SPA.
_SPA_PAGES = {
    "dashboard.html": "/admin#dashboard",
    "products.html": "/admin#products",
    "add_product.html": "/admin#products",
    "edit_product.html": "/admin#products",
    "masters.html": "/admin#masters",
    "add_master.html": "/admin#masters",
    "edit_master.html": "/admin#masters",
    "master_detail.html": "/admin#masters",
    "orders.html": "/admin#orders",
    "invoice.html": "/admin#orders",
    "cashier.html": "/admin#cashier",
    "debtors.html": "/admin#cashier",
    "admins.html": "/admin#admins",
    "edit_admin.html": "/admin#admins",
    "settings_social.html": "/admin",
    "403.html": "/admin/login",
    "admin_login.html": "/admin/login",
}


class _SpaTemplates:
    def TemplateResponse(self, request, name, context=None, status_code=200):
        return RedirectResponse(url=_SPA_PAGES.get(name, "/admin"), status_code=302)


templates = _SpaTemplates()
os.makedirs("static/barcodes", exist_ok=True)


def _admin_ctx(user):  # user: MasterDB (legacy) или AdminDB
    """Контекст для сайдбара: права и флаг супер-админа."""
    is_super = bool(getattr(user, "is_superadmin", 0)) or _is_superadmin_by_phone(user)
    return {
        "admin_permissions": get_admin_permissions(user),
        "is_superadmin": is_super,
    }


def _reset_master_password_db(db: Session, master_id: int) -> MasterDB:
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master:
        raise HTTPException(status_code=404, detail="Master not found")
    master.password_hash = None
    master.is_password_reset = 1
    db.commit()
    db.refresh(master)
    return master


def generate_barcode_image(master_id: int) -> str:
    """Генерирует изображение штрих-кода Code128 по ID мастера. Возвращает путь к файлу или \"\"."""
    try:
        code_content = str(master_id)
        if not code_content:
            return ""
        BarcodeClass = barcode.get_barcode_class("code128")
        barcode_obj = BarcodeClass(code_content, writer=ImageWriter())
        path = f"static/barcodes/barcode_id_{master_id}"
        barcode_obj.save(path)
        return f"{path}.png"
    except Exception as e:
        print(f"Ошибка генерации штрих-кода: {e}")
        return ""


# -----------------------------------------------------------------------------
# Установка PIN при первом входе в админку (после проверки по коду)
# -----------------------------------------------------------------------------

@router.post("/admin/set_pin")
async def admin_set_pin(
    request: Request,
    user = Depends(require_admin),
    db: Session = Depends(get_db),
):
    """Сохранить 4-значный PIN (для админов из таблицы admins при смене PIN через API)."""
    try:
        body = await request.json()
    except Exception:
        body = {}
    pin = str((body.get("pin") or "")).strip()
    if len(pin) != 4 or not pin.isdigit():
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="PIN должен быть 4 цифры")
    user.pin_hash = hash_pin(pin)
    db.commit()
    phone_norm = getattr(user, "phone_norm", None) or normalize_phone(getattr(user, "phone", None) or "")
    if getattr(user, "__tablename__", None) == "admins":
        token = create_access_token(phone_norm=phone_norm, admin_id=user.id)
    else:
        token = create_access_token(master_id=user.id, phone_norm=phone_norm, role=getattr(user, "role", None) or "admin")
    return {"status": "success", "access_token": token, "redirect": "/admin"}  # GET /admin редиректнет на первый доступный раздел


# -----------------------------------------------------------------------------
# Выход из админки
# -----------------------------------------------------------------------------

@router.get("/admin/logout")
def admin_logout():
    """Очистить cookie и перенаправить на страницу входа."""
    response = RedirectResponse(url="/admin/login", status_code=302)
    response.delete_cookie(SUPERADMIN_SESSION_COOKIE, path="/")
    response.delete_cookie("access_token", path="/")
    return response


# -----------------------------------------------------------------------------
# Управление админами (только супер-админ)
# -----------------------------------------------------------------------------

@router.get("/admin/admins")
def admin_admins_page(request: Request, db: Session = Depends(get_db), _user = Depends(require_superadmin)):
    """Страница: список админов из таблицы admins, форма добавления."""
    admins = db.query(AdminDB).order_by(AdminDB.id).all()
    admin_list = []
    for a in admins:
        perms = get_admin_permissions(a)
        admin_list.append({
            "id": a.id,
            "name": a.name or "—",
            "phone": a.phone or "—",
            "is_superadmin": bool(a.is_superadmin),
            "permissions": perms,
        })
    return templates.TemplateResponse(request, "admins.html", {
        "request": request,
        "page": "admins",
        "admin_list": admin_list,
        "scopes": ADMIN_SCOPES,
        "scope_labels": {
            "dashboard": "Дашборд",
            "orders": "Заказы",
            "products": "Товары",
            "masters": "Мастера",
            "cashier": "Касса",
        },
        **_admin_ctx(_user),
    })


@router.post("/admin/admins/add")
async def admin_add_admin(
    request: Request,
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
    name: str = Form(""),
    phone: str = Form(...),
    pin: str = Form(...),
    permissions: List[str] = Form([]),
):
    """Добавить админа в таблицу admins: имя, телефон, 4-значный PIN, список разрешений."""
    name_clean = (name or "").strip()
    phone_clean = (phone or "").strip()
    pin_clean = "".join(filter(str.isdigit, (pin or "")))
    if len(phone_clean) < 9:
        raise HTTPException(status_code=400, detail="Укажите корректный номер телефона")
    if len(pin_clean) != 4:
        raise HTTPException(status_code=400, detail="PIN должен быть 4 цифры")
    phone_norm = normalize_phone(phone_clean)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Не удалось нормализовать номер")
    display_name = name_clean if name_clean else f"Админ {phone_norm[-4:]}"
    allowed = [s for s in permissions if s in ADMIN_SCOPES]
    admin = db.query(AdminDB).filter(AdminDB.phone_norm == phone_norm).first()
    if admin:
        admin.name = display_name
        admin.phone = phone_clean
        admin.pin_hash = hash_pin(pin_clean)
        admin.is_superadmin = 0
        admin.admin_permissions = json.dumps(allowed, ensure_ascii=False)
        db.commit()
    else:
        new_admin = AdminDB(
            name=display_name,
            phone=phone_clean,
            phone_norm=phone_norm,
            pin_hash=hash_pin(pin_clean),
            is_superadmin=0,
            admin_permissions=json.dumps(allowed, ensure_ascii=False),
        )
        db.add(new_admin)
        db.commit()
    return RedirectResponse(url="/admin/admins", status_code=303)


@router.post("/admin/admins/remove")
async def admin_remove_admin(
    request: Request,
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
    admin_id: int = Form(...),
):
    """Удалить админа из таблицы admins. Супер-админа удалить нельзя."""
    admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
    if not admin:
        return RedirectResponse(url="/admin/admins", status_code=303)
    if admin.is_superadmin:
        return RedirectResponse(url="/admin/admins", status_code=303)
    db.delete(admin)
    db.commit()
    return RedirectResponse(url="/admin/admins", status_code=303)


@router.get("/admin/admins/edit/{admin_id}")
def admin_edit_admin_page(
    admin_id: int,
    request: Request,
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
):
    """Страница редактирования админа (имя, телефон, PIN, доступы)."""
    admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
    if not admin:
        return RedirectResponse(url="/admin/admins", status_code=303)
    if admin.is_superadmin:
        return RedirectResponse(url="/admin/admins", status_code=303)
    try:
        perms = json.loads(admin.admin_permissions or "[]")
    except Exception:
        perms = []
    return templates.TemplateResponse(request, "edit_admin.html", {
        "request": request,
        "page": "admins",
        "a": admin,
        "current_permissions": perms,
        "scopes": ADMIN_SCOPES,
        "scope_labels": {
            "dashboard": "Дашборд",
            "orders": "Заказы",
            "products": "Товары",
            "masters": "Мастера",
            "cashier": "Касса",
        },
        **_admin_ctx(_user),
    })


@router.post("/admin/admins/edit/{admin_id}")
async def admin_edit_admin_save(
    admin_id: int,
    request: Request,
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
    name: str = Form(""),
    phone: str = Form(...),
    pin: str = Form(""),
    permissions: List[str] = Form([]),
):
    """Сохранить изменения админа в таблице admins. PIN меняется только если введены 4 цифры."""
    admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
    if not admin or admin.is_superadmin:
        return RedirectResponse(url="/admin/admins", status_code=303)
    name_clean = (name or "").strip()
    phone_clean = (phone or "").strip()
    phone_norm = normalize_phone(phone_clean)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Укажите корректный номер телефона")
    pin_clean = "".join(filter(str.isdigit, (pin or "")))
    admin.name = name_clean if name_clean else admin.name
    admin.phone = phone_clean
    admin.phone_norm = phone_norm
    if len(pin_clean) == 4:
        admin.pin_hash = hash_pin(pin_clean)
    allowed = [s for s in permissions if s in ADMIN_SCOPES]
    admin.admin_permissions = json.dumps(allowed, ensure_ascii=False)
    db.commit()
    return RedirectResponse(url="/admin/admins", status_code=303)


# -----------------------------------------------------------------------------
# Настройки: ссылки для Telegram-бота (канал, соцсети, APK, магазин)
# -----------------------------------------------------------------------------

@router.get("/admin/settings/social")
def admin_settings_social_page(
    request: Request,
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
):
    """Страница редактирования ссылок для бота (канал, WhatsApp, соцсети, APK, магазин)."""
    row = db.query(SiteSettingsDB).filter(SiteSettingsDB.id == 1).first()
    if not row:
        row = SiteSettingsDB(id=1)
        db.add(row)
        db.commit()
        db.refresh(row)
    return templates.TemplateResponse(request, "settings_social.html", {
        "request": request,
        "page": "settings_social",
        "settings": row,
        **_admin_ctx(_user),
    })


@router.post("/admin/settings/social")
def admin_settings_social_save(
    db: Session = Depends(get_db),
    _user = Depends(require_superadmin),
    telegram_channel_url: str = Form(""),
    whatsapp_group_url: str = Form(""),
    instagram_url: str = Form(""),
    tiktok_url: str = Form(""),
    apk_url: str = Form(""),
    shop_url: str = Form(""),
):
    """Сохранить ссылки для бота."""
    row = db.query(SiteSettingsDB).filter(SiteSettingsDB.id == 1).first()
    if not row:
        row = SiteSettingsDB(id=1)
        db.add(row)
    row.telegram_channel_url = (telegram_channel_url or "").strip()
    row.whatsapp_group_url = (whatsapp_group_url or "").strip()
    row.instagram_url = (instagram_url or "").strip()
    row.tiktok_url = (tiktok_url or "").strip()
    row.apk_url = (apk_url or "").strip()
    row.shop_url = (shop_url or "").strip()
    db.commit()
    return RedirectResponse(url="/admin/settings/social", status_code=303)


# -----------------------------------------------------------------------------
# Вход в админку: GET /admin → редирект на первый доступный раздел
# -----------------------------------------------------------------------------

@router.get("/admin")
def admin_index_redirect():
    """SPA админка (static/admin). Авторизация через /admin/api/*."""
    from fastapi.responses import FileResponse
    import os

    path = os.path.join(os.path.dirname(__file__), "static", "admin", "index.html")
    return FileResponse(path, media_type="text/html; charset=utf-8")


# -----------------------------------------------------------------------------
# Дашборд (/admin/dashboard) — редирект в SPA
# -----------------------------------------------------------------------------

@router.get("/admin/dashboard")
def admin_dashboard(_user: MasterDB = Depends(require_admin_permission("dashboard"))):
    return RedirectResponse(url="/admin#dashboard", status_code=302)


# --- ТОВАРЫ ---
def _search_like(term: str):
    """Экранирование % и _ для безопасного LIKE/ILIKE."""
    if not term:
        return ""
    t = term.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_")
    return f"%{t}%"


@router.get("/admin/products")
def admin_products(
    request: Request, 
    page: int = 1, 
    category: str = None, 
    search: str = None,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("products")),
):
    limit = 50
    offset = (page - 1) * limit
    search = (search or "").strip() or None

    if search:
        cat_filter = category if category and category != "All" else None
        api_hits = SearchEngine.search_api(search, cat_filter, limit=2000, offset=0)
        total_items = len(api_hits)
        page_hits = api_hits[offset: offset + limit]
        ids = [int(h["id"]) for h in page_hits if h.get("id")]
        if ids:
            rows = db.query(ProductDB).filter(ProductDB.id.in_(ids)).all()
            order_map = {pid: i for i, pid in enumerate(ids)}
            products = sorted(rows, key=lambda p: order_map.get(p.id, 9999))
        else:
            products = []
        total_pages = max(1, math.ceil(total_items / limit))
    else:
        query = db.query(ProductDB)

        if category and category != "All":
            query = query.filter(ProductDB.category == category)

        total_items = query.count()
        total_pages = max(1, math.ceil(total_items / limit))
        products = query.order_by(ProductDB.id.desc()).offset(offset).limit(limit).all()

    product_ids = [p.id for p in products]
    stock_map = {}
    if product_ids:
        rows = db.query(ProductStockDB).filter(ProductStockDB.product_id.in_(product_ids)).all()
        stock_map = {r.product_id: int(r.is_in_stock) for r in rows}
    for p in products:
        # По умолчанию считаем товар "в наличии", если явной записи нет
        p.is_in_stock = stock_map.get(p.id, 1)

    cats_query = db.query(ProductDB.category).distinct().all()
    all_categories = sorted([c[0] for c in cats_query if c[0]])

    return templates.TemplateResponse(request, "products.html", {
        "request": request, 
        "products": products, 
        "page": "products",
        "current_page": page,
        "total_pages": total_pages,
        "selected_category": category,
        "search_query": search or "",
        "all_categories": all_categories,
        **_admin_ctx(_user),
    })


@router.post("/admin/products/set_stock")
async def admin_set_product_stock(
    product_id: int = Form(...),
    in_stock: int = Form(...),
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("products")),
):
    product = db.query(ProductDB).filter(ProductDB.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Товар не найден")
    row = db.query(ProductStockDB).filter(ProductStockDB.product_id == product_id).first()
    if not row:
        row = ProductStockDB(product_id=product_id)
        db.add(row)
    row.is_in_stock = 1 if int(in_stock) == 1 else 0
    row.updated_at = int(datetime.now().timestamp())
    db.commit()
    return {"status": "ok", "product_id": product_id, "in_stock": row.is_in_stock}

@router.get("/admin/products/add")
def admin_products_add_page(request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("products"))):
    cats = db.query(ProductDB.category).distinct().all()
    subs = db.query(ProductDB.subcategory).distinct().all()
    subcategories = sorted([s[0] for s in subs if s[0] and str(s[0]).strip()])
    return templates.TemplateResponse(request, "add_product.html", {"request": request, "page": "products", "categories": [c[0] for c in cats if c[0]], "subcategories": subcategories, **_admin_ctx(_user)})

@router.post("/admin/add_product")
async def admin_save_product(
    name: str = Form(...), 
    price: float = Form(...), 
    brand: str = Form(""),
    category: str = Form(...), 
    new_category: str = Form(None),
    subcategory: str = Form(""), 
    new_subcategory: str = Form(None),
    articul: str = Form(""), 
    description: str = Form(""), 
    unit: str = Form("шт"),
    files: List[UploadFile] = File(None), 
    _user: MasterDB = Depends(require_admin_permission("products")), 
    sizes_names: List[str] = Form([]), 
    sizes_prices: List[float] = Form([]), 
    colors_names: List[str] = Form([]), 
    colors_values: List[str] = Form([]),
    db: Session = Depends(get_db)
):
    final_cat = new_category if new_category else category
    final_subcat = (new_subcategory or "").strip() if subcategory == "NEW" else (subcategory or "")
    saved_photos = []
    if files:
        for file in files:
            if file.filename:
                raw = await file.read()
                rel = save_upload_as_webp(raw)
                if not rel:
                    uid = f"{uuid.uuid4()}_{os.path.basename(file.filename)}"
                    path = os.path.join("static", "images", uid)
                    with open(path, "wb") as buffer:
                        buffer.write(raw)
                    rel = f"static/images/{uid}"
                saved_photos.append(rel)
    main_image = saved_photos[0] if saved_photos else ""
    sizes_list = [{"name": n, "price": p} for n, p in zip(sizes_names, sizes_prices) if n]
    colors_list = [{"name": n, "value": v} for n, v in zip(colors_names, colors_values) if n]
    
    new_product = ProductDB(
        name=name, 
        price=price, 
        brand=brand, # 🔥 СОХРАНЯЕМ БРЕНД
        category=final_cat, 
        subcategory=final_subcat, 
        description=description, 
        unit=unit, 
        articul=articul, 
        image=main_image, 
        photos_json=json.dumps(saved_photos), 
        sizes_json=json.dumps(sizes_list, ensure_ascii=False), 
        colors_json=json.dumps(colors_list, ensure_ascii=False)
    )
    db.add(new_product); db.commit()
    refresh_products_cache(db)
    return RedirectResponse(url="/admin/products", status_code=303)

@router.get("/admin/products/edit/{product_id}")
def admin_products_edit_page(product_id: int, request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("products"))):
    product = db.query(ProductDB).filter(ProductDB.id == product_id).first()
    if not product: return RedirectResponse(url="/admin/products")
    try: sizes = json.loads(product.sizes_json); photos = json.loads(product.photos_json); colors = json.loads(product.colors_json)
    except: sizes=[]; photos=[]; colors=[]
    cats = db.query(ProductDB.category).distinct().all()
    subs = db.query(ProductDB.subcategory).distinct().all()
    subcategories = sorted([s[0] for s in subs if s[0] and str(s[0]).strip()])
    return templates.TemplateResponse(request, "edit_product.html", {"request": request, "page": "products", "p": product, "sizes": sizes, "photos": photos, "colors": colors, "categories": [c[0] for c in cats if c[0]], "subcategories": subcategories, **_admin_ctx(_user)})

@router.post("/admin/edit_product/{product_id}")
async def admin_update_product(
    product_id: int, 
    _user: MasterDB = Depends(require_admin_permission("products")), 
    name: str = Form(...), 
    price: float = Form(...), 
    brand: str = Form(""), # 🔥 ДОБАВЛЕНО ПОЛЕ БРЕНД
    category: str = Form(...), 
    new_category: str = Form(None),
    subcategory: str = Form(""), 
    new_subcategory: str = Form(None),
    articul: str = Form(""), 
    description: str = Form(""), 
    unit: str = Form("шт"),
    files: List[UploadFile] = File(None), 
    sizes_names: List[str] = Form([]), 
    sizes_prices: List[float] = Form([]), 
    colors_names: List[str] = Form([]), 
    colors_values: List[str] = Form([]), 
    existing_photos: List[str] = Form([]),
    db: Session = Depends(get_db)
):
    product = db.query(ProductDB).filter(ProductDB.id == product_id).first()
    if not product: return RedirectResponse(url="/admin/products")
    final_cat = new_category if new_category else category
    final_subcat = (new_subcategory or "").strip() if subcategory == "NEW" else (subcategory or "")
    new_photos = []
    if files:
        for file in files:
            if file.filename:
                raw = await file.read()
                rel = save_upload_as_webp(raw)
                if not rel:
                    uid = f"{uuid.uuid4()}_{os.path.basename(file.filename)}"
                    path = os.path.join("static", "images", uid)
                    with open(path, "wb") as buffer:
                        buffer.write(raw)
                    rel = f"static/images/{uid}"
                new_photos.append(rel)
    all_photos = existing_photos + new_photos; main_image = all_photos[0] if all_photos else ""
    sizes_list = [{"name": n, "price": p} for n, p in zip(sizes_names, sizes_prices) if n]
    colors_list = [{"name": n, "value": v} for n, v in zip(colors_names, colors_values) if n]
    
    # Обновляем поля
    product.name = name
    product.price = price
    product.brand = brand # 🔥 ОБНОВЛЯЕМ БРЕНД
    product.category = final_cat
    product.subcategory = final_subcat
    product.articul = articul
    product.description = description
    product.unit = unit
    product.image = main_image
    product.photos_json = json.dumps(all_photos)
    product.sizes_json = json.dumps(sizes_list, ensure_ascii=False)
    product.colors_json = json.dumps(colors_list, ensure_ascii=False)
    
    db.commit()
    refresh_products_cache(db)
    return RedirectResponse(url="/admin/products", status_code=303)

@router.get("/admin/delete_product/{product_id}")
def admin_delete_product(product_id: int, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("products"))):
    db.query(ProductDB).filter(ProductDB.id == product_id).delete(); db.commit()
    refresh_products_cache(db) 
    return RedirectResponse(url="/admin/products", status_code=303)


@router.post("/admin/products/delete_bulk")
async def admin_delete_products_bulk(request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("products"))):
    """Удалить выбранные товары (чекбоксы на странице товаров)."""
    form = await request.form()
    raw = form.getlist("product_ids")
    ids = []
    for x in raw:
        try:
            ids.append(int(x))
        except (ValueError, TypeError):
            continue
    if ids:
        db.query(ProductDB).filter(ProductDB.id.in_(ids)).delete(synchronize_session=False)
        db.commit()
        refresh_products_cache(db)
    return RedirectResponse(url="/admin/products", status_code=303)


def _products_to_excel_buffer(products: List[ProductDB]) -> io.BytesIO:
    """Собрать товары в Excel (колонки как при импорте) и вернуть BytesIO."""
    if pd is None:
        raise HTTPException(status_code=503, detail="Установите pandas и openpyxl для экспорта в Excel")
    rows = []
    for p in products:
        rows.append({
            "ID": p.id,
            "Название": p.name or "",
            "Цена": float(p.price) if p.price is not None else 0,
            "Бренд": p.brand or "",
            "Категория": p.category or "",
            "Подкатегория": p.subcategory or "",
            "Описание": (p.description or "")[:500],
            "Ед": p.unit or "шт",
            "Артикул": p.articul or "",
        })
    if not rows:
        rows = [{"Название": "(нет товаров)", "Цена": 0, "Бренд": "", "Категория": "", "Описание": "", "Ед": "шт", "Артикул": ""}]
    df = pd.DataFrame(rows)
    buf = io.BytesIO()
    df.to_excel(buf, index=False, engine="openpyxl")
    buf.seek(0)
    return buf


@router.get("/admin/products/export")
def admin_products_export_all(
    category: str = None,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("products")),
):
    """Экспорт всех товаров в Excel (опционально по категории)."""
    query = db.query(ProductDB)
    if category and category != "All":
        query = query.filter(ProductDB.category == category)
    products = query.order_by(ProductDB.id).all()
    buf = _products_to_excel_buffer(products)
    filename = f"products_{datetime.now().strftime('%Y-%m-%d_%H-%M')}.xlsx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/admin/products/export")
async def admin_products_export_selected(
    request: Request,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("products")),
):
    """Экспорт выбранных товаров в Excel (если ничего не выбрано — экспорт всех)."""
    form = await request.form()
    raw = form.getlist("product_ids")
    ids = []
    for x in raw:
        try:
            ids.append(int(x))
        except (ValueError, TypeError):
            continue
    if ids:
        products = db.query(ProductDB).filter(ProductDB.id.in_(ids)).order_by(ProductDB.id).all()
    else:
        products = db.query(ProductDB).order_by(ProductDB.id).all()
    buf = _products_to_excel_buffer(products)
    filename = f"products_{datetime.now().strftime('%Y-%m-%d_%H-%M')}.xlsx"
    return StreamingResponse(
        buf,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )

@router.post("/admin/import_products")
async def import_products_excel(file: UploadFile = File(...), db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("products"))):
    if pd is None: return {"error": "Pandas missing"}
    try:
        contents = await file.read()
        df = pd.read_excel(io.BytesIO(contents))
        for index, row in df.iterrows():
            if pd.isna(row.get("Название")) or pd.isna(row.get("Цена")): continue
            name = str(row.get("Название")); price = float(row.get("Цена"))
            
            # 🔥 ЧИТАЕМ БРЕНД ИЗ EXCEL
            brand = str(row.get("Бренд", "")) if not pd.isna(row.get("Бренд")) else ""
            
            category_val = str(row.get("Категория", "Разное")) if not pd.isna(row.get("Категория")) else "Разное"
            subcategory_val = str(row.get("Подкатегория", "")) if not pd.isna(row.get("Подкатегория")) else ""
            new_product = ProductDB(
                name=name, 
                price=price, 
                brand=brand,
                category=category_val,
                subcategory=subcategory_val,
                description=str(row.get("Описание", "")) if not pd.isna(row.get("Описание")) else "",
                unit=str(row.get("Ед", "шт")) if not pd.isna(row.get("Ед")) else "шт",
                articul=str(row.get("Артикул", "")) if not pd.isna(row.get("Артикул")) else "",
                image="", 
                photos_json="[]", sizes_json="[]", colors_json="[]"
            )
            db.add(new_product)
        db.commit()
        refresh_products_cache(db)
    except Exception as e: print(f"Error: {e}")
    return RedirectResponse(url="/admin/products", status_code=303)

# --- МАСТЕРА ---
@router.get("/admin/masters")
def admin_masters(
    request: Request,
    page: int = 1,
    category: str = None,
    search: str = None,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("masters")),
):
    limit = 50
    offset = (page - 1) * limit
    search = (search or "").strip() or None
    query = db.query(MasterDB)
    if category and category != "All":
        query = query.filter(MasterDB.categories_json.like(f'%"{category}"%'))
    if search:
        like = _search_like(search)
        query = query.filter(
            or_(
                MasterDB.name.ilike(like),
                MasterDB.phone.ilike(like),
                MasterDB.description.ilike(like),
            )
        )
    total_items = query.count()
    total_pages = max(1, math.ceil(total_items / limit))
    masters = query.order_by(MasterDB.points.desc(), MasterDB.id.desc()).offset(offset).limit(limit).all()
    all_cats_set = set()
    all_masters_for_cats = db.query(MasterDB.categories_json).all()
    for m_json in all_masters_for_cats:
        try:
            cats = json.loads(m_json[0])
            for c in cats: all_cats_set.add(c)
        except: continue
    for m in masters:
        if m.categories_json:
            try: m.cats_list = json.loads(m.categories_json)
            except: m.cats_list = []
        else: m.cats_list = []
        if m.points is None: m.points = 0
        if m.otp_code is None: m.otp_code = ""

    return templates.TemplateResponse(request, "masters.html", {
        "request": request, 
        "masters": masters, 
        "page": "masters",
        "current_page": page,
        "total_pages": total_pages,
        "selected_category": category,
        "search_query": search or "",
        "all_categories": sorted(list(all_cats_set)),
        **_admin_ctx(_user),
    })

@router.get("/admin/masters/add")
def admin_masters_add_page(request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("masters"))):
    masters = db.query(MasterDB).all(); all_cats = set(); base = ["Сантехник", "Электрик", "Маляр"]; [all_cats.add(b) for b in base]
    for m in masters:
        try: [all_cats.add(c) for c in json.loads(m.categories_json)]
        except: continue
    return templates.TemplateResponse(request, "add_master.html", {"request": request, "page": "masters", "categories": sorted(list(all_cats)), **_admin_ctx(_user)})

@router.post("/admin/add_master")
async def admin_save_master(
    name: str = Form(...), phone: str = Form(...), description: str = Form(""), experience: int = Form(0),
    _user: MasterDB = Depends(require_admin_permission("masters")),
    categories: List[str] = Form([]), new_category: str = Form(None),
    avatar: UploadFile = File(None), portfolio: List[UploadFile] = File(None),
    service_names: List[str] = Form([]), service_prices: List[float] = Form([]), service_units: List[str] = Form([]),
    db: Session = Depends(get_db)
):
    final_cats = categories.copy()
    if new_category: final_cats.append(new_category)
    avatar_url = ""
    if avatar and avatar.filename:
        uid = f"{uuid.uuid4()}_{avatar.filename}"; path = os.path.join("static", "images", uid)
        with open(path, "wb") as buffer: shutil.copyfileobj(avatar.file, buffer)
        avatar_url = f"static/images/{uid}"
    portfolio_urls = []
    if portfolio:
        for file in portfolio:
            if file.filename:
                uid = f"{uuid.uuid4()}_{file.filename}"; path = os.path.join("static", "images", uid)
                with open(path, "wb") as buffer: shutil.copyfileobj(file.file, buffer)
                portfolio_urls.append(f"static/images/{uid}")
    services_list = []
    for i in range(len(service_names)):
        if service_names[i]: services_list.append({"name": service_names[i], "price": service_prices[i], "unit": service_units[i]})

    new_master = MasterDB(
        name=name, 
        phone=phone, 
        description=description, 
        experience=experience,
        city="",
        categories_json=json.dumps(final_cats, ensure_ascii=False), 
        image=avatar_url, 
        portfolio_json=json.dumps(portfolio_urls), 
        services_json=json.dumps(services_list, ensure_ascii=False),
        barcode="",
        is_password_reset=1,
        moderation_status="approved",
    )
    db.add(new_master)
    db.commit()
    return RedirectResponse(url="/admin/masters", status_code=303)

@router.get("/admin/masters/edit/{master_id}")
def admin_masters_edit_page(master_id: int, request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("masters"))):
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master: return RedirectResponse(url="/admin/masters")
    try: portfolio = json.loads(master.portfolio_json); services = json.loads(master.services_json); my_cats = json.loads(master.categories_json)
    except: portfolio=[]; services=[]; my_cats=[]
    masters = db.query(MasterDB).all(); all_cats = set(); base = ["Сантехник", "Электрик", "Маляр"]; [all_cats.add(b) for b in base]
    for m in masters:
        try: [all_cats.add(c) for c in json.loads(m.categories_json)]
        except: continue
    return templates.TemplateResponse(request, "edit_master.html", {"request": request, "page": "masters", "m": master, "portfolio": portfolio, "services": services, "my_cats": my_cats, "categories": sorted(list(all_cats)), **_admin_ctx(_user)})

@router.get("/admin/masters/{master_id}")
def admin_master_detail(master_id: int, request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("masters"))):
    # 1. Берем мастера
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master: return RedirectResponse(url="/admin/masters")

    # Декодируем JSON поля
    try: master.portfolio = json.loads(master.portfolio_json)
    except: master.portfolio = []
    try: master.services = json.loads(master.services_json)
    except: master.services = []
    try: master.cats_list = json.loads(master.categories_json)
    except: master.cats_list = []
    if master.points is None: master.points = 0

    # 2. Ищем его заказы (по номеру телефона)
    master_digits = "".join(filter(str.isdigit, master.phone))
    search_phone = master_digits[-9:] if len(master_digits) >= 9 else master_digits
    
    all_orders = db.query(OrderDB).order_by(OrderDB.id.desc()).all()
    master_orders = []
    total_spent = 0
    
    for o in all_orders:
        if not o.client_phone: continue
        o_digits = "".join(filter(str.isdigit, o.client_phone))
        if o_digits.endswith(search_phone):
            try: o.items_list = json.loads(o.items_json)
            except: o.items_list = []
            if o.status == "completed":
                total_spent += o.total_price
            master_orders.append(o)

    return templates.TemplateResponse(request, "master_detail.html", {
        "request": request, 
        "m": master, 
        "orders": master_orders,
        "total_spent": total_spent,
        **_admin_ctx(_user),
    })

@router.post("/admin/masters/{master_id}/reset-password")
def admin_reset_master_password(
    master_id: int,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("masters")),
):
    _reset_master_password_db(db, master_id)
    return RedirectResponse(
        url=f"/admin/masters/{master_id}?password_reset=1",
        status_code=303,
    )


@router.post("/api/v1/admin/users/{user_id}/reset-password-flag")
def api_v1_reset_password_flag(
    user_id: int,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin),
):
    _reset_master_password_db(db, user_id)
    return {
        "status": "success",
        "message": "Пароль мастера сброшен. Теперь он может задать новый код в своем приложении.",
    }


@router.post("/admin/edit_master/{master_id}")
async def admin_update_master(
    master_id: int, name: str = Form(...), phone: str = Form(...), description: str = Form(""), experience: int = Form(0),
    _user: MasterDB = Depends(require_admin_permission("masters")),
    categories: List[str] = Form([]), new_category: str = Form(None),
    avatar: UploadFile = File(None), portfolio: List[UploadFile] = File(None), existing_portfolio: List[str] = Form([]),
    service_names: List[str] = Form([]), service_prices: List[float] = Form([]), service_units: List[str] = Form([]),
    db: Session = Depends(get_db)
):
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master: return RedirectResponse(url="/admin/masters")
    final_cats = categories.copy()
    if new_category: final_cats.append(new_category)
    if avatar and avatar.filename:
        uid = f"{uuid.uuid4()}_{avatar.filename}"; path = os.path.join("static", "images", uid)
        with open(path, "wb") as buffer: shutil.copyfileobj(avatar.file, buffer)
        master.image = f"static/images/{uid}"
    new_portfolio_urls = []
    if portfolio:
        for file in portfolio:
            if file.filename:
                uid = f"{uuid.uuid4()}_{file.filename}"; path = os.path.join("static", "images", uid)
                with open(path, "wb") as buffer: shutil.copyfileobj(file.file, buffer)
                new_portfolio_urls.append(f"static/images/{uid}")
    services_list = []
    for i in range(len(service_names)):
        if service_names[i]: services_list.append({"name": service_names[i], "price": service_prices[i], "unit": service_units[i]})
    
    master.name = name; master.phone = phone; master.description = description; master.experience = experience
    master.categories_json = json.dumps(final_cats, ensure_ascii=False)
    master.portfolio_json = json.dumps(existing_portfolio + new_portfolio_urls)
    master.services_json = json.dumps(services_list, ensure_ascii=False)
    db.commit()
    return RedirectResponse(url="/admin/masters", status_code=303)

@router.get("/admin/delete_master/{master_id}")
def admin_delete_master(master_id: int, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("masters"))):
    # Удаляем связанные записи, чтобы не нарушать FK при удалении мастера
    db.query(RefreshTokenDB).filter(RefreshTokenDB.user_id == master_id).delete(synchronize_session=False)
    db.query(MasterNotificationDB).filter(MasterNotificationDB.master_id == master_id).delete(synchronize_session=False)
    db.query(DeviceTokenDB).filter(DeviceTokenDB.master_id == master_id).delete(synchronize_session=False)
    db.query(OrderDB).filter(OrderDB.master_id == master_id).update({OrderDB.master_id: None}, synchronize_session=False)
    db.query(MasterDB).filter(MasterDB.id == master_id).delete(synchronize_session=False)
    db.commit()
    return RedirectResponse(url="/admin/masters", status_code=303)

# --- ЗАКАЗЫ ---
@router.get("/admin/orders")
def admin_orders(request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("orders"))):
    orders = db.query(OrderDB).order_by(OrderDB.id.desc()).all()
    for o in orders:
        try: o.items_list = json.loads(o.items_json)
        except: o.items_list = []
    return templates.TemplateResponse(request, "orders.html", {"request": request, "orders": orders, "page": "orders", **_admin_ctx(_user)})

@router.post("/admin/orders/update_status")
async def admin_update_order_status(
    order_id: int = Form(...), 
    new_status: str = Form(...), 
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("orders")),
):
    apply_order_status_change(db, order_id, new_status)
    return RedirectResponse(url="/admin/orders", status_code=303)
@router.get("/admin/orders/invoice/{order_id}")
def admin_order_invoice(order_id: int, request: Request, db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("orders"))):
    order = db.query(OrderDB).filter(OrderDB.id == order_id).first()
    if not order: return RedirectResponse(url="/admin/orders")
    try: items = json.loads(order.items_json)
    except: items = []
    rows_count = 14; empty_rows = []
    if len(items) < rows_count: empty_rows = range(rows_count - len(items))
    try: date_obj = datetime.strptime(order.created_at, "%Y-%m-%d %H:%M"); formatted_date = date_obj.strftime("%d.%m.%Y")
    except: formatted_date = order.created_at
    return templates.TemplateResponse(request, "invoice.html", {"request": request, "o": order, "items": items, "empty_rows": empty_rows, "date": formatted_date, **_admin_ctx(_user)})

# -----------------------------------------------------------------------------
# Касса: начисление/списание баллов, рассылка уведомлений
# -----------------------------------------------------------------------------

@router.get("/admin/cashier")
def admin_cashier_page(request: Request, _user: MasterDB = Depends(require_admin_permission("cashier"))):
    """Экран кассы: терминал, списание баллов, рассылка акций."""
    return templates.TemplateResponse(request, "cashier.html", {
        "request": request, "page": "cashier", "success_msg": None, "error_msg": None,
        **_admin_ctx(_user),
    })


def _find_master_by_identifier(db: Session, identifier: str):
    """Найти мастера по ID или телефону (цифры)."""
    clean = "".join(filter(str.isdigit, identifier))
    if clean.isdigit() and len(clean) < 6:
        return db.query(MasterDB).filter(MasterDB.id == int(clean)).first()
    search = clean[-9:] if len(clean) >= 9 else clean
    for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
        m_digits = "".join(filter(str.isdigit, m.phone or ""))
        if m_digits.endswith(search):
            return m
    return None


@router.get("/admin/points")
def admin_points_redirect(request: Request, _user: MasterDB = Depends(require_admin_permission("cashier"))):
    """Редирект на экран кассы (для старых ссылок)."""
    return RedirectResponse(url="/admin/cashier", status_code=302)


@router.post("/admin/points/add")
def admin_add_points(request: Request, identifier: str = Form(...), amount: int = Form(...), db: Session = Depends(get_db), _user: MasterDB = Depends(require_admin_permission("cashier"))):
    if not MASTER_POINTS_ENABLED:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request,
            "page": "cashier",
            "success_msg": None,
            "error_msg": "❌ Программа баллов временно отключена.",
            **_admin_ctx(_user),
        })
    master = _find_master_by_identifier(db, identifier)
    
    if master:
        master.points += amount
        new_tx = TransactionDB(
            master_id=master.id,
            master_name=master.name,
            amount=amount,
            created_at=datetime.now().strftime("%Y-%m-%d %H:%M")
        )
        db.add(new_tx)
        db.commit()
        create_notification(
            db, master.id, "points_added",
            "Балл илова шуд",
            f"Ба шумо {amount} балл илова карда шуд. Ҳамагӣ: {master.points}.",
            {"amount": amount, "total_points": master.points},
        )
        db.commit()
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, 
            "page": "cashier",
            "success_msg": f"✅ {master.name}: +{amount} баллов. (Всего: {master.points})",
            "error_msg": None,
            **_admin_ctx(_user),
        })
    else:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, 
            "page": "cashier",
            "success_msg": None,
            "error_msg": f"❌ Мастер не найден! (Ввод: {identifier})",
            **_admin_ctx(_user),
        })


# -----------------------------------------------------------------------------
# Рассылка акций и списание баллов
# -----------------------------------------------------------------------------

@router.post("/admin/notifications/promo")
def admin_send_promo(
    request: Request,
    title: str = Form(..., description="Заголовок акции"),
    body: str = Form("", description="Текст уведомления"),
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("cashier")),
):
    """Рассылает уведомление-акцию всем зарегистрированным мастерам."""
    count = create_promo_for_all(db, title.strip(), body.strip())
    return templates.TemplateResponse(request, "cashier.html", {
        "request": request,
        "page": "cashier",
        "success_msg": f"✅ Акция отправлена {count} мастерам.",
        "error_msg": None,
        **_admin_ctx(_user),
    })


@router.post("/admin/points/spend")
def admin_spend_points(
    request: Request,
    identifier: str = Form(...),
    amount: int = Form(...),
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("cashier")),
):
    """Списание баллов у мастера (по ID или телефону). Создаёт уведомление points_spent."""
    if not MASTER_POINTS_ENABLED:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Программа баллов временно отключена.",
            **_admin_ctx(_user),
        })
    master = _find_master_by_identifier(db, identifier)
    if not master:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Мастер не найден.",
            **_admin_ctx(_user),
        })
    current = master.points or 0
    if amount > current:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": f"❌ Недостаточно баллов (есть {current}).",
            **_admin_ctx(_user),
        })
    master.points = current - amount
    db.commit()
    create_notification(
        db, master.id, "points_spent",
        "Балл хориҷ карда шуд",
        f"{amount} балл хориҷ карда шуд. Монда: {master.points}.",
        {"amount": amount, "total_points": master.points},
    )
    db.commit()
    return templates.TemplateResponse(request, "cashier.html", {
        "request": request, "page": "cashier",
        "success_msg": f"✅ {master.name}: списано {amount} баллов. Осталось: {master.points}.",
        "error_msg": None,
        **_admin_ctx(_user),
    })


# -----------------------------------------------------------------------------
# Долги: оформление и оплата через кассу, уведомления мастерам
# -----------------------------------------------------------------------------

@router.post("/admin/debt/add")
def admin_debt_add(
    request: Request,
    identifier: str = Form(...),
    amount: float = Form(...),
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("cashier")),
):
    """Оформить долг мастеру. Мастер получает уведомление type=debt."""
    master = _find_master_by_identifier(db, identifier)
    if not master:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Мастер не найден.",
            **_admin_ctx(_user),
        })
    if amount <= 0:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Сумма должна быть больше 0.",
            **_admin_ctx(_user),
        })
    current = getattr(master, "debt", 0.0) or 0.0
    master.debt = current + amount
    db.commit()
    create_notification(
        db, master.id, "debt",
        "Қарз ба қайд гирифта шуд",
        f"Ба шумо қарзи {amount} TJS ба қайд гирифта шуд. Ҳамагии қарз: {master.debt} TJS.",
        {"amount": amount, "total_debt": master.debt},
    )
    db.commit()
    return templates.TemplateResponse(request, "cashier.html", {
        "request": request, "page": "cashier",
        "success_msg": f"✅ {master.name}: долг +{amount} TJS. Всего долг: {master.debt} TJS.",
        "error_msg": None,
        **_admin_ctx(_user),
    })


@router.post("/admin/debt/pay")
def admin_debt_pay(
    request: Request,
    identifier: str = Form(...),
    amount: float = Form(...),
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("cashier")),
):
    """Оплата долга. Мастер получает уведомление type=debt."""
    master = _find_master_by_identifier(db, identifier)
    if not master:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Мастер не найден.",
            **_admin_ctx(_user),
        })
    if amount <= 0:
        return templates.TemplateResponse(request, "cashier.html", {
            "request": request, "page": "cashier",
            "success_msg": None, "error_msg": "❌ Сумма должна быть больше 0.",
            **_admin_ctx(_user),
        })
    current = getattr(master, "debt", 0.0) or 0.0
    master.debt = max(0.0, current - amount)
    db.commit()
    create_notification(
        db, master.id, "debt",
        "Пардохти қарз",
        f"{amount} TJS пардохт карда шуд. Мандии қарз: {master.debt} TJS.",
        {"amount": amount, "total_debt": master.debt},
    )
    db.commit()
    return templates.TemplateResponse(request, "cashier.html", {
        "request": request, "page": "cashier",
        "success_msg": f"✅ {master.name}: оплачено {amount} TJS. Остаток долга: {master.debt} TJS.",
        "error_msg": None,
        **_admin_ctx(_user),
    })


@router.get("/admin/debtors")
def admin_debtors(
    request: Request,
    db: Session = Depends(get_db),
    _user: MasterDB = Depends(require_admin_permission("cashier")),
):
    """Экран должников: мастера с долгом > 0."""
    debtors = db.query(MasterDB).filter(MasterDB.debt > 0).order_by(MasterDB.debt.desc()).all()
    total_debt = sum(getattr(m, "debt", 0.0) for m in debtors)
    return templates.TemplateResponse(request, "debtors.html", {
        "request": request,
        "page": "debtors",
        "debtors": debtors,
        "total_debt": total_debt,
        **_admin_ctx(_user),
        })