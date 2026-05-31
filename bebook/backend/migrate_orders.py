import psycopg2

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# orders tablosuna kitap bilgisi sütunları ekle
try:
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS book_title VARCHAR(500)")
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS book_author VARCHAR(255)")
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS book_image TEXT")
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS book_category VARCHAR(255)")
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_email VARCHAR(255)")
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS seller_id INTEGER")
    conn.commit()
    print("✅ orders tablosuna sütunlar eklendi")
except Exception as e:
    conn.rollback()
    print(f"Hata: {e}")

# Mevcut orders'ları güncelle (books tablosundan bilgileri çek)
try:
    cur.execute("""
        UPDATE orders o
        SET 
            book_title = b.title,
            book_author = b.author,
            book_image = b.image_path,
            book_category = b.category,
            seller_email = b.seller_email,
            seller_id = u.user_id
        FROM books b
        LEFT JOIN users u ON b.seller_email = u.email
        WHERE o.book_id = b.id AND o.book_title IS NULL
    """)
    conn.commit()
    print(f"✅ {cur.rowcount} mevcut sipariş güncellendi")
except Exception as e:
    conn.rollback()
    print(f"Güncelleme hatası: {e}")

conn.close()
