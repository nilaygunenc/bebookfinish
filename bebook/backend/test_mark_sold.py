import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# Mevcut kitapları göster
cur.execute("SELECT book_id, title, seller_email, is_sold FROM books WHERE is_sold = FALSE OR is_sold IS NULL ORDER BY book_id DESC LIMIT 10")
rows = cur.fetchall()
print("Satılmamış kitaplar:")
for r in rows:
    print(f"  book_id={r[0]}, title={r[1]}, seller={r[2]}, is_sold={r[3]}")

print("\nHangi kitabı test için is_sold=TRUE yapalım? (book_id girin, boş bırakın iptal)")
book_id = input("> ").strip()
if book_id:
    # Önce orders tablosuna test kaydı ekle
    cur.execute("SELECT user_id FROM users WHERE email = (SELECT seller_email FROM books WHERE book_id = %s)", (int(book_id),))
    seller = cur.fetchone()
    
    # Alıcı olarak farklı bir kullanıcı seç
    cur.execute("SELECT user_id FROM users WHERE user_id != %s LIMIT 1", (seller[0] if seller else 0,))
    buyer = cur.fetchone()
    
    if buyer:
        cur.execute(
            "INSERT INTO orders (user_id, book_id, price, status, book_ids) VALUES (%s, %s, 100, 'SUCCESS', %s) RETURNING order_id",
            (buyer[0], int(book_id), str(book_id))
        )
        order_id = cur.fetchone()[0]
        cur.execute("UPDATE books SET is_sold = TRUE WHERE book_id = %s", (int(book_id),))
        conn.commit()
        print(f"✅ book_id={book_id} is_sold=TRUE yapıldı, order_id={order_id}")
        print(f"   Alıcı user_id={buyer[0]}")
    else:
        print("Alıcı bulunamadı")

conn.close()
