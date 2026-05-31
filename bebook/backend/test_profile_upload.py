import requests
import os

BASE_URL = "http://localhost:8001"
USER_ID = 18

# Küçük bir test görseli oluştur (1x1 px PNG)
import struct, zlib

def create_test_png():
    def png_chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    
    signature = b'\x89PNG\r\n\x1a\n'
    ihdr = png_chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
    idat = png_chunk(b'IDAT', zlib.compress(b'\x00\xff\x00\x00'))
    iend = png_chunk(b'IEND', b'')
    return signature + ihdr + idat + iend

png_data = create_test_png()

# Test yükle
print(f"Test: /user/profile/{USER_ID}")
r = requests.get(f"{BASE_URL}/user/profile/{USER_ID}")
print(f"  GET profile: {r.status_code} - {r.json()}")

print(f"\nTest: /user/upload_profile_photo/{USER_ID}")
r = requests.post(
    f"{BASE_URL}/user/upload_profile_photo/{USER_ID}",
    files={"file": ("test.png", png_data, "image/png")}
)
print(f"  POST upload: {r.status_code} - {r.text}")

if r.status_code == 200:
    data = r.json()
    image_path = data.get("image_path", "")
    print(f"  image_path: {image_path}")
    
    # Dosya gerçekten var mı?
    if os.path.exists(image_path):
        print(f"  ✅ Dosya mevcut: {image_path}")
    else:
        print(f"  ❌ Dosya bulunamadı: {image_path}")
    
    # URL ile erişilebilir mi?
    url_path = image_path.replace("\\", "/")
    if not url_path.startswith("http"):
        url_path = f"{BASE_URL}/{url_path}"
    r2 = requests.get(url_path)
    print(f"  GET image URL ({url_path}): {r2.status_code}")
