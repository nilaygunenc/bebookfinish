import requests

# Endpoint'in içindeki print'leri görmek için direkt çağır
r = requests.get("http://localhost:8001/recommendations/18?top_n=6")
print("Status:", r.status_code)
print("Response:", r.text[:500])
