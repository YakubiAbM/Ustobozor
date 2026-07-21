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
    image = Column(String, default="")
    portfolio_json = Column(Text, default="[]")
    services_json = Column(Text, default="[]")
    rating = Column(Float, default=5.0)
    # OTP: храним только хэш кода
    otp_code = Column(String, nullable=True)  # legacy
    otp_hash = Column(String(128), nullable=True)
    otp_created_at = Column(Integer, default=0)
    otp_attempts = Column(Integer, default=0)
    otp_blocked_until = Column(Integer, nullable=True)
    points = Column(Integer, default=0)
    debt = Column(Float, default=0.0, nullable=False)  # долг мастера (TJS), погашается через кассу
    barcode = Column(String, default="")
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
    """Глобальные настройки: ссылки на соцсети, APK и магазин."""
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


Base.metadata.create_all(bind=engine)


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
    image: Optional[str] = None
    rating: float
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
