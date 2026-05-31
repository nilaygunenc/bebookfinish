import psycopg2

conn = psycopg2.connect(
    host='localhost',
    database='bebook',
    user='postgres',
    password='1414',
    port='5432'
)

cur = conn.cursor()

# Eski IP'yi yeni IP ile değiştir
cur.execute("""
    UPDATE books 
    SET image_path = REPLACE(image_path, '192.168.1.11', '192.168.1.3') 
    WHERE image_path LIKE '%192.168.1.11%'
""")

conn.commit()
print(f'✓ Güncellenen kayıt sayısı: {cur.rowcount}')

cur.close()
conn.close()
