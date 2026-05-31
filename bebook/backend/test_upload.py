#!/usr/bin/env python3
"""
Bebook - Görsel Yükleme Test Script'i
Bu script, görsel yükleme işleminin doğru çalışıp çalışmadığını test eder.
"""

import requests
import os
from pathlib import Path

# Test ayarları
BASE_URL = "http://192.168.0.14:8002"  # Güncel IP adresi
TEST_IMAGE_PATH = "test_book_cover.jpg"  # Test için bir görsel oluşturun

def create_test_image():
    """Test için basit bir görsel oluştur"""
    try:
        from PIL import Image, ImageDraw, ImageFont
        
        # 300x400 boyutunda test görseli
        img = Image.new('RGB', (300, 400), color=(106, 99, 255))
        draw = ImageDraw.Draw(img)
        
        # Metin ekle
        text = "TEST\nGÖRSEL"
        draw.text((100, 180), text, fill=(255, 255, 255))
        
        img.save(TEST_IMAGE_PATH)
        print(f"✅ Test görseli oluşturuldu: {TEST_IMAGE_PATH}")
        return True
    except ImportError:
        print("⚠️ PIL/Pillow yüklü değil. Manuel olarak test_book_cover.jpg ekleyin.")
        return False

def test_upload():
    """Kitap yükleme endpoint'ini test et"""
    print("\n🧪 Görsel Yükleme Testi Başlıyor...\n")
    
    # Test görseli yoksa oluştur
    if not os.path.exists(TEST_IMAGE_PATH):
        if not create_test_image():
            print("❌ Test görseli bulunamadı. Lütfen 'test_book_cover.jpg' ekleyin.")
            return
    
    # Test verisi
    data = {
        'title': 'Test Kitabı',
        'author': 'Test Yazar',
        'category': 'Test Kategori',
        'publisher': 'Test Yayınevi',
        'price': '99.99',
        'description': 'Bu bir test kitabıdır.',
        'seller_email': 'test@example.com'
    }
    
    # Görseli aç
    with open(TEST_IMAGE_PATH, 'rb') as img_file:
        files = {'image': (TEST_IMAGE_PATH, img_file, 'image/jpeg')}
        
        print("📤 Backend'e gönderiliyor...")
        print(f"   URL: {BASE_URL}/books")
        print(f"   Görsel: {TEST_IMAGE_PATH}")
        
        try:
            response = requests.post(
                f"{BASE_URL}/books",
                data=data,
                files=files,
                timeout=10
            )
            
            print(f"\n📥 Yanıt Alındı:")
            print(f"   Status Code: {response.status_code}")
            print(f"   Response: {response.json()}")
            
            if response.status_code == 200:
                print("\n✅ Yükleme başarılı!")
                
                # Şimdi kitapları çek ve kontrol et
                print("\n🔍 Yüklenen kitap kontrol ediliyor...")
                books_response = requests.get(f"{BASE_URL}/books")
                
                if books_response.status_code == 200:
                    books = books_response.json()
                    if books:
                        latest_book = books[-1]  # Son eklenen kitap
                        print(f"\n📚 Son Eklenen Kitap:")
                        print(f"   ID: {latest_book.get('id')}")
                        print(f"   Başlık: {latest_book.get('title')}")
                        print(f"   Görsel Yolu: {latest_book.get('image_path')}")
                        
                        # Görsel yolunu kontrol et
                        image_path = latest_book.get('image_path', '')
                        if image_path.startswith('/uploads/'):
                            print(f"\n✅ Görsel yolu doğru formatta: {image_path}")
                            
                            # Görselin erişilebilir olup olmadığını kontrol et
                            full_url = f"{BASE_URL}{image_path}"
                            print(f"\n🌐 Görsel URL'si test ediliyor: {full_url}")
                            
                            img_response = requests.get(full_url, timeout=5)
                            if img_response.status_code == 200:
                                print(f"✅ Görsel başarıyla erişilebilir!")
                                print(f"   Content-Type: {img_response.headers.get('content-type')}")
                                print(f"   Boyut: {len(img_response.content)} bytes")
                            else:
                                print(f"❌ Görsel erişilemedi! Status: {img_response.status_code}")
                        else:
                            print(f"❌ Görsel yolu yanlış formatta: {image_path}")
                            print(f"   Beklenen: /uploads/...")
                    else:
                        print("⚠️ Henüz kitap bulunamadı")
            else:
                print(f"\n❌ Yükleme başarısız!")
                print(f"   Hata: {response.text}")
                
        except requests.exceptions.ConnectionError:
            print(f"\n❌ Bağlantı hatası! Backend çalışıyor mu?")
            print(f"   URL: {BASE_URL}")
            print(f"   Kontrol: Backend'i başlatmak için 'uvicorn main:app --reload --host 0.0.0.0 --port 8000'")
        except Exception as e:
            print(f"\n❌ Beklenmeyen hata: {e}")

def test_static_files():
    """Static files endpoint'ini test et"""
    print("\n🧪 Static Files Testi...\n")
    
    try:
        # Backend'deki uploads klasörünü kontrol et
        backend_dir = Path(__file__).parent
        uploads_dir = backend_dir / "uploads"
        
        print(f"📁 Uploads klasörü: {uploads_dir}")
        
        if uploads_dir.exists():
            files = list(uploads_dir.glob("*"))
            print(f"✅ Uploads klasörü mevcut")
            print(f"   Dosya sayısı: {len(files)}")
            
            if files:
                print(f"\n📄 İlk 5 dosya:")
                for f in files[:5]:
                    print(f"   - {f.name} ({f.stat().st_size} bytes)")
                    
                # İlk dosyayı test et
                test_file = files[0]
                test_url = f"{BASE_URL}/uploads/{test_file.name}"
                print(f"\n🌐 Test URL: {test_url}")
                
                response = requests.get(test_url, timeout=5)
                if response.status_code == 200:
                    print(f"✅ Static file erişilebilir!")
                else:
                    print(f"❌ Static file erişilemedi! Status: {response.status_code}")
            else:
                print("⚠️ Uploads klasörü boş")
        else:
            print(f"❌ Uploads klasörü bulunamadı!")
            print(f"   Backend başlatıldığında otomatik oluşturulmalı")
            
    except Exception as e:
        print(f"❌ Hata: {e}")

if __name__ == "__main__":
    print("=" * 60)
    print("🚀 BEBOOK - GÖRSEL YÜKLEME TEST ARACI")
    print("=" * 60)
    
    # 1. Static files testi
    test_static_files()
    
    # 2. Upload testi
    test_upload()
    
    print("\n" + "=" * 60)
    print("✨ Test tamamlandı!")
    print("=" * 60)
