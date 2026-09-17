"""
Биржа заявок на услуги мастеров (service_requests).
Не связана с магазинными orders (OrderDB).
"""

from __future__ import annotations

import base64
import json
import re
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import or_
from sqlalchemy.orm import Session

from auth import get_current_client, get_master_for_me
from database import (
    ClientDB,
    MasterDB,
    ServiceRequestDB,
    ServiceRequestPhotoDB,
    ServiceRequestResponseDB,
    get_db,
)
from image_utils import save_upload_as_webp

router = APIRouter(tags=["service-requests"])

VALID_STATUSES = {"open", "in_progress", "completed", "cancelled"}


class ServiceRequestCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=150)
    category: str = Field(..., min_length=1, max_length=128)
    description: str = ""
    address: str = ""
    city: str = ""
    budget: Optional[float] = None
    # data-url или чистый base64 jpeg/png/webp
    photos_base64: List[str] = []


class ServiceRequestStatusBody(BaseModel):
    status: str


class ServiceRequestRespondBody(BaseModel):
    proposed_price: Optional[float] = None
    comment: str = ""


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


def _master_categories(m: MasterDB) -> List[str]:
    try:
        raw = getattr(m, "categories_json", None) or "[]"
        data = json.loads(raw) if isinstance(raw, str) else raw
        if isinstance(data, list):
            return [str(x).strip() for x in data if str(x).strip()]
    except Exception:
        pass
    return []


def _serialize_request(
    r: ServiceRequestDB,
    db: Session,
    *,
    include_client_contact: bool = False,
    master_id: Optional[int] = None,
) -> dict:
    photos = [
        p.image_url
        for p in db.query(ServiceRequestPhotoDB)
        .filter(ServiceRequestPhotoDB.request_id == r.id)
        .all()
    ]
    responses_q = (
        db.query(ServiceRequestResponseDB)
        .filter(ServiceRequestResponseDB.request_id == r.id)
        .order_by(ServiceRequestResponseDB.id.desc())
        .all()
    )
    responses = []
    for resp in responses_q:
        master = db.query(MasterDB).filter(MasterDB.id == resp.master_id).first()
        responses.append(
            {
                "id": resp.id,
                "master_id": resp.master_id,
                "master_name": (master.name if master else ""),
                "master_phone": (master.phone if master else ""),
                "proposed_price": resp.proposed_price,
                "comment": resp.comment or "",
                "created_at": resp.created_at or "",
            }
        )

    out = {
        "id": r.id,
        "category": r.category or "",
        "title": r.title,
        "description": r.description or "",
        "address": r.address or "",
        "city": r.city or "",
        "budget": r.budget,
        "status": r.status or "open",
        "created_at": r.created_at or "",
        "photos": photos,
        "responses_count": len(responses),
        "responses": responses,
        "my_response": None,
    }
    if include_client_contact:
        out["client_name"] = r.client_name or ""
        out["client_phone"] = r.client_phone or ""
        out["client_id"] = r.client_id
    else:
        # в ленте мастера показываем имя, телефон — для звонка/WA
        out["client_name"] = r.client_name or ""
        out["client_phone"] = r.client_phone or ""

    if master_id is not None:
        mine = next((x for x in responses if x["master_id"] == master_id), None)
        out["my_response"] = mine
    return out


@router.post("/service-requests")
def create_service_request(
    body: ServiceRequestCreate,
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    title = body.title.strip()
    category = body.category.strip()
    if not title or not category:
        raise HTTPException(status_code=400, detail="title and category required")

    req = ServiceRequestDB(
        client_id=client.id,
        category=category,
        title=title,
        description=(body.description or "").strip(),
        address=(body.address or "").strip(),
        city=(body.city or "").strip(),
        budget=body.budget,
        client_name=(client.name or "").strip(),
        client_phone=(client.phone or "").strip(),
        status="open",
        created_at=_now(),
    )
    db.add(req)
    db.commit()
    db.refresh(req)

    for raw in (body.photos_base64 or [])[:8]:
        data = _decode_photo(raw)
        if not data:
            continue
        path = save_upload_as_webp(data)
        if not path:
            continue
        db.add(ServiceRequestPhotoDB(request_id=req.id, image_url=path))
    db.commit()

    return {"status": "success", "request": _serialize_request(req, db, include_client_contact=True)}


@router.get("/service-requests/my")
def my_client_requests(
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(ServiceRequestDB)
        .filter(ServiceRequestDB.client_id == client.id)
        .order_by(ServiceRequestDB.id.desc())
        .all()
    )
    return {
        "status": "success",
        "items": [_serialize_request(r, db, include_client_contact=True) for r in rows],
    }


@router.post("/service-requests/{request_id}/status")
def update_request_status(
    request_id: int,
    body: ServiceRequestStatusBody,
    client: ClientDB = Depends(get_current_client),
    db: Session = Depends(get_db),
):
    status_val = (body.status or "").strip().lower()
    if status_val not in VALID_STATUSES:
        raise HTTPException(status_code=400, detail="invalid status")
    req = db.query(ServiceRequestDB).filter(ServiceRequestDB.id == request_id).first()
    if not req or req.client_id != client.id:
        raise HTTPException(status_code=404, detail="not found")
    req.status = status_val
    db.commit()
    return {"status": "success", "request": _serialize_request(req, db, include_client_contact=True)}


@router.get("/service-requests/open")
def public_open_requests(
    db: Session = Depends(get_db),
    city: Optional[str] = None,
    limit: int = 12,
):
    """Публичная лента открытых заявок для главной веб-страницы (без телефонов)."""
    lim = max(1, min(int(limit or 12), 40))
    q = db.query(ServiceRequestDB).filter(ServiceRequestDB.status == "open")
    city_f = (city or "").strip()
    if city_f:
        city_clean = re.sub(r"^г\.\s*", "", city_f, flags=re.IGNORECASE)
        q = q.filter(
            or_(
                ServiceRequestDB.city == "",
                ServiceRequestDB.city.is_(None),
                ServiceRequestDB.city.like(f"%{city_clean}%"),
            )
        )
    rows = q.order_by(ServiceRequestDB.id.desc()).limit(lim).all()
    items = []
    for r in rows:
        data = _serialize_request(r, db, include_client_contact=False)
        items.append(data)
    return {"status": "success", "items": items}


@router.get("/service-requests/feed")
def master_feed(
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
    city: Optional[str] = None,
):
    q = db.query(ServiceRequestDB).filter(ServiceRequestDB.status == "open")
    city_f = (city or getattr(master, "city", None) or "").strip()
    if city_f:
        city_clean = re.sub(r"^г\.\s*", "", city_f, flags=re.IGNORECASE)
        q = q.filter(
            or_(
                ServiceRequestDB.city == "",
                ServiceRequestDB.city.is_(None),
                ServiceRequestDB.city.like(f"%{city_clean}%"),
            )
        )

    cats = _master_categories(master)
    rows = q.order_by(ServiceRequestDB.id.desc()).limit(100).all()
    if cats:
        cats_l = [c.lower() for c in cats]
        filtered = [
            r
            for r in rows
            if not r.category
            or any(c in (r.category or "").lower() or (r.category or "").lower() in c for c in cats_l)
        ]
        # если после фильтра пусто — показать все open (чтобы лента не была пустой)
        rows = filtered or rows

    return {
        "status": "success",
        "items": [
            _serialize_request(r, db, include_client_contact=True, master_id=master.id)
            for r in rows
        ],
    }


@router.get("/service-requests/{request_id}")
def get_request(
    request_id: int,
    db: Session = Depends(get_db),
    master: MasterDB = Depends(get_master_for_me),
):
    req = db.query(ServiceRequestDB).filter(ServiceRequestDB.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="not found")
    return {
        "status": "success",
        "request": _serialize_request(req, db, include_client_contact=True, master_id=master.id),
    }


@router.post("/service-requests/{request_id}/respond")
def respond_to_request(
    request_id: int,
    body: ServiceRequestRespondBody,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    req = db.query(ServiceRequestDB).filter(ServiceRequestDB.id == request_id).first()
    if not req or req.status != "open":
        raise HTTPException(status_code=404, detail="request not open")

    existing = (
        db.query(ServiceRequestResponseDB)
        .filter(
            ServiceRequestResponseDB.request_id == request_id,
            ServiceRequestResponseDB.master_id == master.id,
        )
        .first()
    )
    if existing:
        existing.proposed_price = body.proposed_price
        existing.comment = (body.comment or "").strip()
        existing.created_at = _now()
    else:
        db.add(
            ServiceRequestResponseDB(
                request_id=request_id,
                master_id=master.id,
                proposed_price=body.proposed_price,
                comment=(body.comment or "").strip(),
                created_at=_now(),
            )
        )
    db.commit()
    return {
        "status": "success",
        "request": _serialize_request(req, db, include_client_contact=True, master_id=master.id),
    }


@router.post("/service-requests/{request_id}/convert-to-crm")
def convert_to_crm_payload(
    request_id: int,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    """Возвращает данные для создания локального объекта CRM (Hive) на устройстве мастера."""
    req = db.query(ServiceRequestDB).filter(ServiceRequestDB.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="not found")
    return {
        "status": "success",
        "crm": {
            "title": req.title,
            "client": req.client_name or "",
            "phone": req.client_phone or "",
            "address": req.address or "",
            "note": (req.description or "").strip(),
            "income": float(req.budget or 0),
            "category": req.category or "",
            "source_request_id": req.id,
        },
    }
