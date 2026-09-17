"""
Публикация объявления мастера в каталог (через приложение) → модерация админом.
Обязательно: name, category, photo. Остальное опционально.
"""

from __future__ import annotations

import base64
import json
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from auth import get_master_for_me
from database import MasterDB, get_db
from image_utils import save_upload_as_webp

router = APIRouter(tags=["master-listing"])

BASE_CATEGORIES = ["Сантехник", "Электрик", "Маляр", "Плиточник", "Сварщик", "Евроремонт", "Разнорабочий", "Алюкобонд"]


class MasterListingSubmit(BaseModel):
    name: str = Field(..., min_length=2, max_length=120)
    category: str = Field(..., min_length=1, max_length=128)
    description: str = ""
    city: str = ""
    experience: Optional[int] = None
    # главное фото: обязательно для первой публикации; при правке можно оставить пустым
    photo_base64: str = ""
    portfolio_base64: List[str] = []


def _decode_b64(raw: str) -> Optional[bytes]:
    s = (raw or "").strip()
    if not s:
        return None
    if "," in s and s.lower().startswith("data:"):
        s = s.split(",", 1)[1]
    try:
        return base64.b64decode(s, validate=False)
    except Exception:
        return None


def _parse_list(raw) -> list:
    try:
        data = json.loads(raw) if isinstance(raw, str) else (raw or [])
        return data if isinstance(data, list) else []
    except Exception:
        return []


def _listing_out(m: MasterDB) -> dict:
    return {
        "id": m.id,
        "name": m.name or "",
        "phone": m.phone or "",
        "description": m.description or "",
        "city": getattr(m, "city", None) or "",
        "experience": int(m.experience or 0),
        "image": m.image or "",
        "categories": _parse_list(m.categories_json),
        "portfolio": _parse_list(m.portfolio_json),
        "moderation_status": getattr(m, "moderation_status", None) or "draft",
        "moderation_note": getattr(m, "moderation_note", None) or "",
    }


@router.get("/masters/me/listing")
def get_my_listing(master: MasterDB = Depends(get_master_for_me), db: Session = Depends(get_db)):
    # refresh from db
    m = db.query(MasterDB).filter(MasterDB.id == master.id).first()
    if not m:
        raise HTTPException(status_code=404, detail="not found")
    return {"status": "success", "listing": _listing_out(m), "categories": BASE_CATEGORIES}


@router.post("/masters/me/listing")
def submit_my_listing(
    body: MasterListingSubmit,
    master: MasterDB = Depends(get_master_for_me),
    db: Session = Depends(get_db),
):
    m = db.query(MasterDB).filter(MasterDB.id == master.id).first()
    if not m:
        raise HTTPException(status_code=404, detail="not found")

    name = body.name.strip()
    category = body.category.strip()
    if len(name) < 2:
        raise HTTPException(status_code=400, detail="Укажите название / имя")
    if not category:
        raise HTTPException(status_code=400, detail="Укажите категорию")

    photo_bytes = _decode_b64(body.photo_base64)
    image_path = None
    if photo_bytes:
        image_path = save_upload_as_webp(photo_bytes)
        if not image_path:
            raise HTTPException(status_code=400, detail="Не удалось обработать фото")
    elif not (m.image or "").strip():
        raise HTTPException(status_code=400, detail="Добавьте фото")

    portfolio = []
    for raw in (body.portfolio_base64 or [])[:8]:
        data = _decode_b64(raw)
        if not data:
            continue
        path = save_upload_as_webp(data)
        if path:
            portfolio.append(path)

    m.name = name
    m.description = (body.description or "").strip()
    m.city = (body.city or "").strip()
    if body.experience is not None and body.experience >= 0:
        m.experience = int(body.experience)
    m.categories_json = json.dumps([category], ensure_ascii=False)
    if image_path:
        m.image = image_path
    if portfolio:
        # дополняем существующее портфолио
        existing = _parse_list(m.portfolio_json)
        m.portfolio_json = json.dumps((existing + portfolio)[:12], ensure_ascii=False)
    m.moderation_status = "pending"
    m.moderation_note = ""
    db.commit()
    db.refresh(m)

    return {
        "status": "success",
        "message": "Отправлено на модерацию",
        "listing": _listing_out(m),
    }
