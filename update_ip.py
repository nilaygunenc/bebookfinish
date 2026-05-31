import psycopg2

conn = psycopg2.connect(
    host='localhost', database='bebook',
    user='postgres', password='1414', port='5432'
)
cur = conn.cursor()
cur.execute("UPDATE books SET image_path = REPLACE(image_path, '192.168.1.3', '192.168.1.5') WHERE image_path LIKE '%192.168.1.3%'")
conn.commit()
print(f'Veritabani guncellendi: {cur.rowcount} kayit')
cur.close()
conn.close()
