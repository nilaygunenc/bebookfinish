import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# books tablosundaki seller_email'lerin users tablosunda karşılığı var mı?
cur.execute("""
    SELECT b.book_id, b.seller_email, u.user_id, u.email
    FROM books b
    LEFT JOIN users u ON b.seller_email = u.email
    LIMIT 10
""")
rows = cur.fetchall()
print("book_id | seller_email | user_id | users.email")
for r in rows:
    print(f"  {r[0]} | {r[1]} | {r[2]} | {r[3]}")

# Eşleşmeyen kayıt sayısı
cur.execute("""
    SELECT COUNT(*) FROM books b
    LEFT JOIN users u ON b.seller_email = u.email
    WHERE u.user_id IS NULL
""")
print(f"\nEşleşmeyen kitap sayısı: {cur.fetchone()[0]}")

conn.close()
