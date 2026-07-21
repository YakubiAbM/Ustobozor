from database import SessionLocal, ProductDB, ProductStockDB

db = SessionLocal()
total = db.query(ProductDB).count()
out = db.query(ProductStockDB).filter(ProductStockDB.is_in_stock == 0).count()
in_stock = db.query(ProductStockDB).filter(ProductStockDB.is_in_stock == 1).count()
print("products_total", total)
print("stock_out", out)
print("stock_in", in_stock)
rows = (
    db.query(ProductDB.id, ProductDB.name, ProductStockDB.is_in_stock)
    .outerjoin(ProductStockDB, ProductStockDB.product_id == ProductDB.id)
    .order_by(ProductDB.id.desc())
    .limit(15)
    .all()
)
for r in rows:
    print(r[0], r[2], r[1][:50])
db.close()
