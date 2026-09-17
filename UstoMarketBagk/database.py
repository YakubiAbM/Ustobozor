"""
Модели БД (SQLAlchemy) и Pydantic-схемы для API.
Поддерживается SQLite (dev) и PostgreSQL (prod) через DATABASE_URL.
"""

from typing import List, Optional

from sqlalchemy import create_engine, Column, Integer, String, Float, Text, ForeignKey
from sqlalchemy.orm import sessionmaker, declarative_base
from pydantic import BaseModel, field_validator

try:
    from config import DATABASE_URL, USE_SQLITE
except ImportError:
    DATABASE_URL = "sqlite:///./market.db"
    USE_SQLITE = True

# -----------------------------------------------------------------------------
# Подключение к БД
# -----------------------------------------------------------------------------
connect_args = {"check_same_thread": False} if USE_SQLITE else {}
engine = create_engine(DATABASE_URL, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """FastAPI dependency: сессия БД с авто-закрытием после запроса."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# -----------------------------------------------------------------------------
# Таблицы (ORM)
# -----------------------------------------------------------------------------

class ProductDB(Base):
    """Товар: название, цена, категория, бренд, фото/размеры/цвета (JSON)."""
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    brand = Column(String, default="")
    price = Column(Float)
    category = Column(String)
    subcategory = Column(String)
    description = Column(String)
    unit = Column(String)
    image = Column(String)
    articul = Column(String)
    photos_json = Column(Text, default="[]")
    sizes_json = Column(Text, default="[]")
    colors_json = Column(Text, default="[]")
    sales_count = Column(Integer, default=0)


class MasterDB(Base):
    """Мастер/пользователь: телефон, роль, OTP-поля, баллы, портфолио."""
    __tablename__ = "masters"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String)
    phone = Column(String, unique=True, index=True)
    phone_norm = Column(String(9), index=True)  # последние 9 цифр для поиска
    role = Column(String(16), default="user", nullable=False)  # user | admin
    categories_json = Column(Text, default="[]")
    description = Column(String, default="")
    experience = Column(Integer, default=0)
    city = Column(String, default="")  # город мастера (Душанбе, Худжанд, Истаравшан…)
    image = Column(String, default="")
    portfolio_json = Column(Text, default="[]")
    services_json = Column(Text, default="[]")
    rating = Column(Float, default=5.0)
    reviews_count = Column(Integer, default=0, nullable=False)
    # Публикация в каталог: draft | pending | approved | rejected
    moderation_status = Column(String(16), default="approved", index=True)
    moderation_note = Column(String(255), default="")
    # Если анкета-дубликат: id канонического мастера (фото+заказы+отзывы)
    merged_into_master_id = Column(Integer, nullable=True, index=True)
    # OTP: храним только хэш кода
    otp_code = Column(String, nullable=True)  # legacy
    otp_hash = Column(String(128), nullable=True)
    otp_created_at = Column(Integer, default=0)
    otp_attempts = Column(Integer, default=0)
    otp_blocked_until = Column(Integer, nullable=True)
    points = Column(Integer, default=0)
    debt = Column(Float, default=0.0, nullable=False)  # долг мастера (TJS), погашается через кассу
    barcode = Column(String, default="")
    # Telegram chat_id для персональных уведомлений (опционально)
    telegram_chat_id = Column(String(32), nullable=True)
    # 4-значный PIN для входа в админку (хэш; только у админов)
    pin_hash = Column(String(64), nullable=True)
    # Пароль мастера для входа в мобильное приложение (bcrypt)
    password_hash = Column(String(255), nullable=True)
    is_password_reset = Column(Integer, default=0, nullable=False)  # 0 | 1
    # Супер-админ: полный доступ и управление другими админами
    is_superadmin = Column(Integer, default=0, nullable=False)  # 0 | 1
    # Доступ по экранам для обычного админа: JSON-массив ["dashboard","orders","products","masters","cashier"]
    admin_permissions = Column(Text, nullable=True)  # null/[] = только то, что указано


class AdminDB(Base):
    """Админ панели: отдельная таблица (не мастера). Вход по телефону + PIN."""
    __tablename__ = "admins"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, default="")
    phone = Column(String, nullable=False, index=True)
    phone_norm = Column(String(9), unique=True, nullable=False, index=True)
    pin_hash = Column(String(64), nullable=False)
    is_superadmin = Column(Integer, default=0, nullable=False)  # 0 | 1
    admin_permissions = Column(Text, nullable=True)  # JSON: ["dashboard","orders",...]


class ClientDB(Base):
    """Покупатель (клиент магазина): вход по телефону и личному коду (пароль)."""
    __tablename__ = "clients"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, default="")
    phone = Column(String, unique=True, index=True)
    phone_norm = Column(String(9), unique=True, index=True)
    password_hash = Column(String(255), nullable=False)
    created_at = Column(String(32), default="")


class OrderDB(Base):
    """Заказ: клиент, сумма, позиции (JSON), способ оплаты, опционально привязка к мастеру."""
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    client_name = Column(String)
    client_phone = Column(String)
    client_phone_norm = Column(String(9), index=True)
    client_address = Column(String)
    total_price = Column(Float)
    items_json = Column(Text)
    payment_type = Column(String(16), nullable=True)  # "cash" | "card"
    comment = Column(Text, nullable=True)
    created_at = Column(String)
    status = Column(String, default="new")
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=True)


class ChatSessionDB(Base):
    """Сессия чат-бота: корзина и очередь невыбранных позиций (JSON)."""
    __tablename__ = "chat_sessions"
    session_id = Column(String, primary_key=True, index=True)
    cart_json = Column(Text, default="[]")
    pending_items_json = Column(Text, default="[]")
    created_at = Column(Integer)


class TransactionDB(Base):
    """Офлайн-транзакция (касса): начисление баллов мастеру."""
    __tablename__ = "transactions"
    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(Integer)
    master_name = Column(String)
    amount = Column(Float)
    created_at = Column(String)


class RefreshTokenDB(Base):
    """Refresh-токен: хэш, срок, отзыв, rotation (replaced_by_token_hash)."""
    __tablename__ = "refresh_tokens"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False, index=True)
    user_kind = Column(String(16), default="master", nullable=False)  # master | client
    token_hash = Column(String(128), unique=True, nullable=False, index=True)
    created_at = Column(Integer, nullable=False)
    expires_at = Column(Integer, nullable=False)
    revoked_at = Column(Integer, nullable=True)
    replaced_by_token_hash = Column(String(128), nullable=True)
    ip = Column(String(45), nullable=True)
    user_agent = Column(Text, nullable=True)


class MasterNotificationDB(Base):
    """Уведомление для мастера: акции, начисление/списание баллов."""
    __tablename__ = "master_notifications"
    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, index=True)
    type = Column(String(32), nullable=False)  # promo | points_added | points_spent
    title = Column(String(256), nullable=False)
    body = Column(Text, default="")
    payload_json = Column(Text, default="{}")  # доп. данные: amount, order_id и т.д.
    created_at = Column(String(32), nullable=False)
    read_at = Column(String(32), nullable=True)


class DeviceTokenDB(Base):
    """FCM-токен устройства мастера (для push-уведомлений)."""
    __tablename__ = "device_tokens"
    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, index=True)
    token = Column(String(255), unique=True, nullable=False, index=True)
    platform = Column(String(16), default="android")
    created_at = Column(Integer, nullable=False)
    updated_at = Column(Integer, nullable=False)
    is_active = Column(Integer, default=1, nullable=False)  # 1 = активен, 0 = выключен/устарел


class SiteSettingsDB(Base):
    """Глобальные настройки: ссылки для Telegram-бота, APK и магазин."""
    __tablename__ = "site_settings"
    id = Column(Integer, primary_key=True, index=True)
    telegram_channel_url = Column(String, default="")
    whatsapp_group_url = Column(String, default="")
    instagram_url = Column(String, default="")
    tiktok_url = Column(String, default="")
    apk_url = Column(String, default="")
    shop_url = Column(String, default="")  # ссылка на PWA / мини-магазин


class ProductStockDB(Base):
    """Наличие товара в магазине: 1 = в наличии, 0 = нет в наличии."""
    __tablename__ = "product_stock"
    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False, unique=True, index=True)
    is_in_stock = Column(Integer, default=1, nullable=False)
    updated_at = Column(Integer, default=0, nullable=False)


class ServiceRequestDB(Base):
    """Заявка на услугу мастера (биржа заказов). Не путать с shop OrderDB."""
    __tablename__ = "service_requests"
    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False, index=True)
    category = Column(String(128), nullable=False, default="", index=True)
    title = Column(String(150), nullable=False)
    description = Column(Text, default="")
    address = Column(String(255), default="")
    city = Column(String(128), default="")
    budget = Column(Float, nullable=True)
    client_name = Column(String(128), default="")
    client_phone = Column(String(32), default="")
    status = Column(String(32), default="open", index=True)  # open|in_progress|completed|cancelled
    created_at = Column(String(32), default="")


class ServiceRequestPhotoDB(Base):
    __tablename__ = "service_request_photos"
    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(Integer, ForeignKey("service_requests.id"), nullable=False, index=True)
    image_url = Column(String, nullable=False)


class ServiceRequestResponseDB(Base):
    __tablename__ = "service_request_responses"
    id = Column(Integer, primary_key=True, index=True)
    request_id = Column(Integer, ForeignKey("service_requests.id"), nullable=False, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, index=True)
    proposed_price = Column(Float, nullable=True)
    comment = Column(Text, default="")
    created_at = Column(String(32), default="")


# -----------------------------------------------------------------------------
# Каталог фикс-услуг + заказы с комиссией (не путать с shop OrderDB / service_requests)
# -----------------------------------------------------------------------------

class ServiceCategoryDB(Base):
    __tablename__ = "service_categories"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(128), nullable=False, unique=True, index=True)
    is_active = Column(Integer, default=1, nullable=False)  # 1/0 for SQLite


class ServiceCatalogDB(Base):
    __tablename__ = "service_catalog"
    id = Column(Integer, primary_key=True, index=True)
    category_id = Column(Integer, ForeignKey("service_categories.id"), nullable=False, index=True)
    title = Column(String(255), nullable=False)
    price_client = Column(Float, nullable=False, default=0)
    commission_fee = Column(Float, nullable=False, default=0)
    is_active = Column(Integer, default=1, nullable=False, index=True)


class MasterBalanceDB(Base):
    __tablename__ = "master_balances"
    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, unique=True, index=True)
    balance = Column(Float, nullable=False, default=0)


class ServiceOrderDB(Base):
    """Заказ из каталога услуг. Не путать с shop OrderDB."""
    __tablename__ = "service_orders"
    id = Column(Integer, primary_key=True, index=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False, index=True)
    service_id = Column(Integer, ForeignKey("service_catalog.id"), nullable=False, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=True, index=True)
    address = Column(Text, default="")  # текстовый ориентир (address_text)
    comment = Column(Text, default="")
    scheduled_date = Column(String(32), default="")  # YYYY-MM-DD
    scheduled_time = Column(String(16), default="")  # HH:MM
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    status = Column(String(32), default="NEW", index=True)  # NEW|IN_PROGRESS|COMPLETED|CANCELLED
    price_client = Column(Float, nullable=False, default=0)  # snapshot
    commission_fee = Column(Float, nullable=False, default=0)  # snapshot (комиссия пока не списывается)
    client_name = Column(String(128), default="")
    client_phone = Column(String(32), default="")
    created_at = Column(String(32), default="")


class ServiceOrderPhotoDB(Base):
    __tablename__ = "service_order_photos"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("service_orders.id"), nullable=False, index=True)
    image_url = Column(String, nullable=False)


class ServiceOrderReviewDB(Base):
    """Отзыв клиента по выполненному service_order (1 заказ = 1 отзыв)."""
    __tablename__ = "service_order_reviews"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("service_orders.id"), nullable=False, unique=True, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, index=True)
    client_id = Column(Integer, ForeignKey("clients.id"), nullable=False, index=True)
    rating = Column(Integer, nullable=False)  # 1..5
    comment = Column(Text, default="")
    created_at = Column(String(32), default="")


class ServiceOrderReviewPhotoDB(Base):
    __tablename__ = "service_order_review_photos"
    id = Column(Integer, primary_key=True, index=True)
    review_id = Column(Integer, ForeignKey("service_order_reviews.id"), nullable=False, index=True)
    photo_url = Column(String, nullable=False)


class BalanceTransactionDB(Base):
    __tablename__ = "balance_transactions"
    id = Column(Integer, primary_key=True, index=True)
    master_id = Column(Integer, ForeignKey("masters.id"), nullable=False, index=True)
    amount = Column(Float, nullable=False)
    type = Column(String(32), nullable=False, index=True)  # COMMISSION_DEBIT | BALANCE_TOPUP
    order_id = Column(Integer, ForeignKey("service_orders.id"), nullable=True, index=True)
    note = Column(String(255), default="")
    created_at = Column(String(32), default="")


Base.metadata.create_all(bind=engine)


def ensure_service_orders_geo_columns() -> None:
    """SQLite/Postgres: добавить geo-колонки к существующей таблице service_orders."""
    from sqlalchemy import inspect, text

    insp = inspect(engine)
    if "service_orders" not in insp.get_table_names():
        return
    existing = {c["name"] for c in insp.get_columns("service_orders")}
    alters = []
    if "scheduled_date" not in existing:
        alters.append("ALTER TABLE service_orders ADD COLUMN scheduled_date VARCHAR(32) DEFAULT ''")
    if "scheduled_time" not in existing:
        alters.append("ALTER TABLE service_orders ADD COLUMN scheduled_time VARCHAR(16) DEFAULT ''")
    if "latitude" not in existing:
        alters.append("ALTER TABLE service_orders ADD COLUMN latitude FLOAT")
    if "longitude" not in existing:
        alters.append("ALTER TABLE service_orders ADD COLUMN longitude FLOAT")
    if not alters:
        return
    with engine.begin() as conn:
        for sql in alters:
            conn.execute(text(sql))


def ensure_master_reviews_count_column() -> None:
    from sqlalchemy import inspect, text

    insp = inspect(engine)
    if "masters" not in insp.get_table_names():
        return
    existing = {c["name"] for c in insp.get_columns("masters")}
    if "reviews_count" in existing:
        return
    with engine.begin() as conn:
        conn.execute(
            text("ALTER TABLE masters ADD COLUMN reviews_count INTEGER NOT NULL DEFAULT 0")
        )


def ensure_master_merged_into_column() -> None:
    """Pointer to canonical master when a duplicate listing was merged."""
    from sqlalchemy import inspect, text

    insp = inspect(engine)
    if "masters" not in insp.get_table_names():
        return
    existing = {c["name"] for c in insp.get_columns("masters")}
    if "merged_into_master_id" in existing:
        return
    with engine.begin() as conn:
        conn.execute(
            text("ALTER TABLE masters ADD COLUMN merged_into_master_id INTEGER")
        )


ensure_service_orders_geo_columns()
ensure_master_reviews_count_column()
ensure_master_merged_into_column()


# -----------------------------------------------------------------------------
# Pydantic-схемы для запросов/ответов API
# -----------------------------------------------------------------------------

class ProductResponse(BaseModel):
    id: int
    name: str
    price: float
    category: str
    subcategory: str
    description: str
    unit: str
    image: Optional[str] = None
    articul: str
    photos: List[str] = []
    sizes: List[dict] = []
    colors: List[dict] = []
    brand: Optional[str] = ""


class PaginatedProductsResponse(BaseModel):
    items: List[ProductResponse]
    total: int
    has_more: bool


class MasterResponse(BaseModel):
    id: int
    name: str
    phone: str
    description: str
    experience: int
    city: str = ""
    image: Optional[str] = None
    rating: float
    reviews_count: int = 0
    categories: List[str] = []
    portfolio: List[str] = []
    services: List[dict] = []


class OrderItem(BaseModel):
    product_id: int
    name: str
    qty: float
    price: float


VALID_PAYMENT_TYPES = ("cash", "card")


class OrderCreate(BaseModel):
    client_name: str
    client_phone: str
    client_address: str
    total_price: float
    items: List[OrderItem]
    payment_type: Optional[str] = "cash"

    class Config:
        extra = "forbid"

    @field_validator("payment_type")
    @classmethod
    def payment_type_must_be_cash_or_card(cls, v):
        if v is None or v == "":
            return "cash"
        v = (v or "").strip().lower()
        if v not in VALID_PAYMENT_TYPES:
            raise ValueError("payment_type должен быть cash или card")
        return v


class OrderResponse(OrderCreate):
    id: int
    status: str
    created_at: str


class ChatMessage(BaseModel):
    session_id: str
    text: str


class ChatPick(BaseModel):
    session_id: str
    item_index: int
    product_id: int


class ChatAction(BaseModel):
    session_id: str
    action: str
    payload: dict


class ChatSubmit(BaseModel):
    session_id: str
    client_name: str
    client_phone: str
    client_address: str
    payment_type: Optional[str] = "cash"
    comment: Optional[str] = None

    @field_validator("payment_type")
    @classmethod
    def payment_type_must_be_cash_or_card(cls, v):
        if v is None or v == "":
            return "cash"
        v = (v or "").strip().lower()
        if v not in VALID_PAYMENT_TYPES:
            raise ValueError("payment_type должен быть cash или card")
        return v

    @field_validator("comment")
    @classmethod
    def comment_strip(cls, v):
        if v is None:
            return None
        s = str(v).strip()
        return s if s else None


class AuthRequest(BaseModel):
    phone: str
    name: str


class VerifyRequest(BaseModel):
    phone: str
    code: str
    name: Optional[str] = None


class SpendPointsRequest(BaseModel):
    master_id: int
    points: int


class NotificationResponse(BaseModel):
    id: int
    master_id: int
    type: str
    title: str
    body: str
    payload: dict = {}
    created_at: str
    read_at: Optional[str] = None
