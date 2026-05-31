import requests

# Tıp bölümü kullanıcısı (user_id=22, gfds@gmail.com, Tıp)
r = requests.get('http://localhost:8002/recommendations/22?top_n=6', timeout=30)
data = r.json()
print("=== Tıp Bölümü Önerileri ===")
for b in data:
    print(f"  {b['title']} | Bölüm: {b['department']} | Skor: {b['match_percentage']}%")
