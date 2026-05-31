import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# Mevcut kullanıcıların full_name'lerini göster
cur.execute("SELECT user_id, email, full_name FROM users ORDER BY user_id")
rows = cur.fetchall()
print("Mevcut kullanıcılar:")
for r in rows:
    print(f"  user_id={r[0]}, email={r[1]}, full_name={r[2]}")

print("\nHangi kullanıcıya ad soyad eklemek istiyorsunuz?")
print("Format: user_id:Ad Soyad (örn: 4:Merve Yılmaz)")
print("Çıkmak için boş bırakın")

while True:
    inp = input("> ").strip()
    if not inp:
        break
    try:
        uid, name = inp.split(":", 1)
        cur.execute("UPDATE users SET full_name = %s WHERE user_id = %s", (name.strip(), int(uid)))
        conn.commit()
        print(f"  ✅ user_id={uid} için full_name='{name.strip()}' güncellendi")
    except Exception as e:
        print(f"  ❌ Hata: {e}")

conn.close()
print("Tamamlandı!")
