import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

print("=== Tum siparisler ===")
cur.execute("SELECT order_id, user_id, book_id, book_ids, status, created_at FROM orders ORDER BY created_at DESC LIMIT 10")
rows = cur.fetchall()
for r in rows:
    print(f"  order_id={r[0]}, user_id={r[1]}, book_id={r[2]}, book_ids={r[3]}, status={r[4]}, tarih={r[5]}")

print("\n=== is_sold=TRUE olan kitaplar ===")
cur.execute("SELECT book_id, title, seller_email FROM books WHERE is_sold = TRUE")
rows = cur.fetchall()
for r in rows:
    print(f"  book_id={r[0]}, title={r[1]}, seller={r[2]}")
if not rows:
    print("  Hic yok")

conn.close()
