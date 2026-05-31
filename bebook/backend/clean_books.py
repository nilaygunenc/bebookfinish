import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# Geçersiz seller_email olan ilanları göster
cur.execute("""
    SELECT b.book_id, b.title, b.seller_email
    FROM books b
    LEFT JOIN users u ON LOWER(TRIM(b.seller_email)) = LOWER(TRIM(u.email))
    WHERE u.user_id IS NULL
""")
rows = cur.fetchall()
print("Silinecek geçersiz ilanlar:")
for r in rows:
    print(f"  book_id={r[0]}, title={r[1]}, seller_email={r[2]}")

print(f"\nToplam: {len(rows)} ilan")

if rows:
    confirm = input("\nBu ilanları silmek istiyor musunuz? (evet/hayır): ")
    if confirm.lower() == 'evet':
        ids = [r[0] for r in rows]
        cur.execute(f"DELETE FROM books WHERE book_id = ANY(%s)", (ids,))
        conn.commit()
        print(f"{cur.rowcount} ilan silindi.")
    else:
        print("İptal edildi.")

conn.close()
