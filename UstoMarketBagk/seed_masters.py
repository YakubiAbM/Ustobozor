import random
import json
from database import SessionLocal, MasterDB

# === БАЗА ДАННЫХ ИМЕН И УСЛУГ ===

FIRST_NAMES = [
    "Алишер", "Джамшед", "Рустам", "Исмоил", "Далер", "Парвиз", "Фарход", 
    "Собир", "Умед", "Акмал", "Бахром", "Зафар", "Шерали", "Тимур", "Ильхом"
]

LAST_NAMES = [
    "Алиев", "Каримов", "Рахимов", "Назаров", "Саидов", "Джураев", 
    "Турсунов", "Исломов", "Ходжаев", "Бобоев", "Курбонов"
]

PROFESSIONS = {
    "Сантехник": [
        {"name": "Установка смесителя", "price": 50, "unit": "шт"},
        {"name": "Монтаж труб", "price": 20, "unit": "м"},
        {"name": "Установка унитаза", "price": 100, "unit": "шт"},
        {"name": "Устранение засора", "price": 80, "unit": "услуга"},
        {"name": "Подключение стиральной машины", "price": 70, "unit": "шт"}
    ],
    "Электрик": [
        {"name": "Установка розетки", "price": 15, "unit": "шт"},
        {"name": "Монтаж проводки", "price": 10, "unit": "м"},
        {"name": "Сборка электрощита", "price": 200, "unit": "шт"},
        {"name": "Установка люстры", "price": 60, "unit": "шт"},
        {"name": "Поиск неисправности", "price": 100, "unit": "услуга"}
    ],
    "Маляр-Штукатур": [
        {"name": "Шпатлевка стен", "price": 25, "unit": "кв.м"},
        {"name": "Покраска стен", "price": 20, "unit": "кв.м"},
        {"name": "Поклейка обоев", "price": 30, "unit": "кв.м"},
        {"name": "Грунтовка", "price": 5, "unit": "кв.м"},
        {"name": "Штукатурка под маяк", "price": 40, "unit": "кв.м"}
    ],
    "Плиточник": [
        {"name": "Укладка кафеля (пол)", "price": 60, "unit": "кв.м"},
        {"name": "Укладка кафеля (стены)", "price": 70, "unit": "кв.м"},
        {"name": "Затирка швов", "price": 10, "unit": "кв.м"},
        {"name": "Резка плитки (угол 45)", "price": 15, "unit": "м"}
    ],
    "Сварщик": [
        {"name": "Сварка труб", "price": 50, "unit": "шов"},
        {"name": "Изготовление ворот", "price": 500, "unit": "кв.м"},
        {"name": "Монтаж навеса", "price": 150, "unit": "кв.м"}
    ],
    "Плотник": [
        {"name": "Установка двери", "price": 150, "unit": "шт"},
        {"name": "Укладка ламината", "price": 25, "unit": "кв.м"},
        {"name": "Монтаж плинтуса", "price": 10, "unit": "м"}
    ]
}

DESCRIPTIONS = [
    "Опыт работы более 10 лет. Качество гарантирую.",
    "Работаю быстро и аккуратно. Свой инструмент.",
    "Бригада мастеров. Выполняем любые объемы.",
    "Мастер на час. Выезд в любой район города.",
    "Профессиональный подход. Гарантия на все виды работ.",
    "Не пью, не курю, работаю на совесть.",
    "Помогу с закупкой материалов со скидкой."
]

def generate_masters(count=500):
    db = SessionLocal()
    
    print(f"👷 Генерация {count} мастеров...")

    masters_buffer = []

    for _ in range(count):
        # 1. Генерируем данные
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)
        full_name = f"{first} {last}"
        
        # Выбираем профессию
        profession = random.choice(list(PROFESSIONS.keys()))
        categories = [profession] # Основная категория
        
        # Иногда добавляем вторую категорию (мастер на все руки)
        if random.random() > 0.8:
            second_cat = random.choice(list(PROFESSIONS.keys()))
            if second_cat != profession:
                categories.append(second_cat)

        # Услуги
        available_services = PROFESSIONS[profession]
        
        # --- ИСПРАВЛЕНИЕ ОШИБКИ ЗДЕСЬ ---
        # Мы берем случайное количество от 1 до ВСЕХ доступных услуг.
        # Это гарантирует, что мы никогда не попросим больше услуг, чем есть в списке.
        count_to_pick = random.randint(1, len(available_services))
        my_services = random.sample(available_services, k=count_to_pick)
        # -------------------------------
        
        # Рейтинг (смещаем к 4.5-5.0, плохих мастеров мало)
        rating = round(random.uniform(3.5, 5.0), 1)
        
        # Опыт
        experience = random.randint(2, 25)
        
        # Телефон
        phone = f"+992 92 {random.randint(100, 999)} {random.randint(10, 99)} {random.randint(10, 99)}"

        # 2. Создаем объект
        master = MasterDB(
            name=full_name,
            phone=phone,
            categories_json=json.dumps(categories, ensure_ascii=False),
            description=random.choice(DESCRIPTIONS),
            experience=experience,
            image="", # Без фото, или можно подставить заглушку
            portfolio_json="[]",
            services_json=json.dumps(my_services, ensure_ascii=False),
            rating=rating
        )
        masters_buffer.append(master)

    # 3. Сохраняем пачкой
    db.bulk_save_objects(masters_buffer)
    db.commit()
    db.close()
    print("✅ Готово! 500 мастеров добавлено.")

if __name__ == "__main__":
    generate_masters(500)