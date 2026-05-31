import psycopg2
conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

# ulkugunenc kullanıcısını bul
cur.execute("SELECT user_id, email, university, department FROM users WHERE email LIKE '%ulku%'")
users = cur.fetchall()
print("ulku kullanıcıları:", users)

# Tüm kullanıcıları listele
cur.execute("SELECT user_id, email, department FROM users ORDER BY user_id")
all_users = cur.fetchall()
print("\nTüm kullanıcılar:")
for u in all_users:
    print(f"  ID:{u[0]} | {u[1]} | {u[2]}")

conn.close()
