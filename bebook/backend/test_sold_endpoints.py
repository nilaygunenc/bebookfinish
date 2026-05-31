import psycopg2

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# Orders tablosundaki kayıtları kontrol et
cur.execute("SELECT order_id, user_id, book_id, price, status, created_at FROM orders ORDER BY created_at DESC LIMIT 10")
orders = cur.fetchall()
print("=== ORDERS ===")
for o in orders:
    print(o)

# is_sold = TRUE olan kitapları kontrol et
cur.execute("SELECT id, title, is_sold FROM books WHERE is_sold = TRUE")
sold = cur.fetchall()
print("\n=== SOLD BOOKS ===")
for s in sold:
    print(s)

# SUCCESS olan siparişler
cur.execute("SELECT order_id, user_id, book_id, status FROM orders WHERE status = 'SUCCESS'")
success = cur.fetchall()
print("\n=== SUCCESS ORDERS ===")
for s in success:
    print(s)

conn.close()
