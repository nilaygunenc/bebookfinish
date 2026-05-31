# 📚 Bebook - Üniversite Kitap Satış Uygulaması

Flutter (Web/Android) + FastAPI + PostgreSQL ile geliştirilmiş ikinci el üniversite kitabı alım-satım platformu.

---

## 🚀 Projeyi Ayağa Kaldırma

### Gereksinimler
- [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/web) (PATH'e ekli olmalı)
- Python 3.10+
- PostgreSQL 18
- Google Chrome

---

### 1. PostgreSQL Veritabanı
pgAdmin veya psql ile `bebook` adında bir veritabanı oluşturun.  
Bağlantı bilgilerini `backend/main.py` içindeki `get_db_connection()` fonksiyonunda güncelleyin:
```python
host="localhost"
database="bebook"
user="postgres"
password="SENIN_SIFREN"
port="5432"
```

---

### 2. Backend (FastAPI)

```bash
cd backend

# Gerekli paketleri kur (ilk seferinde)
pip install uvicorn fastapi psycopg2-binary bcrypt iyzipay python-multipart

# Sunucuyu başlat
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Backend `http://localhost:8000` adresinde çalışır.

---

### 3. Flutter (Chrome)

```bash
# Web desteğini aktif et (ilk seferinde)
flutter config --enable-web

# Bağımlılıkları yükle (ilk seferinde)
flutter pub get

# Chrome'da çalıştır
flutter run -d chrome
```

> **Not:** `lib/services/api_service.dart` dosyasındaki `baseUrl` değerini kendi lokal IP adresinizle güncelleyin:
> ```dart
> static const String baseUrl = "http://SENIN_IP_ADRESIN:8000";
> ```
> IP adresinizi öğrenmek için terminalde `ipconfig` komutunu çalıştırın.

---

## 🛠️ Yapılan Düzeltmeler

- **IP adresi güncellendi:** Tüm Dart dosyalarındaki sabit IP adresleri (`10.108.206.156`) yeni IP ile değiştirildi.
- **Veritabanı şifresi düzeltildi:** Backend PostgreSQL bağlantısı güncellendi.
- **Favoriler endpoint hatası giderildi:** `books` tablosunda `book_id` yerine `id` kolonu kullanılıyordu, sorgu düzeltildi.
- **Görsel URL'leri normalize edildi:** Veritabanındaki `image_path` alanları tam URL formatına (`http://IP:8000/uploads/...`) güncellendi.
- **Düzenle/Sil butonları eklendi:** Profil → "Satışa Sunduğum Kitaplar" ekranında her ilan için düzenleme ve silme butonları eklendi.
- **Kart layout yeniden düzenlendi:** `isMyPost` kartları için taşma (overflow) sorunu giderildi, yatay kart tasarımı uygulandı.
- **Gereksiz .md dosyaları temizlendi:** Geliştirme sürecinde oluşturulan 10 adet not dosyası silindi.

---

## 📁 Proje Yapısı

```
bebook/
├── lib/
│   ├── features/       # Ekranlar (home, profile, cart, payment...)
│   ├── models/         # Veri modelleri
│   ├── services/       # API servisi
│   └── widgets/        # Ortak widget'lar
├── backend/
│   ├── main.py         # FastAPI uygulaması
│   └── uploads/        # Yüklenen görseller
└── android/            # Android yapılandırması
```
