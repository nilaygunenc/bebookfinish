import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# books tablosuna is_sold sütunu ekle
try:
    cur.execute("ALTER TABLE books ADD COLUMN IF NOT EXISTS is_sold BOOLEAN DEFAULT FALSE")
    print("is_sold sütunu eklendi")
except Exception as e:
    print(f"is_sold zaten var veya hata: {e}")

# orders tablosuna book_ids sütunu ekle (tüm satın alınan kitapların ID'leri)
try:
    cur.execute("ALTER TABLE orders ADD COLUMN IF NOT EXISTS book_ids TEXT DEFAULT ''")
    print("book_ids sütunu eklendi")
except Exception as e:
    print(f"book_ids zaten var veya hata: {e}")

conn.commit()

# Kontrol
cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'books' ORDER BY ordinal_position")
print("books sütunları:", [r[0] for r in cur.fetchall()])

cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'orders' ORDER BY ordinal_position")
print("orders sütunları:", [r[0] for r in cur.fetchall()])

conn.close()
print("Tamamlandı!")
