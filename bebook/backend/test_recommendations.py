import requests

r = requests.get("http://localhost:8001/recommendations/18?top_n=6")
data = r.json()
print(f"Status: {r.status_code}")
print(f"Oneri sayisi: {len(data)}")
if data and isinstance(data, list):
    for i, b in enumerate(data[:6], 1):
        title = b.get("title", "?")
        pct = b.get("match_percentage", 0)
        price = b.get("price", 0)
        print(f"  {i}. [{pct}%] {title} - {price} TL")
else:
    print("Veri:", data)
