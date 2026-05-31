import requests

users = [18, 20, 9]
for u in users:
    r = requests.get(f'http://localhost:8002/recommendations/{u}?top_n=3', timeout=30)
    data = r.json()
    print(f"\n=== User {u} ===")
    if isinstance(data, list):
        for b in data:
            print(f"  {b['title']} ({b['department']}) - {b['match_percentage']}%")
    else:
        print(f"  Hata: {data}")
