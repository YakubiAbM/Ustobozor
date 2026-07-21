"""
Конвертация загруженных изображений в WebP (Pillow).
Используется при добавлении/редактировании товара в админке.
"""

import io
import os
import uuid
from typing import Optional

from PIL import Image, ImageOps

# Максимальная сторона (px) после ресайза; 0 = не менять размер
MAX_SIDE = 2048
WEBP_QUALITY = 85


def _normalize_mode(im: Image.Image) -> Image.Image:
    im = ImageOps.exif_transpose(im)
    if im.mode == "P":
        im = im.convert("RGBA")
    elif im.mode in ("LA", "L"):
        im = im.convert("RGBA" if im.mode == "LA" else "RGB")
    elif im.mode not in ("RGB", "RGBA"):
        im = im.convert("RGB")
    return im


def bytes_to_webp(data: bytes, *, max_side: int = MAX_SIDE, quality: int = WEBP_QUALITY) -> Optional[bytes]:
    """
    Принимает сырые байты файла (JPEG/PNG/WebP/GIF/BMP и т.д.), возвращает байты WebP.
    При ошибке (не картинка, повреждённый файл) возвращает None.
    """
    if not data:
        return None
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        im = _normalize_mode(im)
        w, h = im.size
        if max_side > 0 and max(w, h) > max_side:
            ratio = max_side / float(max(w, h))
            new_w = max(1, int(w * ratio))
            new_h = max(1, int(h * ratio))
            im = im.resize((new_w, new_h), Image.Resampling.LANCZOS)
        out = io.BytesIO()
        im.save(
            out,
            format="WEBP",
            quality=quality,
            method=6,
        )
        return out.getvalue()
    except Exception as e:
        print(f"[image_utils] bytes_to_webp: {e}")
        return None


def save_upload_as_webp(data: bytes, images_dir: str = os.path.join("static", "images")) -> Optional[str]:
    """
    Сохраняет изображение как {uuid}.webp в images_dir.
    Возвращает относительный путь вида static/images/xxx.webp или None при сбое.
    """
    webp_bytes = bytes_to_webp(data)
    if not webp_bytes:
        return None
    os.makedirs(images_dir, exist_ok=True)
    name = f"{uuid.uuid4().hex}.webp"
    path = os.path.join(images_dir, name)
    with open(path, "wb") as f:
        f.write(webp_bytes)
    rel = os.path.join("static", "images", name).replace("\\", "/")
    return rel
