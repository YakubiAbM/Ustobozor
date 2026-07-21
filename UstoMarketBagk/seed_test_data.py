"""
Тестовые данные: 100 мастеров и 100 стройматериалов с разными категориями.
Запуск: python seed_test_data.py
"""
import random
import json
from database import SessionLocal, MasterDB, ProductDB, Base, engine

# Создаём таблицы, если нет
Base.metadata.create_all(bind=engine)
db = SessionLocal()

# --- Мастера ---
FIRST_NAMES = [
    "Алишер", "Джамшед", "Рустам", "Исмоил", "Далер", "Парвиз", "Фарход",
    "Собир", "Умед", "Акмал", "Бахром", "Зафар", "Шерали", "Тимур", "Ильхом",
    "Азиз", "Бобур", "Дониёр", "Жасур", "Камол", "Лохиджон", "Мунир", "Нозим"
]
LAST_NAMES = [
    "Алиев", "Каримов", "Рахимов", "Назаров", "Саидов", "Джураев",
    "Турсунов", "Исломов", "Ходжаев", "Бобоев", "Курбонов", "Юсупов"
]
PROFESSIONS = {
    "Сантехник": [
        {"name": "Установка смесителя", "price": 50, "unit": "шт"},
        {"name": "Монтаж труб", "price": 20, "unit": "м"},
        {"name": "Установка унитаза", "price": 100, "unit": "шт"},
    ],
    "Электрик": [
        {"name": "Установка розетки", "price": 15, "unit": "шт"},
        {"name": "Монтаж проводки", "price": 10, "unit": "м"},
        {"name": "Установка люстры", "price": 60, "unit": "шт"},
    ],
    "Маляр-Штукатур": [
        {"name": "Шпатлевка стен", "price": 25, "unit": "кв.м"},
        {"name": "Покраска стен", "price": 20, "unit": "кв.м"},
        {"name": "Поклейка обоев", "price": 30, "unit": "кв.м"},
    ],
    "Плиточник": [
        {"name": "Укладка кафеля (пол)", "price": 60, "unit": "кв.м"},
        {"name": "Укладка кафеля (стены)", "price": 70, "unit": "кв.м"},
    ],
    "Плотник": [
        {"name": "Установка двери", "price": 150, "unit": "шт"},
        {"name": "Укладка ламината", "price": 25, "unit": "кв.м"},
    ],
}
DESCRIPTIONS = [
    "Опыт работы более 5 лет. Качество гарантирую.",
    "Работаю быстро и аккуратно. Свой инструмент.",
    "Мастер на час. Выезд в любой район.",
]

print("Добавляем 100 мастеров...")
masters_list = []
for i in range(100):
    name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
    phone = f"+99292{1000000 + i}"
    phone_norm = f"92{1000000 + i}"[-9:]
    profession = random.choice(list(PROFESSIONS.keys()))
    categories = [profession]
    if random.random() > 0.7:
        other = random.choice(list(PROFESSIONS.keys()))
        if other != profession:
            categories.append(other)
    services = random.sample(PROFESSIONS[profession], k=min(2, len(PROFESSIONS[profession])))
    m = MasterDB(
        name=name,
        phone=phone,
        phone_norm=phone_norm,
        role="user",
        categories_json=json.dumps(categories, ensure_ascii=False),
        description=random.choice(DESCRIPTIONS),
        experience=random.randint(2, 20),
        image="",
        portfolio_json="[]",
        services_json=json.dumps(services, ensure_ascii=False),
        rating=round(random.uniform(3.8, 5.0), 1),
        points=0,
    )
    masters_list.append(m)
db.bulk_save_objects(masters_list)
db.commit()
print("  Ок: 100 мастеров.")

# --- Стройматериалы (100 шт, разные категории/подкатегории) ---
BRANDS_BUILD = ["Knauf", "Ceresit", "Weber", "Huaxin", "Mohir", "Bergauf", "Gips", "МеталлПрофиль"]
CATEGORIES_SUB = {
    "Сухие смеси": [
        ("Штукатурка гипсовая", [75, 85]),
        ("Шпаклевка финишная", [90, 140]),
        ("Цемент М500", [80, 95]),
        ("Клей плиточный", [55, 120]),
        ("Наливной пол", [60, 150]),
        ("Клей для блоков", [50, 90]),
        ("Грунтовка бетоноконтакт", [40, 80]),
    ],
    "Гипсокартон и профили": [
        ("ГКЛ Стеновой 12.5мм", [65, 80]),
        ("ГКЛ Влагостойкий", [75, 95]),
        ("Профиль CD-60", [25, 45]),
        ("Профиль UD-27", [18, 35]),
        ("ГКЛВ 9.5мм", [55, 70]),
    ],
    "Кирпич и блоки": [
        ("Кирпич керамический", [8, 15]),
        ("Блок газобетонный", [12, 25]),
        ("Пеноблок", [10, 22]),
    ],
    "Кровля и изоляция": [
        ("Рубероид", [30, 60]),
        ("Утеплитель минвата", [80, 200]),
        ("Пенопласт 50мм", [40, 90]),
        ("Паропроницаемая пленка", [15, 40]),
    ],
    "Лакокрасочные материалы": [
        ("Краска водоэмульсионная", [150, 500]),
        ("Грунтовка глубокая", [40, 150]),
        ("Эмаль ПФ", [80, 250]),
    ],
}

print("Добавляем 100 стройматериалов...")
products_list = []
for i in range(100):
    sub_name = random.choice(list(CATEGORIES_SUB.keys()))
    templates = CATEGORIES_SUB[sub_name]
    name_base, price_range = random.choice(templates)
    min_p, max_p = price_range
    brand = random.choice(BRANDS_BUILD)
    name = f"{name_base} {brand}"
    if "Профиль" not in name_base and "ГКЛ" not in name_base:
        name += f" {random.randint(100, 999)}"
    price = round(random.uniform(min_p, max_p), 0)
    unit = "шт"
    if "Цемент" in name_base or "Штукатурка" in name_base or "Клей" in name_base:
        unit = "мешок"
    if "Краска" in name_base or "Эмульсия" in name_base:
        unit = "ведро"
    if "Кабель" in name_base or "Пленка" in name_base:
        unit = "рулон"
    articul = f"SM-{100000 + i}"
    p = ProductDB(
        name=name,
        brand=brand,
        price=price,
        category="Стройматериалы",
        subcategory=sub_name,
        description=f"Стройматериал {brand}. {sub_name}.",
        unit=unit,
        articul=articul,
        image="",
        photos_json="[]",
        sizes_json="[]",
        colors_json="[]",
    )
    products_list.append(p)
db.bulk_save_objects(products_list)
db.commit()
db.close()

print("  Ок: 100 стройматериалов.")
print("Готово. Запустите приложение: uvicorn main:app --reload")
