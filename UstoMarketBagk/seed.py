import random
from database import SessionLocal, ProductDB, engine, Base

# Создаем таблицы (если вдруг нет)
Base.metadata.create_all(bind=engine)

db = SessionLocal()

# 🔥 ОЧИСТКА: Удаляем старые товары перед наполнением
print("🗑 Удаляем старые товары...")
db.query(ProductDB).delete()
db.commit()

# === НАБОРЫ ДАННЫХ ===

BRANDS_TOOLS = ["Bosch", "Makita", "DeWalt", "Total", "Crown", "Ingco", "Deko", "Hilti"]
BRANDS_PAINT = ["Tikkurila", "Dulux", "Sniezka", "Betek", "Marshall", "Alpina"]
BRANDS_BUILD = ["Knauf", "Ceresit", "Weber", "Huaxin", "Mohir", "Isam", "Bergauf"]
BRANDS_ELEC = ["Legrand", "Schneider", "ABB", "IEK", "EKF", "Philips", "Camelion"]
BRANDS_SAN = ["Cersanit", "Grohe", "Roca", "Gappo", "Frap", "Ledeme"]

CATALOG = {
    "Инструменты": {
        "Электроинструмент": [
            ("Перфоратор", BRANDS_TOOLS, 800, 2500),
            ("Дрель ударная", BRANDS_TOOLS, 400, 1200),
            ("Шуруповерт", BRANDS_TOOLS, 350, 1500),
            ("Болгарка (УШМ)", BRANDS_TOOLS, 450, 1800),
            ("Лобзик электрический", BRANDS_TOOLS, 300, 900),
            ("Пила циркулярная", BRANDS_TOOLS, 900, 3000)
        ],
        "Ручной инструмент": [
            ("Молоток", ["Matrix", "Stayer", "Зубр"], 30, 150),
            ("Набор отверток", ["Sata", "Total", "Gross"], 80, 400),
            ("Рулетка 5м", ["Total", "Ingco"], 25, 80),
            ("Уровень строительный", ["Kapro", "Matrix"], 60, 300)
        ]
    },
    "Стройматериалы": {
        "Сухие смеси": [
            ("Штукатурка Rotband", ["Knauf"], 75, 85),
            ("Шпаклевка финишная", ["Weber", "Knauf"], 90, 140),
            ("Цемент М500", ["Huaxin", "Mohir"], 80, 95),
            ("Клей плиточный", ["Ceresit", "Litokol"], 55, 120),
            ("Наливной пол", ["Bergauf", "Ceresit"], 60, 150)
        ],
        "Гипсокартон": [
            ("ГКЛ Стеновой 12.5мм", ["Knauf", "Gips"], 65, 80),
            ("ГКЛ Влагостойкий", ["Knauf", "Gips"], 75, 95),
            ("Профиль CD-60", ["МеталлПрофиль"], 25, 45),
            ("Профиль UD-27", ["МеталлПрофиль"], 18, 35)
        ]
    },
    "Краски": {
        "Интерьерные": [
            ("Эмульсия моющаяся", BRANDS_PAINT, 150, 800),
            ("Краска для потолка", BRANDS_PAINT, 120, 600),
            ("Грунтовка глубокая", ["Ceresit", "Knauf"], 40, 150)
        ],
        "Фасадные": [
            ("Краска фасадная", BRANDS_PAINT, 300, 1200),
            ("Лак по камню", ["Olimp", "Главный Технолог"], 80, 250)
        ]
    },
    "Электрика": {
        "Розетки и выключатели": [
            ("Розетка с заземлением", BRANDS_ELEC, 25, 150),
            ("Выключатель 1-кл", BRANDS_ELEC, 20, 120),
            ("Рамка 2-ная", BRANDS_ELEC, 15, 80)
        ],
        "Освещение": [
            ("Лампа LED 10W", ["Philips", "Camelion"], 15, 45),
            ("Прожектор 50W", ["Wolta", "IEK"], 80, 250),
            ("Светильник потолочный", ["Noname"], 150, 800)
        ],
        "Кабель": [
            ("Кабель ВВГнг 3x2.5", ["Севкабель", "Камкабель"], 8, 15), # цена за метр
            ("Кабель ВВГнг 2x1.5", ["Севкабель", "Камкабель"], 5, 10)
        ]
    },
    "Сантехника": {
        "Смесители": [
            ("Смеситель для кухни", BRANDS_SAN, 150, 800),
            ("Смеситель для ванны", BRANDS_SAN, 250, 1500),
            ("Душевая стойка", BRANDS_SAN, 500, 3000)
        ],
        "Керамика": [
            ("Унитаз-компакт", ["Cersanit", "Santeri"], 800, 2500),
            ("Раковина с тумбой", ["Akvaton", "Roca"], 1200, 4000)
        ]
    }
}

# === ГЕНЕРАЦИЯ 500 ТОВАРОВ ===
items_to_add = []
print("⚙️ Генерируем 500 товаров...")

for i in range(500):
    # 1. Выбираем случайную категорию
    cat_name = random.choice(list(CATALOG.keys()))
    
    # 2. Выбираем подкатегорию
    sub_name = random.choice(list(CATALOG[cat_name].keys()))
    
    # 3. Выбираем шаблон товара (Название, Бренды, МинЦена, МаксЦена)
    template = random.choice(CATALOG[cat_name][sub_name])
    base_name, allowed_brands, min_p, max_p = template
    
    # 4. Генерируем конкретику
    brand = random.choice(allowed_brands)
    
    # Делаем название уникальным: "Перфоратор Bosch 251"
    model_num = random.randint(100, 9000)
    if "Кабель" in base_name or "ГКЛ" in base_name or "Профиль" in base_name:
        full_name = f"{base_name} {brand}" # Без номера модели для стройматериалов
    else:
        full_name = f"{base_name} {brand} Model-{model_num}"
    
    # Цена
    price = round(random.uniform(min_p, max_p), 0)
    
    # Единица измерения
    unit = "шт"
    if "Кабель" in base_name: unit = "м"
    if "Штукатурка" in base_name or "Цемент" in base_name: unit = "мешок"
    if "Краска" in base_name or "Эмульсия" in base_name: unit = "ведро"
    if "Ламинат" in base_name: unit = "упак"

    # Артикул
    articul = f"ART-{random.randint(100000, 999999)}"

    # Картинка (заглушка)
    image_path = ""
    
    item = ProductDB(
        name=full_name,
        price=price,
        brand=brand,
        category=cat_name,
        subcategory=sub_name,
        description=f"Качественный товар от производителя {brand}. Отличный выбор для ремонта.",
        unit=unit,
        articul=articul,
        image=image_path,
        photos_json="[]",
        sizes_json="[]",
        colors_json="[]"
    )
    items_to_add.append(item)

# Сохраняем пачками по 100 штук (чтобы быстрее)
db.bulk_save_objects(items_to_add)
db.commit()
db.close()

print("✅ УСПЕХ! Добавлено 500 тестовых товаров с брендами.")