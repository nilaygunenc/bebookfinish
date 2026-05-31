import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# Tüm profil path'lerini çek ve Python'da düzelt
cur.execute("SELECT user_id, profile_image_path FROM public.users WHERE profile_image_path IS NOT NULL AND profile_image_path != ''")
rows = cur.fetchall()

fixed = 0
for user_id, path in rows:
    new_path = path.replace('\\', '/')
    if new_path != path:
        cur.execute("UPDATE public.users SET profile_image_path = %s WHERE user_id = %s", (new_path, user_id))
        print(f"Düzeltildi: user_id={user_id}, {path} -> {new_path}")
        fixed += 1

conn.commit()
print(f"\nToplam düzeltilen: {fixed} kayıt")
conn.close()
