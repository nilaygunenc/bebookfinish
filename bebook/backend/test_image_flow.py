#!/usr/bin/env python3
"""
Görsel Akışını Test Et - Hangi görsel hangi kitaba ait?
"""

import psycopg2
import os

print("=" * 70)
print("🔍 GÖRSEL AKIŞI ANALİZİ")
print("=" * 70)

# Veritabanı bağlantısı
try:
    conn = psycopg2.connect(
        host="localhost",
        database="bebook",
        user="postgres",
        password="senem2003",
        port="5432"
    )
    print("✅ Veritabanına bağlanıldı\n")
    
    cur = conn.cursor()
    
    # 1. Son eklenen 5 kitabı getir
    print("📚 SON EKLENEN 5 KİTAP:")
    print("-" * 70)
    cur.execute("""
        SELECT id, title, image_path, seller_email, created_at
        FROM public.books
        ORDER BY created_at DESC
        LIMIT 5
    """)
    
    books = cur.fetchall()
    for book in books:
        book_id, title, image_path, seller, created = book
        print(f"\n🔹 ID: {book_id}")
        print(f"   Başlık: {title}")
        print(f"   Görsel: {image_path}")
        print(f"   Satıcı: {seller}")
        print(f"   Tarih: {created}")
        
        # Görsel dosyasının varlığını kontrol et
        if image_path and image_path.startswith('/uploads/'):
            file_name = image_path.replace('/uploads/', '')
            file_path = os.path.join(os.path.dirname(__file__), 'uploads', file_name)
            
            if os.path.exists(file_path):
                size = os.path.getsize(file_path)
                print(f"   ✅ Dosya mevcut ({size} bytes)")
            else:
                print(f"   ❌ Dosya bulunamadı: {file_path}")
        elif not image_path or image_path == '':
            print(f"   ⚠️ Görsel yolu boş")
        else:
            print(f"   ⚠️ Yanlış format: {image_path}")
    
    # 2. Aynı görseli kullanan kitapları bul
    print("\n\n" + "=" * 70)
    print("🔍 AYNI GÖRSELİ KULLANAN KİTAPLAR:")
    print("-" * 70)
    
    cur.execute("""
        SELECT image_path, COUNT(*) as count, STRING_AGG(title, ' | ') as titles
        FROM public.books
        WHERE image_path IS NOT NULL AND image_path != ''
        GROUP BY image_path
        HAVING COUNT(*) > 1
    """)
    
    duplicates = cur.fetchall()
    if duplicates:
        for dup in duplicates:
            image_path, count, titles = dup
            print(f"\n⚠️ Görsel: {image_path}")
            print(f"   Kullanım: {count} kitap")
            print(f"   Kitaplar: {titles}")
    else:
        print("✅ Görsel karışıklığı yok, her kitabın kendi görseli var")
    
    # 3. Uploads klasöründeki dosyaları kontrol et
    print("\n\n" + "=" * 70)
    print("📁 UPLOADS KLASÖRÜNDE BULUNAN DOSYALAR:")
    print("-" * 70)
    
    upload_dir = os.path.join(os.path.dirname(__file__), 'uploads')
    if os.path.exists(upload_dir):
        files = os.listdir(upload_dir)
        print(f"\nToplam dosya: {len(files)}\n")
        
        for f in files:
            file_path = os.path.join(upload_dir, f)
            size = os.path.getsize(file_path)
            
            # Bu dosyayı kullanan kitapları bul
            cur.execute("""
                SELECT id, title
                FROM public.books
                WHERE image_path = %s
            """, (f'/uploads/{f}',))
            
            using_books = cur.fetchall()
            
            print(f"📄 {f} ({size} bytes)")
            if using_books:
                for book_id, title in using_books:
                    print(f"   → Kitap #{book_id}: {title}")
            else:
                print(f"   ⚠️ Bu dosyayı kullanan kitap yok (eski/silinmiş)")
    
    # 4. Veritabanında kayıtlı ama dosyası olmayan görseller
    print("\n\n" + "=" * 70)
    print("⚠️ KAYITLI AMA DOSYASI OLMAYAN GÖRSELLER:")
    print("-" * 70)
    
    cur.execute("""
        SELECT id, title, image_path
        FROM public.books
        WHERE image_path IS NOT NULL AND image_path != ''
        ORDER BY created_at DESC
    """)
    
    all_books = cur.fetchall()
    missing_count = 0
    
    for book_id, title, image_path in all_books:
        if image_path.startswith('/uploads/'):
            file_name = image_path.replace('/uploads/', '')
            file_path = os.path.join(upload_dir, file_name)
            
            if not os.path.exists(file_path):
                missing_count += 1
                print(f"\n❌ Kitap #{book_id}: {title}")
                print(f"   Beklenen: {file_path}")
    
    if missing_count == 0:
        print("\n✅ Tüm görseller mevcut")
    else:
        print(f"\n⚠️ Toplam {missing_count} eksik görsel")
    
    conn.close()
    
except Exception as e:
    print(f"❌ Hata: {e}")

print("\n" + "=" * 70)
print("✨ Analiz tamamlandı!")
print("=" * 70)

print("\n💡 SORUN TESPİTİ:")
print("   1. Eğer 'Aynı görseli kullanan kitaplar' varsa:")
print("      → Backend'de dosya kaydetme sırasında hata var")
print("   2. Eğer 'Dosyası olmayan görseller' varsa:")
print("      → Dosyalar yüklenmiyor veya yanlış yere kaydediliyor")
print("   3. Eğer her şey normal görünüyorsa:")
print("      → Flutter tarafında cache sorunu olabilir")
