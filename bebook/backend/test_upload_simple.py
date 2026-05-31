#!/usr/bin/env python3
"""
Basit Upload Test - Görsel yükleme sorununu debug et
"""

import os
import sys

print("=" * 60)
print("🔍 BEBOOK - GÖRSEL YÜKLEME DEBUG")
print("=" * 60)

# 1. Backend dizinini kontrol et
backend_dir = os.path.dirname(os.path.abspath(__file__))
print(f"\n📁 Backend Dizini: {backend_dir}")

# 2. Uploads klasörünü kontrol et
upload_dir = os.path.join(backend_dir, "uploads")
print(f"📁 Uploads Dizini: {upload_dir}")

if os.path.exists(upload_dir):
    print("✅ Uploads klasörü mevcut")
    
    # Dosyaları listele
    files = os.listdir(upload_dir)
    print(f"\n📄 Dosya Sayısı: {len(files)}")
    
    if files:
        print("\n📋 Son 10 Dosya:")
        for i, f in enumerate(sorted(files, key=lambda x: os.path.getmtime(os.path.join(upload_dir, x)), reverse=True)[:10], 1):
            file_path = os.path.join(upload_dir, f)
            size = os.path.getsize(file_path)
            print(f"   {i}. {f} ({size} bytes)")
    else:
        print("⚠️ Uploads klasörü boş!")
        print("\n💡 Çözüm:")
        print("   1. Backend'i başlatın: uvicorn main:app --reload --host 0.0.0.0 --port 8000")
        print("   2. Flutter'dan bir kitap yükleyin")
        print("   3. Bu script'i tekrar çalıştırın")
else:
    print("❌ Uploads klasörü bulunamadı!")
    print("\n💡 Çözüm:")
    print("   1. Backend'i başlatın (otomatik oluşturulacak)")
    print("   2. Veya manuel oluşturun: mkdir uploads")

# 3. main.py'daki UPLOAD_DIR tanımını kontrol et
main_py = os.path.join(backend_dir, "main.py")
if os.path.exists(main_py):
    print(f"\n📄 main.py dosyası bulundu")
    with open(main_py, 'r', encoding='utf-8') as f:
        content = f.read()
        if 'UPLOAD_DIR' in content:
            print("✅ UPLOAD_DIR tanımı mevcut")
        else:
            print("❌ UPLOAD_DIR tanımı bulunamadı!")
            print("   main.py dosyasını kontrol edin")

# 4. Yazma izinlerini kontrol et
print(f"\n🔐 İzin Kontrolü:")
if os.path.exists(upload_dir):
    if os.access(upload_dir, os.W_OK):
        print("✅ Uploads klasörüne yazma izni var")
    else:
        print("❌ Uploads klasörüne yazma izni yok!")
        print("   Klasör izinlerini kontrol edin")
else:
    print("⚠️ Uploads klasörü yok, izin kontrolü yapılamadı")

print("\n" + "=" * 60)
print("✨ Debug tamamlandı!")
print("=" * 60)

# 5. Öneriler
print("\n📝 SONRAKİ ADIMLAR:")
print("   1. pgAdmin4'te debug_images.sql'i çalıştırın")
print("   2. Backend loglarını kontrol edin")
print("   3. Yeni bir kitap yükleyin ve bu klasörü tekrar kontrol edin")
