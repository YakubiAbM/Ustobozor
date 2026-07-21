"""
Общая логика смены статуса заказа (админка).
"""

import json
from sqlalchemy.orm import Session

from database import OrderDB, MasterDB, ProductDB
# from notifications import create_notification  # баллы временно отключены


VALID_STATUSES = ("new", "processing", "completed", "canceled")


def apply_order_status_change(db: Session, order_id: int, new_status: str) -> bool:
    """
    Меняет статус заказа: начисляет баллы мастеру и обновляет sales_count при «Выполнен».
    Возвращает True, если заказ найден и статус обновлён.
    """
    if new_status not in VALID_STATUSES:
        return False
    order = db.query(OrderDB).filter(OrderDB.id == order_id).first()
    if not order:
        return False

    if new_status == "completed" and order.status != "completed":
        # Начисление баллов мастеру по телефону клиента (временно отключено).
        # if MASTER_POINTS_ENABLED and order.client_phone:
        #     order_digits = "".join(filter(str.isdigit, order.client_phone))
        #     if len(order_digits) >= 7:
        #         search_phone = order_digits[-9:]
        #         for m in db.query(MasterDB).filter(MasterDB.phone.isnot(None)).all():
        #             if not m.phone:
        #                 continue
        #             m_digits = "".join(filter(str.isdigit, m.phone))
        #             if m_digits.endswith(search_phone):
        #                 points = int(order.total_price)
        #                 m.points = (m.points or 0) + points
        #                 create_notification(
        #                     db, m.id, "points_added",
        #                     "Балл илова шуд (барои фармоиш)",
        #                     f"Ба фармоиши №{order_id} {points} балл илова карда шуд. Ҳамагӣ: {m.points}.",
        #                     {"order_id": order_id, "amount": points, "total_points": m.points},
        #                 )
        #                 break

        # Увеличение sales_count у товаров
        try:
            items = json.loads(order.items_json or "[]")
            for item in items:
                p_id = item.get("product_id") or item.get("id")
                qty = float(item.get("qty", 1))
                if p_id:
                    prod = db.query(ProductDB).filter(ProductDB.id == int(p_id)).first()
                    if prod:
                        prod.sales_count = (prod.sales_count or 0) + int(qty)
        except Exception:
            pass

    order.status = new_status
    db.commit()
    return True
