"""
JSON API для мобильного приложения Ustobozor Admin.
Авторизация: cookie superadmin_session или access_token (как в веб-админке).
"""

import json
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from auth import (
    ADMIN_SCOPES,
    get_admin_permissions,
    hash_pin,
    normalize_phone,
    require_admin,
    require_admin_permission,
    require_superadmin,
)
from database import (
    AdminDB,
    DeviceTokenDB,
    MasterDB,
    MasterNotificationDB,
    OrderDB,
    ProductDB,
    ProductStockDB,
    RefreshTokenDB,
    TransactionDB,
    get_db,
)
from order_actions import VALID_STATUSES, apply_order_status_change
from search_engine import refresh_products_cache
from config import MASTER_POINTS_ENABLED

router = APIRouter(prefix="/admin/api", tags=["admin-mobile"])


def _find_master_by_identifier(db: Session, identifier: str):
    clean = "".join(filter(str.isdigit, identifier or ""))
    if clean.isdigit() and len(clean) < 6:
        return db.query(MasterDB).filter(MasterDB.id == int(clean)).first()
    search = clean[-9:] if len(clean) >= 9 else clean
    for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
        m_digits = "".join(filter(str.isdigit, m.phone or ""))
        if m_digits.endswith(search):
            return m
    return None


def _parse_items(raw: str) -> list:
    try:
        data = json.loads(raw or "[]")
        return data if isinstance(data, list) else []
    except (TypeError, json.JSONDecodeError):
        return []


def _parse_cats(raw: str) -> list:
    try:
        data = json.loads(raw or "[]")
        return data if isinstance(data, list) else []
    except (TypeError, json.JSONDecodeError):
        return []


class OrderItemOut(BaseModel):
    name: Optional[str] = None
    qty: Optional[float] = None
    price: Optional[float] = None
    product_id: Optional[int] = None


class AdminOrderOut(BaseModel):
    id: int
    client_name: Optional[str] = None
    client_phone: Optional[str] = None
    client_address: Optional[str] = None
    total_price: float
    payment_type: Optional[str] = None
    comment: Optional[str] = None
    created_at: Optional[str] = None
    status: str
    items_count: int
    items: List[OrderItemOut] = []


class AdminMasterOut(BaseModel):
    id: int
    name: Optional[str] = None
    phone: Optional[str] = None
    points: int = 0
    debt: float = 0
    experience: int = 0
    rating: float = 5.0
    categories: List[str] = []
    image: Optional[str] = None


class AdminTransactionOut(BaseModel):
    id: int
    master_id: Optional[int] = None
    master_name: Optional[str] = None
    amount: float
    created_at: Optional[str] = None


class DashboardOut(BaseModel):
    new_orders_count: int
    orders_today_count: int
    online_revenue: float
    offline_revenue_today: float
    total_masters: int
    products_count: int
    recent_orders: List[AdminOrderOut]
    recent_transactions: List[AdminTransactionOut]


class OrderStatusBody(BaseModel):
    new_status: str = Field(..., description="new | processing | completed | canceled")


class PointsBody(BaseModel):
    identifier: str = Field(..., description="ID мастера или телефон")
    amount: int = Field(..., gt=0)


class DebtBody(BaseModel):
    identifier: str = Field(..., description="ID мастера или телефон")
    amount: float = Field(..., gt=0)


class PromoBody(BaseModel):
    title: str = Field(..., min_length=1)
    body: str = ""


class BulkDeleteBody(BaseModel):
    product_ids: List[int] = Field(..., min_length=1)


class StockBody(BaseModel):
    in_stock: bool


class AdminProductOut(BaseModel):
    id: int
    name: str
    price: float
    brand: Optional[str] = None
    category: Optional[str] = None
    subcategory: Optional[str] = None
    articul: Optional[str] = None
    description: Optional[str] = None
    unit: Optional[str] = None
    image: Optional[str] = None
    in_stock: bool = True
    photos: List[str] = []


class CategoriesOut(BaseModel):
    categories: List[str]
    subcategories: List[str]


class AdminSessionOut(BaseModel):
    name: str
    phone: Optional[str] = None
    is_superadmin: bool
    permissions: List[str]
    all_scopes: List[str]


class DebtorOut(BaseModel):
    id: int
    name: Optional[str] = None
    phone: Optional[str] = None
    debt: float
    points: int = 0


class MasterDetailOut(AdminMasterOut):
    description: Optional[str] = None
    orders_count: int = 0
    total_spent: float = 0
    recent_orders: List[AdminOrderOut] = []
    services: List[dict] = []
    portfolio: List[str] = []


class MasterServiceIn(BaseModel):
    name: str
    price: float = 0
    unit: str = ""


class MasterSaveBody(BaseModel):
    name: str = Field(..., min_length=1)
    phone: str = Field(..., min_length=9)
    description: str = ""
    experience: int = 0
    categories: List[str] = []
    new_category: Optional[str] = None
    services: List[MasterServiceIn] = []


class InvoiceItemOut(BaseModel):
    name: str
    qty: float
    price: float
    unit: str = "шт"
    line_total: float


class InvoiceOut(BaseModel):
    order_id: int
    invoice_number: str
    date: str
    client_name: Optional[str] = None
    client_phone: Optional[str] = None
    client_address: Optional[str] = None
    items: List[InvoiceItemOut]
    total: float
    payment_type: Optional[str] = None
    comment: Optional[str] = None


class AdminUserOut(BaseModel):
    id: int
    name: str
    phone: str
    is_superadmin: bool
    permissions: List[str]


class AdminSaveBody(BaseModel):
    name: str = ""
    phone: str
    pin: str = ""
    permissions: List[str] = []


SCOPE_LABELS = {
    "dashboard": "Дашборд",
    "orders": "Заказы",
    "products": "Товары",
    "masters": "Мастера",
    "cashier": "Касса",
}


class PointsResult(BaseModel):
    ok: bool
    message: str
    master_id: Optional[int] = None
    master_name: Optional[str] = None
    points: Optional[int] = None


def _order_out(o: OrderDB) -> AdminOrderOut:
    items = _parse_items(o.items_json)
    parsed = [
        OrderItemOut(
            name=i.get("name"),
            qty=i.get("qty"),
            price=i.get("price"),
            product_id=i.get("product_id") or i.get("id"),
        )
        for i in items
    ]
    return AdminOrderOut(
        id=o.id,
        client_name=o.client_name,
        client_phone=o.client_phone,
        client_address=o.client_address,
        total_price=float(o.total_price or 0),
        payment_type=o.payment_type,
        comment=o.comment,
        created_at=o.created_at,
        status=o.status or "new",
        items_count=len(parsed),
        items=parsed,
    )


def _master_out(m: MasterDB) -> AdminMasterOut:
    return AdminMasterOut(
        id=m.id,
        name=m.name,
        phone=m.phone,
        points=int(m.points or 0),
        debt=float(getattr(m, "debt", 0) or 0),
        experience=int(m.experience or 0),
        rating=float(m.rating or 5),
        categories=_parse_cats(m.categories_json),
        image=m.image,
    )


def _tx_out(t: TransactionDB) -> AdminTransactionOut:
    return AdminTransactionOut(
        id=t.id,
        master_id=t.master_id,
        master_name=t.master_name,
        amount=float(t.amount or 0),
        created_at=t.created_at,
    )


def _session_out(user) -> AdminSessionOut:
    is_super = bool(getattr(user, "is_superadmin", None))
    return AdminSessionOut(
        name=(getattr(user, "name", None) or "Админ").strip() or "Админ",
        phone=getattr(user, "phone", None),
        is_superadmin=is_super,
        permissions=get_admin_permissions(user),
        all_scopes=list(ADMIN_SCOPES),
    )


def _product_stock_map(db: Session, product_ids: List[int]) -> dict:
    if not product_ids:
        return {}
    rows = db.query(ProductStockDB).filter(ProductStockDB.product_id.in_(product_ids)).all()
    return {r.product_id: int(r.is_in_stock) for r in rows}


def _product_out(p: ProductDB, stock_map: dict) -> AdminProductOut:
    photos = []
    try:
        raw = json.loads(p.photos_json or "[]")
        if isinstance(raw, list):
            photos = [str(x) for x in raw if x]
    except (TypeError, json.JSONDecodeError):
        pass
    in_stock = stock_map.get(p.id, 1) != 0
    return AdminProductOut(
        id=p.id,
        name=p.name or "",
        price=float(p.price or 0),
        brand=p.brand,
        category=p.category,
        subcategory=p.subcategory,
        articul=p.articul,
        description=p.description,
        unit=p.unit,
        image=p.image,
        in_stock=in_stock,
        photos=photos,
    )


def _parse_services(raw: str) -> list:
    try:
        data = json.loads(raw or "[]")
        return data if isinstance(data, list) else []
    except (TypeError, json.JSONDecodeError):
        return []


def _parse_portfolio(raw: str) -> list:
    try:
        data = json.loads(raw or "[]")
        if isinstance(data, list):
            return [str(x) for x in data if x]
    except (TypeError, json.JSONDecodeError):
        pass
    return []


def _master_category_options(db: Session) -> List[str]:
    base = ["Сантехник", "Электрик", "Маляр"]
    all_cats = set(base)
    for m in db.query(MasterDB).all():
        for c in _parse_cats(m.categories_json):
            if c:
                all_cats.add(c)
    return sorted(all_cats)


def _master_detail_out(db: Session, master: MasterDB) -> MasterDetailOut:
    master_digits = "".join(filter(str.isdigit, master.phone or ""))
    search_phone = master_digits[-9:] if len(master_digits) >= 9 else master_digits
    master_orders = []
    total_spent = 0.0
    for o in db.query(OrderDB).order_by(OrderDB.id.desc()).all():
        if not o.client_phone:
            continue
        o_digits = "".join(filter(str.isdigit, o.client_phone))
        if o_digits.endswith(search_phone):
            out = _order_out(o)
            master_orders.append(out)
            if (o.status or "") == "completed":
                total_spent += float(o.total_price or 0)
    base = _master_out(master)
    return MasterDetailOut(
        **base.model_dump(),
        description=getattr(master, "description", None),
        orders_count=len(master_orders),
        total_spent=total_spent,
        recent_orders=master_orders[:10],
        services=_parse_services(master.services_json),
        portfolio=_parse_portfolio(master.portfolio_json),
    )


def _is_today(date_str: Optional[str]) -> bool:
    if not date_str:
        return False
    try:
        dt = datetime.strptime(date_str, "%Y-%m-%d %H:%M")
        return dt.date() == datetime.now().date()
    except ValueError:
        return False


@router.get("/me", response_model=AdminSessionOut)
def admin_api_me(_user=Depends(require_admin)):
    return _session_out(_user)


@router.get("/dashboard", response_model=DashboardOut)
def admin_api_dashboard(
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("dashboard")),
):
    orders = db.query(OrderDB).order_by(OrderDB.id.desc()).all()
    transactions = db.query(TransactionDB).order_by(TransactionDB.id.desc()).limit(50).all()
    masters_count = db.query(MasterDB).count()
    products_count = db.query(ProductDB).count()

    new_orders = [o for o in orders if (o.status or "new") == "new"]
    orders_today = [o for o in orders if _is_today(o.created_at)]
    online_revenue = sum(float(o.total_price or 0) for o in orders if o.status == "completed")
    tx_today = [t for t in transactions if _is_today(t.created_at)]
    offline_today = sum(float(t.amount or 0) for t in tx_today)

    return DashboardOut(
        new_orders_count=len(new_orders),
        orders_today_count=len(orders_today),
        online_revenue=online_revenue,
        offline_revenue_today=offline_today,
        total_masters=masters_count,
        products_count=products_count,
        recent_orders=[_order_out(o) for o in orders[:8]],
        recent_transactions=[_tx_out(t) for t in transactions[:8]],
    )


@router.get("/orders", response_model=List[AdminOrderOut])
def admin_api_orders(
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("orders")),
):
    q = db.query(OrderDB).order_by(OrderDB.id.desc())
    if status and status in VALID_STATUSES:
        q = q.filter(OrderDB.status == status)
    return [_order_out(o) for o in q.limit(100).all()]


@router.post("/orders/{order_id}/status")
def admin_api_order_status(
    order_id: int,
    body: OrderStatusBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("orders")),
):
    if body.new_status not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail="Недопустимый статус")
    ok = apply_order_status_change(db, order_id, body.new_status)
    if not ok:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    order = db.query(OrderDB).filter(OrderDB.id == order_id).first()
    return {"ok": True, "order": _order_out(order)}


@router.get("/orders/{order_id}/invoice", response_model=InvoiceOut)
def admin_api_order_invoice(
    order_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("orders")),
):
    order = db.query(OrderDB).filter(OrderDB.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    raw_items = _parse_items(order.items_json)
    items_out = []
    for i in raw_items:
        name = str(i.get("name") or "—")
        qty = float(i.get("qty") or 1)
        price = float(i.get("price") or 0)
        unit = str(i.get("unit") or "шт")
        items_out.append(
            InvoiceItemOut(
                name=name,
                qty=qty,
                price=price,
                unit=unit,
                line_total=round(qty * price, 2),
            )
        )
    try:
        date_obj = datetime.strptime(order.created_at, "%Y-%m-%d %H:%M")
        formatted_date = date_obj.strftime("%d.%m.%Y")
    except (TypeError, ValueError):
        formatted_date = order.created_at or ""
    return InvoiceOut(
        order_id=order.id,
        invoice_number=f"{order.id:06d}",
        date=formatted_date,
        client_name=order.client_name,
        client_phone=order.client_phone,
        client_address=order.client_address,
        items=items_out,
        total=float(order.total_price or 0),
        payment_type=order.payment_type,
        comment=order.comment,
    )


@router.get("/masters", response_model=List[AdminMasterOut])
def admin_api_masters(
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    q = db.query(MasterDB).order_by(MasterDB.points.desc(), MasterDB.id.desc())
    if search and search.strip():
        like = f"%{search.strip()}%"
        q = q.filter(
            (MasterDB.name.ilike(like))
            | (MasterDB.phone.ilike(like))
        )
    return [_master_out(m) for m in q.limit(100).all()]


@router.post("/masters/{master_id}/reset-password")
def admin_api_reset_master_password(
    master_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    from admin_routes import _reset_master_password_db

    _reset_master_password_db(db, master_id)
    return {
        "ok": True,
        "message": "Пароль мастера сброшен. Теперь он может задать новый пароль в приложении.",
    }


@router.get("/cashier/summary")
def admin_api_cashier_summary(
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    transactions = db.query(TransactionDB).order_by(TransactionDB.id.desc()).limit(200).all()
    tx_today = [t for t in transactions if _is_today(t.created_at)]
    total_today = sum(float(t.amount or 0) for t in tx_today)
    return {
        "operations_today": len(tx_today),
        "revenue_today": total_today,
        "recent": [_tx_out(t) for t in transactions[:10]],
    }


@router.get("/cashier/transactions", response_model=List[AdminTransactionOut])
def admin_api_cashier_transactions(
    limit: int = 30,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    rows = db.query(TransactionDB).order_by(TransactionDB.id.desc()).limit(min(limit, 100)).all()
    return [_tx_out(t) for t in rows]


@router.post("/cashier/points/add", response_model=PointsResult)
def admin_api_points_add(
    body: PointsBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    if not MASTER_POINTS_ENABLED:
        return PointsResult(ok=False, message="Программа баллов временно отключена")
    from notifications import create_notification

    master = _find_master_by_identifier(db, body.identifier)
    if not master:
        return PointsResult(ok=False, message="Мастер не найден")
    master.points = int(master.points or 0) + body.amount
    tx = TransactionDB(
        master_id=master.id,
        master_name=master.name,
        amount=float(body.amount),
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
    )
    db.add(tx)
    create_notification(
        db,
        master.id,
        "points_added",
        "Балл илова шуд",
        f"Ба шумо {body.amount} балл илова карда шуд. Ҳамагӣ: {master.points}.",
        {"amount": body.amount, "total_points": master.points},
    )
    db.commit()
    return PointsResult(
        ok=True,
        message=f"+{body.amount} баллов",
        master_id=master.id,
        master_name=master.name,
        points=int(master.points or 0),
    )


@router.get("/products/categories", response_model=CategoriesOut)
def admin_api_product_categories(
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("products")),
):
    cats = db.query(ProductDB.category).distinct().all()
    subs = db.query(ProductDB.subcategory).distinct().all()
    return CategoriesOut(
        categories=sorted([c[0] for c in cats if c[0] and str(c[0]).strip()]),
        subcategories=sorted([s[0] for s in subs if s[0] and str(s[0]).strip()]),
    )


@router.get("/products", response_model=List[AdminProductOut])
def admin_api_products(
    search: Optional[str] = None,
    category: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("products")),
):
    q = db.query(ProductDB)
    if category and category.strip():
        q = q.filter(ProductDB.category == category.strip())
    if search and search.strip():
        like = f"%{search.strip()}%"
        q = q.filter(
            (ProductDB.name.ilike(like))
            | (ProductDB.articul.ilike(like))
            | (ProductDB.category.ilike(like))
        )
    rows = q.order_by(ProductDB.id.desc()).offset(max(offset, 0)).limit(min(limit, 200)).all()
    stock_map = _product_stock_map(db, [p.id for p in rows])
    return [_product_out(p, stock_map) for p in rows]


@router.delete("/products/{product_id}")
def admin_api_delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("products")),
):
    deleted = db.query(ProductDB).filter(ProductDB.id == product_id).delete()
    if not deleted:
        raise HTTPException(status_code=404, detail="Товар не найден")
    db.query(ProductStockDB).filter(ProductStockDB.product_id == product_id).delete()
    db.commit()
    refresh_products_cache(db)
    return {"ok": True}


@router.post("/products/delete_bulk")
def admin_api_delete_products_bulk(
    body: BulkDeleteBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("products")),
):
    ids = list({int(i) for i in body.product_ids if i})
    if not ids:
        raise HTTPException(status_code=400, detail="Укажите товары")
    db.query(ProductDB).filter(ProductDB.id.in_(ids)).delete(synchronize_session=False)
    db.query(ProductStockDB).filter(ProductStockDB.product_id.in_(ids)).delete(synchronize_session=False)
    db.commit()
    refresh_products_cache(db)
    return {"ok": True, "deleted": len(ids)}


@router.post("/products/{product_id}/stock")
def admin_api_set_product_stock(
    product_id: int,
    body: StockBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("products")),
):
    product = db.query(ProductDB).filter(ProductDB.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Товар не найден")
    row = db.query(ProductStockDB).filter(ProductStockDB.product_id == product_id).first()
    if not row:
        row = ProductStockDB(product_id=product_id)
        db.add(row)
    row.is_in_stock = 1 if body.in_stock else 0
    row.updated_at = int(datetime.now().timestamp())
    db.commit()
    return {"ok": True, "product_id": product_id, "in_stock": bool(body.in_stock)}


@router.get("/masters/meta/categories")
def admin_api_master_categories(
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    return {"categories": _master_category_options(db)}


@router.post("/masters", response_model=MasterDetailOut)
def admin_api_create_master(
    body: MasterSaveBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    phone_norm = normalize_phone(body.phone)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Некорректный телефон")
    existing = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
    if not existing:
        for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
            if normalize_phone(m.phone or "") == phone_norm:
                existing = m
                break
    if existing:
        raise HTTPException(status_code=400, detail="Мастер с таким телефоном уже есть")
    final_cats = [c for c in body.categories if c]
    if body.new_category and body.new_category.strip():
        final_cats.append(body.new_category.strip())
    services_list = [
        {"name": s.name, "price": s.price, "unit": s.unit}
        for s in body.services
        if s.name.strip()
    ]
    master = MasterDB(
        name=body.name.strip(),
        phone=body.phone.strip(),
        phone_norm=phone_norm,
        description=body.description or "",
        experience=int(body.experience or 0),
        categories_json=json.dumps(final_cats, ensure_ascii=False),
        services_json=json.dumps(services_list, ensure_ascii=False),
        portfolio_json="[]",
        image="",
        barcode="",
        is_password_reset=1,
    )
    db.add(master)
    db.commit()
    db.refresh(master)
    return _master_detail_out(db, master)


@router.put("/masters/{master_id}", response_model=MasterDetailOut)
def admin_api_update_master(
    master_id: int,
    body: MasterSaveBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    phone_norm = normalize_phone(body.phone)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Некорректный телефон")
    other = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm, MasterDB.id != master_id).first()
    if other:
        raise HTTPException(status_code=400, detail="Телефон уже используется другим мастером")
    final_cats = [c for c in body.categories if c]
    if body.new_category and body.new_category.strip():
        final_cats.append(body.new_category.strip())
    services_list = [
        {"name": s.name, "price": s.price, "unit": s.unit}
        for s in body.services
        if s.name.strip()
    ]
    master.name = body.name.strip()
    master.phone = body.phone.strip()
    master.phone_norm = phone_norm
    master.description = body.description or ""
    master.experience = int(body.experience or 0)
    master.categories_json = json.dumps(final_cats, ensure_ascii=False)
    master.services_json = json.dumps(services_list, ensure_ascii=False)
    db.commit()
    db.refresh(master)
    return _master_detail_out(db, master)


@router.delete("/masters/{master_id}")
def admin_api_delete_master(
    master_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    db.query(RefreshTokenDB).filter(RefreshTokenDB.user_id == master_id).delete(synchronize_session=False)
    db.query(MasterNotificationDB).filter(MasterNotificationDB.master_id == master_id).delete(synchronize_session=False)
    db.query(DeviceTokenDB).filter(DeviceTokenDB.master_id == master_id).delete(synchronize_session=False)
    db.query(OrderDB).filter(OrderDB.master_id == master_id).update({OrderDB.master_id: None}, synchronize_session=False)
    db.delete(master)
    db.commit()
    return {"ok": True}


@router.get("/masters/{master_id}", response_model=MasterDetailOut)
def admin_api_master_detail(
    master_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("masters")),
):
    master = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not master:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    return _master_detail_out(db, master)


@router.get("/admins/scopes")
def admin_api_admin_scopes(_user=Depends(require_superadmin)):
    return {"scopes": ADMIN_SCOPES, "labels": SCOPE_LABELS}


@router.get("/admins", response_model=List[AdminUserOut])
def admin_api_list_admins(
    db: Session = Depends(get_db),
    _user=Depends(require_superadmin),
):
    rows = db.query(AdminDB).order_by(AdminDB.id).all()
    return [
        AdminUserOut(
            id=a.id,
            name=a.name or "—",
            phone=a.phone or "—",
            is_superadmin=bool(a.is_superadmin),
            permissions=get_admin_permissions(a),
        )
        for a in rows
    ]


@router.post("/admins", response_model=AdminUserOut)
def admin_api_save_admin(
    body: AdminSaveBody,
    db: Session = Depends(get_db),
    _user=Depends(require_superadmin),
):
    phone_norm = normalize_phone(body.phone)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Укажите корректный номер")
    pin_clean = "".join(filter(str.isdigit, body.pin or ""))
    if len(pin_clean) != 4:
        raise HTTPException(status_code=400, detail="PIN должен быть 4 цифры")
    display_name = (body.name or "").strip() or f"Админ {phone_norm[-4:]}"
    allowed = [s for s in body.permissions if s in ADMIN_SCOPES]
    admin = db.query(AdminDB).filter(AdminDB.phone_norm == phone_norm).first()
    if admin:
        admin.name = display_name
        admin.phone = body.phone.strip()
        admin.pin_hash = hash_pin(pin_clean)
        admin.is_superadmin = 0
        admin.admin_permissions = json.dumps(allowed, ensure_ascii=False)
    else:
        admin = AdminDB(
            name=display_name,
            phone=body.phone.strip(),
            phone_norm=phone_norm,
            pin_hash=hash_pin(pin_clean),
            is_superadmin=0,
            admin_permissions=json.dumps(allowed, ensure_ascii=False),
        )
        db.add(admin)
    db.commit()
    db.refresh(admin)
    return AdminUserOut(
        id=admin.id,
        name=admin.name or "—",
        phone=admin.phone or "—",
        is_superadmin=bool(admin.is_superadmin),
        permissions=get_admin_permissions(admin),
    )


@router.put("/admins/{admin_id}", response_model=AdminUserOut)
def admin_api_update_admin(
    admin_id: int,
    body: AdminSaveBody,
    db: Session = Depends(get_db),
    _user=Depends(require_superadmin),
):
    admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Админ не найден")
    if admin.is_superadmin:
        raise HTTPException(status_code=400, detail="Супер-админа нельзя редактировать")
    phone_norm = normalize_phone(body.phone)
    if len(phone_norm) < 9:
        raise HTTPException(status_code=400, detail="Укажите корректный номер")
    other = db.query(AdminDB).filter(AdminDB.phone_norm == phone_norm, AdminDB.id != admin_id).first()
    if other:
        raise HTTPException(status_code=400, detail="Телефон уже занят")
    display_name = (body.name or "").strip() or admin.name
    allowed = [s for s in body.permissions if s in ADMIN_SCOPES]
    admin.name = display_name
    admin.phone = body.phone.strip()
    admin.phone_norm = phone_norm
    admin.admin_permissions = json.dumps(allowed, ensure_ascii=False)
    pin_clean = "".join(filter(str.isdigit, body.pin or ""))
    if len(pin_clean) == 4:
        admin.pin_hash = hash_pin(pin_clean)
    db.commit()
    db.refresh(admin)
    return AdminUserOut(
        id=admin.id,
        name=admin.name or "—",
        phone=admin.phone or "—",
        is_superadmin=bool(admin.is_superadmin),
        permissions=get_admin_permissions(admin),
    )


@router.delete("/admins/{admin_id}")
def admin_api_delete_admin(
    admin_id: int,
    db: Session = Depends(get_db),
    _user=Depends(require_superadmin),
):
    admin = db.query(AdminDB).filter(AdminDB.id == admin_id).first()
    if not admin:
        raise HTTPException(status_code=404, detail="Админ не найден")
    if admin.is_superadmin:
        raise HTTPException(status_code=400, detail="Супер-админа удалить нельзя")
    db.delete(admin)
    db.commit()
    return {"ok": True}


@router.get("/cashier/debtors", response_model=List[DebtorOut])
def admin_api_debtors(
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    rows = db.query(MasterDB).filter(MasterDB.debt > 0).order_by(MasterDB.debt.desc()).all()
    return [
        DebtorOut(
            id=m.id,
            name=m.name,
            phone=m.phone,
            debt=float(getattr(m, "debt", 0) or 0),
            points=int(m.points or 0),
        )
        for m in rows
    ]


@router.post("/cashier/debt/add")
def admin_api_debt_add(
    body: DebtBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    from notifications import create_notification

    master = _find_master_by_identifier(db, body.identifier)
    if not master:
        return {"ok": False, "message": "Мастер не найден"}
    current = float(getattr(master, "debt", 0) or 0)
    master.debt = current + body.amount
    db.commit()
    create_notification(
        db,
        master.id,
        "debt",
        "Қарз ба қайд гирифта шуд",
        f"Ба шумо қарзи {body.amount} TJS ба қайд гирифта шуд. Ҳамагии қарз: {master.debt} TJS.",
        {"amount": body.amount, "total_debt": master.debt},
    )
    db.commit()
    return {
        "ok": True,
        "message": f"+{body.amount} TJS долг",
        "master_id": master.id,
        "master_name": master.name,
        "debt": float(master.debt or 0),
    }


@router.post("/cashier/debt/pay")
def admin_api_debt_pay(
    body: DebtBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    from notifications import create_notification

    master = _find_master_by_identifier(db, body.identifier)
    if not master:
        return {"ok": False, "message": "Мастер не найден"}
    current = float(getattr(master, "debt", 0) or 0)
    master.debt = max(0.0, current - body.amount)
    db.commit()
    create_notification(
        db,
        master.id,
        "debt",
        "Пардохти қарз",
        f"{body.amount} TJS пардохт карда шуд. Мандии қарз: {master.debt} TJS.",
        {"amount": body.amount, "total_debt": master.debt},
    )
    db.commit()
    return {
        "ok": True,
        "message": f"−{body.amount} TJS оплата",
        "master_id": master.id,
        "master_name": master.name,
        "debt": float(master.debt or 0),
    }


@router.post("/cashier/promo")
def admin_api_promo(
    body: PromoBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    from notifications import create_promo_for_all

    count = create_promo_for_all(db, body.title.strip(), body.body.strip())
    return {"ok": True, "message": f"Акция отправлена {count} мастерам", "count": count}


@router.post("/cashier/points/spend", response_model=PointsResult)
def admin_api_points_spend(
    body: PointsBody,
    db: Session = Depends(get_db),
    _user=Depends(require_admin_permission("cashier")),
):
    if not MASTER_POINTS_ENABLED:
        return PointsResult(ok=False, message="Программа баллов временно отключена")
    from notifications import create_notification

    master = _find_master_by_identifier(db, body.identifier)
    if not master:
        return PointsResult(ok=False, message="Мастер не найден")
    current = int(master.points or 0)
    if body.amount > current:
        return PointsResult(
            ok=False,
            message=f"Недостаточно баллов (есть {current})",
            master_id=master.id,
            master_name=master.name,
            points=current,
        )
    master.points = current - body.amount
    tx = TransactionDB(
        master_id=master.id,
        master_name=master.name,
        amount=float(-body.amount),
        created_at=datetime.now().strftime("%Y-%m-%d %H:%M"),
    )
    db.add(tx)
    create_notification(
        db,
        master.id,
        "points_spent",
        "Балл хориҷ карда шуд",
        f"{body.amount} балл хориҷ карда шуд. Монда: {master.points}.",
        {"amount": body.amount, "total_points": master.points},
    )
    db.commit()
    return PointsResult(
        ok=True,
        message=f"−{body.amount} баллов",
        master_id=master.id,
        master_name=master.name,
        points=int(master.points or 0),
    )
