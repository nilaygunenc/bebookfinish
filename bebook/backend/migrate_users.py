import psycopg2

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

try:
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_image_path TEXT")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name VARCHAR(255)")
    conn.commit()
    print("✅ users tablosuna profile_image_path ve full_name sütunları eklendi")
except Exception as e:
    conn.rollback()
    print(f"Hata: {e}")

# Kontrol
cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position")
print("USERS:", [r[0] for r in cur.fetchall()])

conn.close()
