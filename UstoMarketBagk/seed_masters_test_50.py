"""
Тестовые мастера: 50 записей с разными специализациями, услугами и фото работ.

Запуск из папки UstoMarketBagk (нужен настроенный DATABASE_URL в .env):
  python seed_masters_test_50.py
  python seed_masters_test_50.py --count 50
  python seed_masters_test_50.py --no-download    # без скачивания фото (быстро)
  python seed_masters_test_50.py --clear          # удалить ранее созданных тест-мастеров

Тестовые телефоны: +992 93 550 00 XX (phone_norm: 9355000XX).
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import time

import requests

from database import Base, MasterDB, SessionLocal, engine

try:
    from image_utils import save_upload_as_webp
except ImportError:
    save_upload_as_webp = None  # type: ignore

# phone_norm: 935500001 … 935500050 — легко найти и удалить тестовых мастеров
TEST_PHONE_NORM_PREFIX = "9355000"

FIRST_NAMES = [
    "Алишер", "Джамшед", "Рустам", "Исмоил", "Далер", "Парвиз", "Фарход",
    "Собир", "Умед", "Акмал", "Бахром", "Зафар", "Шерали", "Тимур", "Ильхом",
    "Азиз", "Бобур", "Дониёр", "Жасур", "Камол", "Лохиджон", "Мунир", "Нозим",
    "Фирдавс", "Хуршед", "Шохрух", "Эмомали", "Юсуф", "Якуб", "Навруз",
]

LAST_NAMES = [
    "Алиев", "Каримов", "Рахимов", "Назаров", "Саидов", "Джураев",
    "Турсунов", "Исломов", "Ходжаев", "Бобоев", "Курбонов", "Юсупов",
    "Мирзоев", "Гафуров", "Шарипов", "Амонов", "Бердиев", "Касымов",
]

PROFESSIONS: dict[str, dict] = {
    "Сантехник": {
        "services": [
            {"name": "Установка смесителя", "price": 50, "unit": "шт"},
            {"name": "Монтаж труб", "price": 20, "unit": "м"},
            {"name": "Установка унитаза", "price": 100, "unit": "шт"},
            {"name": "Устранение засора", "price": 80, "unit": "услуга"},
            {"name": "Подключение стиральной машины", "price": 70, "unit": "шт"},
            {"name": "Монтаж водонагревателя", "price": 120, "unit": "шт"},
        ],
        "desc": "Сантехника любой сложности. Выезд в день обращения.",
        "photo_seed": "ustobozor-plumber",
    },
    "Электрик": {
        "services": [
            {"name": "Установка розетки", "price": 15, "unit": "шт"},
            {"name": "Монтаж проводки", "price": 10, "unit": "м"},
            {"name": "Сборка электрощита", "price": 200, "unit": "шт"},
            {"name": "Установка люстры", "price": 60, "unit": "шт"},
            {"name": "Поиск неисправности", "price": 100, "unit": "услуга"},
            {"name": "Монтаж автоматов", "price": 25, "unit": "шт"},
        ],
        "desc": "Электромонтаж в квартирах и домах. Сертифицированный мастер.",
        "photo_seed": "ustobozor-electric",
    },
    "Маляр-Штукатур": {
        "services": [
            {"name": "Шпатлевка стен", "price": 25, "unit": "кв.м"},
            {"name": "Покраска стен", "price": 20, "unit": "кв.м"},
            {"name": "Поклейка обоев", "price": 30, "unit": "кв.м"},
            {"name": "Грунтовка", "price": 5, "unit": "кв.м"},
            {"name": "Штукатурка под маяк", "price": 40, "unit": "кв.м"},
            {"name": "Декоративная штукатурка", "price": 55, "unit": "кв.м"},
        ],
        "desc": "Ровные стены и аккуратная отделка. Свой инструмент и материалы по запросу.",
        "photo_seed": "ustobozor-painter",
    },
    "Плиточник": {
        "services": [
            {"name": "Укладка кафеля (пол)", "price": 60, "unit": "кв.м"},
            {"name": "Укладка кафеля (стены)", "price": 70, "unit": "кв.м"},
            {"name": "Затирка швов", "price": 10, "unit": "кв.м"},
            {"name": "Резка плитки (угол 45°)", "price": 15, "unit": "м"},
            {"name": "Гидроизоляция", "price": 35, "unit": "кв.м"},
            {"name": "Мозаика", "price": 90, "unit": "кв.м"},
        ],
        "desc": "Кафель, керамогранит, мозаика. Гарантия на укладку.",
        "photo_seed": "ustobozor-tiler",
    },
    "Сварщик": {
        "services": [
            {"name": "Сварка труб", "price": 50, "unit": "шов"},
            {"name": "Изготовление ворот", "price": 500, "unit": "кв.м"},
            {"name": "Монтаж навеса", "price": 150, "unit": "кв.м"},
            {"name": "Сварка арматуры", "price": 40, "unit": "м"},
            {"name": "Ремонт металлоконструкций", "price": 120, "unit": "услуга"},
        ],
        "desc": "Сварочные работы, металлоконструкции, заборы и навесы.",
        "photo_seed": "ustobozor-welder",
    },
    "Плотник": {
        "services": [
            {"name": "Установка двери", "price": 150, "unit": "шт"},
            {"name": "Укладка ламината", "price": 25, "unit": "кв.м"},
            {"name": "Монтаж плинтуса", "price": 10, "unit": "м"},
            {"name": "Сборка мебели", "price": 80, "unit": "услуга"},
            {"name": "Установка окон", "price": 200, "unit": "шт"},
        ],
        "desc": "Двери, полы, мебель. Точные замеры и аккуратный монтаж.",
        "photo_seed": "ustobozor-carpenter",
    },
    "Кровельщик": {
        "services": [
            {"name": "Монтаж металлочерепицы", "price": 45, "unit": "кв.м"},
            {"name": "Ремонт крыши", "price": 35, "unit": "кв.м"},
            {"name": "Утепление кровли", "price": 40, "unit": "кв.м"},
            {"name": "Монтаж водостоков", "price": 25, "unit": "м"},
        ],
        "desc": "Кровельные работы, утепление, водосточные системы.",
        "photo_seed": "ustobozor-roofer",
    },
    "Мастер по ГКЛ": {
        "services": [
            {"name": "Монтаж каркаса", "price": 30, "unit": "кв.м"},
            {"name": "Обшивка ГКЛ", "price": 35, "unit": "кв.м"},
            {"name": "Арочные конструкции", "price": 120, "unit": "шт"},
            {"name": "Шумоизоляция", "price": 25, "unit": "кв.м"},
        ],
        "desc": "Перегородки, потолки, ниши из гипсокартона.",
        "photo_seed": "ustobozor-drywall",
    },
    "Слесарь": {
        "services": [
            {"name": "Ремонт замков", "price": 60, "unit": "шт"},
            {"name": "Установка решёток", "price": 90, "unit": "шт"},
            {"name": "Сборка каркасов", "price": 70, "unit": "услуга"},
            {"name": "Мелкий ремонт", "price": 50, "unit": "час"},
        ],
        "desc": "Слесарные работы, замки, металлоизделия.",
        "photo_seed": "ustobozor-locksmith",
    },
    "Мастер по натяжным потолкам": {
        "services": [
            {"name": "Натяжной потолок", "price": 55, "unit": "кв.м"},
            {"name": "Многоуровневый потолок", "price": 75, "unit": "кв.м"},
            {"name": "Монтаж светильников", "price": 20, "unit": "шт"},
            {"name": "Обход труб", "price": 15, "unit": "шт"},
        ],
        "desc": "Натяжные потолки любой сложности, замер бесплатно.",
        "photo_seed": "ustobozor-ceiling",
    },
}

EXTRA_DESCRIPTIONS = [
    "Опыт работы более 10 лет. Качество гарантирую.",
    "Работаю быстро и аккуратно. Свой инструмент.",
    "Бригада мастеров. Выполняем любые объёмы.",
    "Мастер на час. Выезд в любой район города.",
    "Профессиональный подход. Гарантия на все виды работ.",
    "Помогу с закупкой материалов со скидкой в Ustobozor.",
    "Работаю по договорённости, без предоплаты.",
]


def _picsum_url(seed: str, width: int = 800, height: int = 600) -> str:
    safe = "".join(c if c.isalnum() or c in "-_" else "-" for c in seed)
    return f"https://picsum.photos/seed/{safe}/{width}/{height}"


def _download_photo(seed: str, *, width: int = 800, height: int = 600) -> str | None:
    """Скачивает фото и сохраняет в static/images/*.webp. Возвращает относительный путь."""
    url = _picsum_url(seed, width, height)
    try:
        resp = requests.get(url, timeout=20, allow_redirects=True)
        resp.raise_for_status()
        data = resp.content
    except requests.RequestException as exc:
        print(f"  [!] не удалось скачать {url}: {exc}")
        return None

    if save_upload_as_webp:
        path = save_upload_as_webp(data)
        if path:
            return path.replace("\\", "/")

    # fallback: сохранить как jpg без конвертации
    os.makedirs(os.path.join("static", "images"), exist_ok=True)
    safe = "".join(c if c.isalnum() else "-" for c in seed)[:40]
    fname = f"seed_{safe}_{int(time.time() * 1000) % 100000}.jpg"
    rel = f"static/images/{fname}"
    with open(rel, "wb") as f:
        f.write(data)
    return rel


def _test_phone(index: int) -> tuple[str, str]:
    """index: 1..99 → phone_norm 935500001 … 935500099 (9 цифр)."""
    if index < 1 or index > 99:
        raise ValueError("index must be 1..99")
    phone_norm = f"{TEST_PHONE_NORM_PREFIX}{index:02d}"
    # +992 93 550 00 01
    d = phone_norm  # 935500001
    phone = f"+992 {d[0:2]} {d[2:5]} {d[5:7]} {d[7:9]}"
    return phone, phone_norm


def _pick_services(profession_key: str, rng: random.Random) -> list[dict]:
    pool = PROFESSIONS[profession_key]["services"]
    k = rng.randint(3, min(6, len(pool)))
    return rng.sample(pool, k=k)


def _pick_categories(profession_key: str, all_keys: list[str], rng: random.Random) -> list[str]:
    cats = [profession_key]
    if rng.random() > 0.75:
        other = rng.choice([k for k in all_keys if k != profession_key])
        cats.append(other)
    return cats


def clear_test_masters(db) -> int:
    rows = (
        db.query(MasterDB)
        .filter(MasterDB.phone_norm.like(f"{TEST_PHONE_NORM_PREFIX}%"))
        .all()
    )
    for m in rows:
        db.delete(m)
    db.commit()
    return len(rows)


def seed_masters(*, count: int = 50, download_images: bool = True, replace: bool = False) -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    rng = random.Random(42)

    if replace:
        removed = clear_test_masters(db)
        if removed:
            print(f"[DEL] Удалено старых тест-мастеров: {removed}")

    profession_keys = list(PROFESSIONS.keys())
    created = 0
    skipped = 0

    print(f"Добавление {count} тестовых мастеров (фото: {'да' if download_images else 'нет'})...")

    for i in range(1, count + 1):
        phone, phone_norm = _test_phone(i)

        existing = db.query(MasterDB).filter(MasterDB.phone_norm == phone_norm).first()
        if existing:
            print(f"  [skip] [{i}/{count}] уже есть: {existing.name} ({phone})")
            skipped += 1
            continue

        profession_key = profession_keys[(i - 1) % len(profession_keys)]
        prof = PROFESSIONS[profession_key]
        name = f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}"
        categories = _pick_categories(profession_key, profession_keys, rng)
        services = _pick_services(profession_key, rng)
        description = f"{prof['desc']} {rng.choice(EXTRA_DESCRIPTIONS)}"
        experience = rng.randint(2, 22)
        rating = round(rng.uniform(3.8, 5.0), 1)

        avatar = ""
        portfolio: list[str] = []

        if download_images:
            avatar = _download_photo(f"{prof['photo_seed']}-avatar-{i}", width=600, height=600) or ""
            portfolio_count = rng.randint(3, 5)
            for j in range(portfolio_count):
                path = _download_photo(f"{prof['photo_seed']}-work-{i}-{j}", width=900, height=600)
                if path:
                    portfolio.append(path)
                time.sleep(0.15)  # небольшая пауза для picsum

        master = MasterDB(
            name=name,
            phone=phone,
            phone_norm=phone_norm,
            role="user",
            categories_json=json.dumps(categories, ensure_ascii=False),
            description=description,
            experience=experience,
            image=avatar,
            portfolio_json=json.dumps(portfolio, ensure_ascii=False),
            services_json=json.dumps(services, ensure_ascii=False),
            rating=rating,
            points=0,
            debt=0.0,
            barcode="",
            is_password_reset=1,
        )
        db.add(master)
        db.commit()
        created += 1
        print(f"  [ok] [{i}/{count}] {name} — {profession_key}, услуг: {len(services)}, фото: {len(portfolio) + (1 if avatar else 0)}")

    db.close()
    print(f"\nГотово: добавлено {created}, пропущено {skipped} (уже в базе).")
    print("Проверка: GET /masters или вкладка «Мастера» в приложении.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed 50 test masters with services and photos")
    parser.add_argument("--count", type=int, default=50, help="Сколько мастеров создать (по умолчанию 50)")
    parser.add_argument(
        "--no-download",
        action="store_true",
        help="Не скачивать фото (быстрый режим, portfolio пустой)",
    )
    parser.add_argument(
        "--clear",
        action="store_true",
        help="Только удалить тест-мастеров (phone_norm 9350010*)",
    )
    parser.add_argument(
        "--replace",
        action="store_true",
        help="Сначала удалить старых тест-мастеров, затем создать заново",
    )
    args = parser.parse_args()

    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    if args.clear:
        Base.metadata.create_all(bind=engine)
        db = SessionLocal()
        n = clear_test_masters(db)
        db.close()
        print(f"[DEL] Удалено тест-мастеров: {n}")
        if not args.replace:
            return

    if args.count < 1 or args.count > 99:
        print("count должен быть от 1 до 99 (ограничение тестовых телефонов)")
        sys.exit(1)

    seed_masters(
        count=args.count,
        download_images=not args.no_download,
        replace=args.replace,
    )


if __name__ == "__main__":
    main()
