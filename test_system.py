import requests

print("=" * 50)
print("  BEBOOK SISTEM KONTROL")
print("=" * 50)
print()

endpoints = [
    ("Kitaplar Listesi", "http://192.168.0.14:8002/books"),
    ("Oneriler (User 18)", "http://192.168.0.14:8002/recommendations/18?top_n=6"),
    ("Favoriler (User 18)", "http://192.168.0.14:8002/favorites/18"),
    ("Mesajlar (User 18)", "http://192.168.0.14:8002/chats/18"),
    ("Kullanici Kitaplari", "http://192.168.0.14:8002/my-books/18"),
]

errors = []

for name, url in endpoints:
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            print(f"✓ {name}: OK")
        else:
            print(f"✗ {name}: HATA (Status: {r.status_code})")
            errors.append(f"{name} - Status {r.status_code}")
    except Exception as e:
        print(f"✗ {name}: BAGLANTI HATASI")
        errors.append(f"{name} - {str(e)}")

print()
print("=" * 50)
if errors:
    print("  HATALAR BULUNDU:")
    for err in errors:
        print(f"  - {err}")
else:
    print("  ✓ TUM SISTEMLER CALISIYOR!")
print("=" * 50)
