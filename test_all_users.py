import requests
import psycopg2

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()
cur.execute("SELECT user_id, email, department FROM users ORDER BY user_id")
users = cur.fetchall()
conn.close()

print("=" * 65)
for user_id, email, dept in users:
    r = requests.get(f'http://localhost:8002/recommendations/{user_id}?top_n=3', timeout=30)
    if r.status_code == 200:
        data = r.json()
        print(f"\nUser {user_id} | {dept}")
        if data:
            for b in data:
                print(f"  ✅ {b['title']} ({b['match_percentage']}%)")
        else:
            print(f"  ⚠️  Bölüme uygun kitap bulunamadı")
    else:
        print(f"\nUser {user_id} | HATA: {r.status_code}")
print("=" * 65)
