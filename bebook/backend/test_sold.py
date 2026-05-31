import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

print("=== is_sold = TRUE olan kitaplar ===")
cur.execute("SELECT book_id, title, seller_email, is_sold FROM books WHERE is_sold = TRUE")
rows = cur.fetchall()
for r in rows:
    print(f"  book_id={r[0]}, title={r[1]}, seller={r[2]}, is_sold={r[3]}")

print("\n=== SUCCESS olan siparişler ===")
cur.execute("SELECT order_id, user_id, book_id, book_ids, status FROM orders WHERE status = 'SUCCESS'")
rows = cur.fetchall()
for r in rows:
    print(f"  order_id={r[0]}, buyer_id={r[1]}, book_id={r[2]}, book_ids={r[3]}, status={r[4]}")

print("\n=== Merve'nin sattığı kitaplar (user_id=4) ===")
cur.execute("""
    SELECT b.book_id, b.title, b.seller_email, b.is_sold,
           o.order_id, o.user_id as buyer_id, buyer.email as buyer_email
    FROM books b
    LEFT JOIN orders o ON (
        b.book_id = o.book_id 
        OR (o.book_ids IS NOT NULL AND o.book_ids != '' AND b.book_id::text = ANY(string_to_array(o.book_ids, ',')))
    ) AND o.status = 'SUCCESS'
    LEFT JOIN users buyer ON o.user_id = buyer.user_id
    WHERE b.seller_email = 'merve@gmail.com' AND b.is_sold = TRUE
""")
rows = cur.fetchall()
for r in rows:
    print(f"  book={r[1]}, is_sold={r[3]}, order_id={r[4]}, buyer={r[6]}")

conn.close()
