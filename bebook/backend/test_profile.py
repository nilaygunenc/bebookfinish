import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()
cur.execute("SELECT user_id, email, profile_image_path FROM public.users WHERE profile_image_path IS NOT NULL LIMIT 5")
rows = cur.fetchall()
print("Profil fotoğrafı olan kullanıcılar:")
for r in rows:
    print(f"  user_id={r[0]}, email={r[1]}, path={r[2]}")

cur.execute("SELECT COUNT(*) FROM public.users WHERE profile_image_path IS NOT NULL AND profile_image_path != ''")
count = cur.fetchone()[0]
print(f"\nToplam profil fotoğrafı olan kullanıcı: {count}")
conn.close()
