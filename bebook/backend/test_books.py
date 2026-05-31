import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()
try:
    cur.execute("""
        SELECT 
            b.book_id as book_id, u.user_id, b.title, b.author, b.category, b.price, 
            b.description, b.image_path, b.seller_email, b.publisher,
            u.email, u.university, u.department
        FROM public.books b
        LEFT JOIN public.users u ON b.seller_email = u.email
    """)
    rows = cur.fetchall()
    print(f"Toplam kitap: {len(rows)}")
    if rows:
        print("İlk kitap:", rows[0])
except Exception as e:
    print(f"HATA: {e}")
finally:
    conn.close()
