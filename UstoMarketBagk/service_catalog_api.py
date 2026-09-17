"""
Каталог фикс-услуг и заказы (service_orders).
Комиссия с баланса мастера временно отключена.
Не связано с магазинными orders и свободными service_requests.
"""

from __future__ import annotations

import base64
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from auth import get_current_client, get_master_for_me
from database import (
    BalanceTransactionDB,
    ClientDB,
    MasterBalanceDB,
    MasterDB,
    ServiceCatalogDB,
    ServiceCategoryDB,
    ServiceOrderDB,
    ServiceOrderPhotoDB,
    ServiceOrderReviewDB,
    ServiceOrderReviewPhotoDB,
    get_db,
)
from image_utils import save_upload_as_webp

router = APIRouter(tags=["service-catalog"])

ORDER_STATUSES = {"NEW", "IN_PROGRESS", "COMPLETED", "CANCELLED"}


def _now() -> str:
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")


def _decode_photo(raw: str) -> Optional[bytes]:
    s = (raw or "").strip()
    if not s:
        return None
    if "," in s and s.lower().startswith("data:"):
        s = s.split(",", 1)[1]
    try:
        return base64.b64decode(s, validate=False)
    except Exception:
        return None


def ensure_master_balance(db: Session, master_id: int) -> MasterBalanceDB:
    """Кошелёк без стартового бонуса (комиссия пока отключена)."""
    row = db.query(MasterBalanceDB).filter(MasterBalanceDB.master_id == master_id).first()
    if row:
        return row
    row = MasterBalanceDB(master_id=master_id, balance=0.0)
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def seed_service_catalog_if_empty(db: Session) -> None:
    if db.query(ServiceCategoryDB).count() > 0:
        return
    cats = [
        "Сантехника",
        "Электрика",
        "Отделка",
        "Климат",
        "Мебель",
        "Общий ремонт",
    ]
    cat_rows = []
    for name in cats:
        c = ServiceCategoryDB(name=name, is_active=1)
        db.add(c)
        cat_rows.append(c)
    db.flush()

    samples = [
        ("Сантехника", "Установка раковины", 150.0, 0.0),
        ("Сантехника", "Замена смесителя", 100.0, 0.0),
        ("Сантехника", "Прочистка засора", 80.0, 0.0),
        ("Электрика", "Установка розетки", 70.0, 0.0),
        ("Электрика", "Замена автомата", 90.0, 0.0),
        ("Отделка", "Шпаклёвка стены (м²)", 45.0, 0.0),
        ("Климат", "Чистка кондиционера", 120.0, 0.0),
        ("Мебель", "Сборка шкафа", 200.0, 0.0),
    ]
    by_name = {c.name: c for c in cat_rows}
    for cat_name, title, price, fee in samples:
        db.add(
            ServiceCatalogDB(
                category_id=by_name[cat_name].id,
                title=title,
                price_client=price,
                commission_fee=fee,
                is_active=1,
            )
        )
    db.commit()


# ---------- serializers ----------

def _category_out(c: ServiceCategoryDB) -> dict:
    return {"id": c.id, "name": c.name, "is_active": bool(c.is_active)}


def _service_out(s: ServiceCatalogDB, category_name: str = "") -> dict:
    return {
        "id": s.id,
        "category_id": s.category_id,
        "category_name": category_name,
        "title": s.title,
        "price_client": float(s.price_client or 0),
        "commission_fee": float(s.commission_fee or 0),
        "is_active": bool(s.is_active),
    }


def _order_photos(db: Session, order_id: int) -> List[str]:
    rows = (
        db.query(ServiceOrderPhotoDB)
        .filter(ServiceOrderPhotoDB.order_id == order_id)
        .all()
    )
    return [r.image_url for r in rows if r.image_url]


def _parse_categories(raw) -> List[str]:
    import json

    if not raw:
        return []
    if isinstance(raw, list):
        return [str(x).strip() for x in raw if str(x).strip()]
    try:
        data = json.loads(raw)
        if isinstance(data, list):
            return [str(x).strip() for x in data if str(x).strip()]
    except Exception:
        pass
    return []


def _order_has_review(db: Session, order_id: int) -> bool:
    return (
        db.query(ServiceOrderReviewDB.id)
        .filter(ServiceOrderReviewDB.order_id == order_id)
        .first()
        is not None
    )


def _recalc_master_rating(db: Session, master_id: int) -> None:
    rows = (
        db.query(ServiceOrderReviewDB.rating)
        .filter(ServiceOrderReviewDB.master_id == master_id)
        .all()
    )
    m = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not m:
        return
    if not rows:
        # Без реальных отзывов не показываем «фейковый» рейтинг из сидов.
        m.rating = 0.0
        m.reviews_count = 0
        return
    vals = [int(r[0]) for r in rows if r[0] is not None]
    m.reviews_count = len(vals)
    m.rating = round(sum(vals) / len(vals), 2) if vals else 0.0


def sync_all_master_ratings_from_reviews(db: Session) -> int:
    """Пересчитать rating/reviews_count у всех мастеров из service_order_reviews."""
    from sqlalchemy import func

    agg = {
        int(mid): (int(cnt), float(avg) if avg is not None else 0.0)
        for mid, cnt, avg in db.query(
            ServiceOrderReviewDB.master_id,
            func.count(ServiceOrderReviewDB.id),
            func.avg(ServiceOrderReviewDB.rating),
        )
        .group_by(ServiceOrderReviewDB.master_id)
        .all()
    }
    updated = 0
    for m in db.query(MasterDB).all():
        cnt, avg = agg.get(m.id, (0, 0.0))
        new_rating = round(avg, 2) if cnt > 0 else 0.0
        new_count = cnt
        if float(m.rating or 0) != new_rating or int(getattr(m, "reviews_count", 0) or 0) != new_count:
            m.rating = new_rating
            m.reviews_count = new_count
            updated += 1
    if updated:
        db.commit()
    return updated


def master_review_stats_map(db: Session) -> dict:
    """master_id -> (reviews_count, avg_rating) из реальной таблицы отзывов."""
    from sqlalchemy import func

    out = {}
    for mid, cnt, avg in db.query(
        ServiceOrderReviewDB.master_id,
        func.count(ServiceOrderReviewDB.id),
        func.avg(ServiceOrderReviewDB.rating),
    ).group_by(ServiceOrderReviewDB.master_id).all():
        out[int(mid)] = (int(cnt), round(float(avg or 0), 2))
    return out


def master_review_stats(db: Session, master_id: int) -> tuple:
    from sqlalchemy import func

    row = (
        db.query(
            func.count(ServiceOrderReviewDB.id),
            func.avg(ServiceOrderReviewDB.rating),
        )
        .filter(ServiceOrderReviewDB.master_id == master_id)
        .first()
    )
    if not row or not row[0]:
        return (0, 0.0)
    return (int(row[0]), round(float(row[1] or 0), 2))


def _master_summary(db: Session, master_id: int, *, include_phone: bool) -> Optional[dict]:
    import json

    m = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not m:
        return None
    cats = _parse_categories(getattr(m, "categories_json", None))
    cnt, avg = master_review_stats(db, master_id)
    portfolio = []
    services = []
    try:
        raw_p = getattr(m, "portfolio_json", None) or "[]"
        data_p = json.loads(raw_p) if isinstance(raw_p, str) else raw_p
        if isinstance(data_p, list):
            portfolio = [str(x).strip() for x in data_p if str(x).strip()]
    except Exception:
        portfolio = []
    try:
        raw_s = getattr(m, "services_json", None) or "[]"
        data_s = json.loads(raw_s) if isinstance(raw_s, str) else raw_s
        if isinstance(data_s, list):
            services = data_s
    except Exception:
        services = []
    out = {
        "id": m.id,
        "name": (m.name or "").strip() or "Мастер",
        "image": m.image or "",
        "rating": avg if cnt > 0 else 0.0,
        "reviews_count": cnt,
        "specialization": cats[0] if cats else "",
        "categories": cats,
        "city": (getattr(m, "city", None) or ""),
        "description": m.description or "",
        "experience": int(m.experience or 0),
        "portfolio": portfolio,
        "services": services,
    }
    if include_phone:
        out["phone"] = m.phone or ""
    return out


def _review_out(db: Session, r: ServiceOrderReviewDB) -> dict:
    photos = (
        db.query(ServiceOrderReviewPhotoDB)
        .filter(ServiceOrderReviewPhotoDB.review_id == r.id)
        .all()
    )
    client = db.query(ClientDB).filter(ClientDB.id == r.client_id).first()
    return {
        "id": r.id,
        "order_id": r.order_id,
        "master_id": r.master_id,
        "client_id": r.client_id,
        "client_name": (client.name if client else "") or "Клиент",
        "rating": int(r.rating),
        "comment": r.comment or "",
        "created_at": r.created_at or "",
        "photos": [p.photo_url for p in photos if p.photo_url],
    }


def list_master_reviews(master_id: int, db: Session) -> List[dict]:
    rows = (
        db.query(ServiceOrderReviewDB)
        .filter(ServiceOrderReviewDB.master_id == master_id)
        .order_by(ServiceOrderReviewDB.id.desc())
        .limit(100)
        .all()
    )
    return [_review_out(db, r) for r in rows]


def _order_out(
    db: Session,
    o: ServiceOrderDB,
    *,
    include_client_contact: bool = False,
    include_precise_location: bool = False,
    include_master: bool = False,
    include_master_phone: bool = False,
    service_title: str = "",
    category_name: str = "",
) -> dict:
    address_text = o.address or ""
    out = {
        "id": o.id,
        "client_id": o.client_id,
        "service_id": o.service_id,
        "service_title": service_title,
        "category_name": category_name,
        "master_id": o.master_id,
        "address": address_text,
        "address_text": address_text,
        "comment": o.comment or "",
        "scheduled_date": getattr(o, "scheduled_date", None) or "",
        "scheduled_time": getattr(o, "scheduled_time", None) or "",
        "status": o.status,
        "price_client": float(o.price_client or 0),
        "commission_fee": float(o.commission_fee or 0),
        "created_at": o.created_at or "",
        "photos": _order_photos(db, o.id),
        "has_location": getattr(o, "latitude", None) is not None
        and getattr(o, "longitude", None) is not None,
        "has_review": _order_has_review(db, o.id),
    }
    if include_client_contact:
        out["client_name"] = o.client_name or ""
        out["client_phone"] = o.client_phone or ""
    if include_precise_location:
        lat = getattr(o, "latitude", None)
        lng = getattr(o, "longitude", None)
        out["latitude"] = float(lat) if lat is not None else None
        out["longitude"] = float(lng) if lng is not None else None
    if include_master and o.master_id:
        summary = _master_summary(db, o.master_id, include_phone=include_master_phone)
        if summary:
            out["master"] = summary
    return out


# ---------- public / client ----------

class ServiceOrderCreate(BaseModel):
    service_id: int
    address: str = ""
    address_text: str = ""
    comment: str = ""
    scheduled_date: str = Field(..., min_length=8, max_length=32)  # YYYY-MM-DD
    scheduled_time: str = Field(..., min_length=4, max_length=16)  # HH:MM
    latitude: float
    longitude: float
    photos_base64: List[str] = []


class ServiceOrderReviewCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    comment: str = ""
    photos_base64: List[str] = []


@router.get("/service-catalog/categories")
def list_categories(db: Session = Depends(get_db)):
    seed_service_catalog_if_empty(db)
    rows = (
        db.query(ServiceCategoryDB)
        .filter(ServiceCategoryDB.is_active == 1)
        .order_by(ServiceCategoryDB.name.asc())
        .all()
    )
    return [_category_out(c) for c in rows]


@router.get("/service-catalog")
def list_services(
    category_id: Optional[int] = None,
    q: Optional[str] = None,
    db: Session = Depends(get_db),
):
    seed_service_catalog_if_empty(db)
    query = db.query(ServiceCatalogDB).filter(ServiceCatalogDB.is_active == 1)
    if category_id:
        query = query.filter(ServiceCatalogDB.category_id == category_id)
    if q and q.strip():
        from sqlalchemy import func
        like = f"%{q.strip().lower()}%"
        query = query.filter(func.lower(ServiceCatalogDB.title).like(like))
    rows = query.order_by(ServiceCatalogDB.title.asc()).all()
    cats = {
        c.id: c.name
        for c in db.query(ServiceCategoryDB).filter(
            ServiceCategoryDB.id.in_({r.category_id for r in rows} or {-1})
        ).all()
    }
    return [_service_out(s, cats.get(s.category_id, "")) for s in rows]


@router.post("/service-orders")
def create_service_order(
    body: ServiceOrderCreate,
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    seed_service_catalog_if_empty(db)
    svc = db.query(ServiceCatalogDB).filter(ServiceCatalogDB.id == body.service_id).first()
    if not svc or not svc.is_active:
        raise HTTPException(status_code=404, detail="Услуга не найдена или отключена")

    date_s = (body.scheduled_date or "").strip()
    time_s = (body.scheduled_time or "").strip()
    if not date_s or not time_s:
        raise HTTPException(status_code=400, detail="Укажите дату и время")

    address_text = (body.address_text or body.address or "").strip()
    if len(address_text) < 3:
        raise HTTPException(status_code=400, detail="Укажите текстовый ориентир")

    try:
        lat = float(body.latitude)
        lng = float(body.longitude)
    except (TypeError, ValueError):
        raise HTTPException(status_code=400, detail="Укажите точку на карте")
    # Истаравшан и окрестности (мягкие границы Таджикистана)
    if not (36.5 <= lat <= 41.5 and 67.0 <= lng <= 75.5):
        raise HTTPException(status_code=400, detail="Точка вне допустимого региона")

    order = ServiceOrderDB(
        client_id=client.id,
        service_id=svc.id,
        master_id=None,
        address=address_text,
        comment=(body.comment or "").strip(),
        scheduled_date=date_s,
        scheduled_time=time_s,
        latitude=lat,
        longitude=lng,
        status="NEW",
        price_client=float(svc.price_client or 0),
        commission_fee=float(svc.commission_fee or 0),
        client_name=(client.name or "").strip(),
        client_phone=(client.phone or "").strip(),
        created_at=_now(),
    )
    db.add(order)
    db.flush()

    for raw in (body.photos_base64 or [])[:5]:
        data = _decode_photo(raw)
        if not data:
            continue
        try:
            url = save_upload_as_webp(data)
        except Exception:
            continue
        if url:
            db.add(ServiceOrderPhotoDB(order_id=order.id, image_url=url))

    db.commit()
    db.refresh(order)
    cat = db.query(ServiceCategoryDB).filter(ServiceCategoryDB.id == svc.category_id).first()
    return _order_out(
        db,
        order,
        include_client_contact=True,
        include_precise_location=True,
        service_title=svc.title,
        category_name=cat.name if cat else "",
    )


@router.get("/service-orders/my")
def my_service_orders(
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(ServiceOrderDB)
        .filter(ServiceOrderDB.client_id == client.id)
        .order_by(ServiceOrderDB.id.desc())
        .limit(100)
        .all()
    )
    return [
        _enrich_order(
            db,
            o,
            include_contact=True,
            include_location=True,
            include_master=True,
            include_master_phone=True,
        )
        for o in rows
    ]


def _enrich_order(
    db: Session,
    o: ServiceOrderDB,
    *,
    include_contact: bool,
    include_location: bool = False,
    include_master: bool = False,
    include_master_phone: bool = False,
) -> dict:
    svc = db.query(ServiceCatalogDB).filter(ServiceCatalogDB.id == o.service_id).first()
    cat_name = ""
    title = ""
    if svc:
        title = svc.title
        cat = db.query(ServiceCategoryDB).filter(ServiceCategoryDB.id == svc.category_id).first()
        cat_name = cat.name if cat else ""
    return _order_out(
        db,
        o,
        include_client_contact=include_contact,
        include_precise_location=include_location,
        include_master=include_master,
        include_master_phone=include_master_phone,
        service_title=title,
        category_name=cat_name,
    )


# ---------- master ----------

@router.get("/service-orders/feed")
def master_orders_feed(
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(ServiceOrderDB)
        .filter(ServiceOrderDB.status == "NEW")
        .order_by(ServiceOrderDB.id.desc())
        .limit(100)
        .all()
    )
    # Лента: только ориентир, без точных координат.
    return [_enrich_order(db, o, include_contact=False, include_location=False) for o in rows]


@router.get("/service-orders/{order_id}")
def get_service_order(
    order_id: int,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    o = db.query(ServiceOrderDB).filter(ServiceOrderDB.id == order_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    allowed = o.master_id == master.id and o.status != "NEW"
    return _enrich_order(
        db,
        o,
        include_contact=allowed,
        include_location=allowed,
    )


@router.post("/service-orders/{order_id}/accept")
def accept_service_order(
    order_id: int,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """Принять заказ и открыть контакты + координаты (комиссия временно отключена)."""
    o = db.query(ServiceOrderDB).filter(ServiceOrderDB.id == order_id).first()
    if not o:
        raise HTTPException(status_code=404, detail="Заказ не найден")

    if o.master_id == master.id and o.status == "IN_PROGRESS":
        return {
            "status": "success",
            "already_accepted": True,
            "order": _enrich_order(db, o, include_contact=True, include_location=True),
        }

    if o.status != "NEW" or o.master_id is not None:
        raise HTTPException(status_code=409, detail="Заказ уже взят или недоступен")

    o.master_id = master.id
    o.status = "IN_PROGRESS"
    db.commit()
    db.refresh(o)
    return {
        "status": "success",
        "order": _enrich_order(db, o, include_contact=True, include_location=True),
    }


@router.get("/masters/me/balance")
def my_balance(
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    bal = ensure_master_balance(db, master.id)
    return {"balance": float(bal.balance or 0), "currency": "TJS"}


@router.get("/masters/me/balance/transactions")
def my_balance_transactions(
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    ensure_master_balance(db, master.id)
    rows = (
        db.query(BalanceTransactionDB)
        .filter(BalanceTransactionDB.master_id == master.id)
        .order_by(BalanceTransactionDB.id.desc())
        .limit(100)
        .all()
    )
    return [
        {
            "id": t.id,
            "amount": float(t.amount or 0),
            "type": t.type,
            "order_id": t.order_id,
            "note": t.note or "",
            "created_at": t.created_at or "",
        }
        for t in rows
    ]


@router.post("/service-orders/{order_id}/status")
def client_update_order_status(
    order_id: int,
    body: dict,
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    status = str((body or {}).get("status") or "").upper()
    if status not in {"COMPLETED", "CANCELLED"}:
        raise HTTPException(status_code=400, detail="Допустимо: COMPLETED или CANCELLED")
    o = db.query(ServiceOrderDB).filter(ServiceOrderDB.id == order_id).first()
    if not o or o.client_id != client.id:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    if o.status == "CANCELLED":
        raise HTTPException(status_code=409, detail="Заказ уже отменён")
    if status == "CANCELLED" and o.status == "COMPLETED":
        raise HTTPException(status_code=409, detail="Завершённый заказ нельзя отменить")
    if status == "COMPLETED" and o.status not in {"IN_PROGRESS", "COMPLETED"}:
        raise HTTPException(status_code=409, detail="Заказ ещё не принят мастером")
    o.status = status
    db.commit()
    return _enrich_order(
        db,
        o,
        include_contact=True,
        include_location=True,
        include_master=True,
        include_master_phone=True,
    )


@router.post("/service-orders/{order_id}/review")
def create_service_order_review(
    order_id: int,
    body: ServiceOrderReviewCreate,
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    o = db.query(ServiceOrderDB).filter(ServiceOrderDB.id == order_id).first()
    if not o or o.client_id != client.id:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    if not o.master_id:
        raise HTTPException(status_code=409, detail="Мастер ещё не назначен")
    if o.status not in {"IN_PROGRESS", "COMPLETED"}:
        raise HTTPException(status_code=409, detail="Нельзя оценить этот заказ")
    if _order_has_review(db, o.id):
        raise HTTPException(status_code=409, detail="Отзыв уже оставлен")

    if o.status != "COMPLETED":
        o.status = "COMPLETED"

    review = ServiceOrderReviewDB(
        order_id=o.id,
        master_id=o.master_id,
        client_id=client.id,
        rating=int(body.rating),
        comment=(body.comment or "").strip(),
        created_at=_now(),
    )
    db.add(review)
    db.flush()

    for raw in (body.photos_base64 or [])[:4]:
        data = _decode_photo(raw)
        if not data:
            continue
        try:
            url = save_upload_as_webp(data)
        except Exception:
            continue
        if url:
            db.add(ServiceOrderReviewPhotoDB(review_id=review.id, photo_url=url))

    _recalc_master_rating(db, o.master_id)
    db.commit()
    db.refresh(review)
    return {
        "status": "success",
        "review": _review_out(db, review),
        "order": _enrich_order(
            db,
            o,
            include_contact=True,
            include_location=True,
            include_master=True,
            include_master_phone=True,
        ),
    }


@router.get("/masters/{master_id}/reviews")
def master_reviews_public(master_id: int, db: Session = Depends(get_db)):
    m = db.query(MasterDB).filter(MasterDB.id == master_id).first()
    if not m:
        raise HTTPException(status_code=404, detail="Мастер не найден")
    # Дубликат анкеты → отзывы канонического мастера (тот же, что принимает заказы)
    target = getattr(m, "merged_into_master_id", None)
    if target:
        master_id = int(target)
        m2 = db.query(MasterDB).filter(MasterDB.id == master_id).first()
        if not m2:
            raise HTTPException(status_code=404, detail="Мастер не найден")
    return list_master_reviews(master_id, db)
