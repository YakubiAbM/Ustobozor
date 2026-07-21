import re
import json
from typing import List, Optional
from thefuzz import process, fuzz
from sqlalchemy.orm import Session
from database import ProductDB

# ==========================================
# ⚙️ НАСТРОЙКИ ПОИСКА
# ==========================================

# Настройки для Чата (Помягче)
THRESHOLD_AUTO = 85   
THRESHOLD_GAP = 20     
THRESHOLD_MIN_CHAT = 40 # Снизил порог, чтобы чат был разговорчивее

# Настройки для Главного поиска (Строже)
THRESHOLD_MIN_API = 60  
MAX_OPTIONS = 5

SYNONYM_GROUPS = [
    {"гкл", "гипсокартон", "лист", "регипс", "гипрок"},
    {"профиль", "направляющая", "стоечный", "cd", "ud", "cw", "uw"},
    {"эмульсия", "краска", "водоэмульсионная", "фасадная", "интерьерная", "эмаль"},
    {"ротбанд", "штукатурка", "смесь", "гипсовая"},
    {"кафель", "плитка", "керамогранит", "кафельная"},
    {"клей", "жидкие гвозди", "пва", "момент", "плиточный"},
    {"пена", "монтажная", "герметик", "пена-клей"},
    {"саморез", "шуруп", "крепеж", "клоп"},
    {"дрель", "перфоратор", "шуруповерт"},
    {"розетка", "выключатель", "электроточка"},
    {"цемент", "м400", "м500", "хуаксин", "мохир"},
    {"шпатлевка", "шпаклевка", "финиш", "старт"},
    {"урса", "минвата", "утеплитель", "изоляция"},
    {"травертин", "жидкий камень", "декор"},
    {"леса", "строительные леса", "лестница"}
]

PRODUCTS_CACHE = []

def refresh_products_cache(db: Session):
    global PRODUCTS_CACHE
    print("🔄 Обновляем кеш товаров...")
    products = db.query(ProductDB).all()
    PRODUCTS_CACHE = []
    for p in products:
        full_text = f"{p.name} {p.category} {p.subcategory} {p.articul} {p.description}".lower().replace('ё', 'е')
        numbers = set(re.findall(r'\d+', full_text))
        
        try: sizes = json.loads(p.sizes_json) if p.sizes_json else []
        except: sizes = []
        try: colors = json.loads(p.colors_json) if p.colors_json else []
        except: colors = []
        try: photos = json.loads(p.photos_json) if p.photos_json else []
        except: photos = []
        if not photos and p.image: photos = [p.image]

        PRODUCTS_CACHE.append({
            "id": p.id,
            "obj": p,
            "name_norm": p.name.lower().replace('ё', 'е'),
            "category_norm": p.category.lower().replace('ё', 'е'),
            "category_raw": p.category, 
            "full_text": full_text,
            "numbers": numbers,
            "sizes": sizes,
            "colors": colors,
            "photos": photos,
            "name": p.name,
            "price": p.price,
            "unit": p.unit,
            "image": p.image,
            "articul": p.articul,
            "tokens": set(full_text.split())
        })
    print(f"✅ Кеш обновлен: {len(PRODUCTS_CACHE)} товаров.")

class TextParser:
    @staticmethod
    def normalize_text(text: str):
        text = text.lower().replace('ё', 'е').replace('x', 'х')
        text = re.sub(r'[^\w\s\d.,-]', ' ', text)
        return re.sub(r'\s+', ' ', text).strip()

    @staticmethod
    def parse_line(text: str):
        text = TextParser.normalize_text(text)
        if not text: return None
        if len(text) < 2: return None # Слишком коротко

        qty = 1.0
        unit = "шт"
        name_query = text

        # Регулярки для поиска единиц (кг, л, шт, мешок)
        units_regex = r'(\d+[.,]?\d*)\s*(меш[а-я]*|лист[а-я]*|упак[а-я]*|пач[а-я]*|рулон[а-я]*|кг|г|л|м|шт|метр[а-я]*|ведер|ведр[а-я]*)'
        
        match_end = re.search(f'^(.*?)\s+{units_regex}$', text)
        match_start = re.search(f'^{units_regex}\s+(.*)$', text)

        if match_end:
            # Пример: "Ротбанд 5 мешков"
            name_query = match_end.group(1)
            qty = float(match_end.group(2).replace(',', '.'))
            unit = TextParser.normalize_unit(match_end.group(3))
        elif match_start:
            # Пример: "5 кг гвоздей"
            qty = float(match_start.group(1).replace(',', '.'))
            unit = TextParser.normalize_unit(match_start.group(2))
            name_query = match_start.group(3)
        else:
            # Пробуем найти просто число в конце: "Краска 2"
            simple_match = re.search(r'^(.*?)\s+(\d+[.,]?\d*)$', text)
            if simple_match:
                name_query = simple_match.group(1)
                qty = float(simple_match.group(2).replace(',', '.'))
            else:
                # 🔥 FALLBACK: Если цифр нет вообще, считаем всё название товаром (1 шт)
                # Это исправит проблему, когда "ротбанд" не искался
                name_query = text
                qty = 1.0

        return {"original": text, "name_query": name_query.strip(), "qty": qty, "unit": unit}

    @staticmethod
    def normalize_unit(raw: str):
        raw = raw.lower()
        if "меш" in raw: return "мешок"
        if "лист" in raw: return "лист"
        if "упак" in raw or "пач" in raw: return "упак"
        if "рулон" in raw: return "рулон"
        if "вед" in raw: return "ведро"
        if "метр" in raw: return "м"
        if "литр" in raw: return "л"
        return raw 

    @staticmethod
    def parse_text_bulk(full_text: str):
        lines = re.split(r'[,\n;]', full_text)
        results = []
        for i, line in enumerate(lines):
            if not line.strip(): continue
            parsed = TextParser.parse_line(line)
            if parsed and len(parsed["name_query"]) > 1:
                parsed["item_index"] = i
                results.append(parsed)
        return results

class SearchEngine:
    @staticmethod
    def expand_query(query: str) -> str:
        words = query.split()
        expanded_words = set(words)
        for w in words:
            for group in SYNONYM_GROUPS:
                if w in group: expanded_words.update(group)
        return " ".join(expanded_words)

    @staticmethod
    def calculate_score(query: str, product: dict, query_expanded: str = None) -> float:
        if not query_expanded:
            query_expanded = SearchEngine.expand_query(query)
        
        # 1. Артикул
        if len(query) > 2 and query in product["articul"].lower(): return 100.0

        score = 0.0
        
        # 2. Прямое вхождение
        if query in product["name_norm"]:
            score = 85.0
            if product["name_norm"].startswith(query): score += 15.0
        else:
            # 3. Fuzzy
            name_score = fuzz.token_set_ratio(query_expanded, product["name_norm"])
            if name_score < 40: score = 0 
            else: score = name_score * 0.85

        # 4. Категория
        if query in product["category_norm"]: score += 5

        # 5. Числа (Только если они есть в запросе)
        query_numbers = set(re.findall(r'\d+', query))
        if query_numbers:
            matches = query_numbers.intersection(product["numbers"])
            if matches: score += 10
            else: score -= 15
        
        return min(max(score, 0), 100)

    # 🔎 ПОИСК ДЛЯ ЧАТА
    @staticmethod
    def search(query: str):
        if not PRODUCTS_CACHE: return [] # Кеш пуст
        candidates = []
        query_expanded = SearchEngine.expand_query(query)
        
        for p in PRODUCTS_CACHE:
            score = SearchEngine.calculate_score(query, p, query_expanded)
            if score >= THRESHOLD_MIN_CHAT:
                candidates.append((p, score))
        
        candidates.sort(key=lambda x: x[1], reverse=True)
        if candidates:
            best_score = candidates[0][1]
            if best_score > 80: candidates = [c for c in candidates if c[1] >= 50]
        return candidates[:MAX_OPTIONS]

    # 🚀 ПОИСК ДЛЯ API (Главный экран)
    @staticmethod
    def search_api(q: str, category: Optional[str] = None, limit: int = 40, offset: int = 0):
        if not q or len(q) < 2: return []
        if not PRODUCTS_CACHE: return []

        q_norm = TextParser.normalize_text(q)
        q_tokens = set(q_norm.split())
        query_expanded = SearchEngine.expand_query(q_norm)
        
        candidates = []
        
        for p in PRODUCTS_CACHE:
            if category and category != 'all' and category != '':
                if p["category_raw"] != category: continue

            if len(q_norm) > 3:
                has_common = False
                if q_tokens.intersection(p["tokens"]): has_common = True
                else:
                    for token in q_tokens:
                        if len(token) > 2 and token in p["name_norm"]:
                            has_common = True; break
                if not has_common: continue

            score = SearchEngine.calculate_score(q_norm, p, query_expanded)
            
            if score >= THRESHOLD_MIN_API:
                candidates.append({
                    "id": p["id"],
                    "name": p["name"],
                    "price": p["price"],
                    "category": p["category_raw"],
                    "subcategory": p["obj"].subcategory,
                    "description": p["obj"].description,
                    "unit": p["obj"].unit,
                    "image": p["image"],
                    "articul": p["articul"],
                    "photos": p["photos"],
                    "sizes": p["sizes"],
                    "colors": p["colors"],
                    "_score": score
                })

        candidates.sort(key=lambda x: x["_score"], reverse=True)
        return candidates[offset : offset + limit]