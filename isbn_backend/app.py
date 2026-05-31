from flask import Flask, request, jsonify
import cv2
import numpy as np
from pyzbar.pyzbar import decode
import requests
from flask_cors import CORS
from bs4 import BeautifulSoup
import cloudscraper

app = Flask(__name__)
CORS(app)

scraper = cloudscraper.create_scraper()

# BOT KORUMALARINI AŞMAK İÇİN GLOBAL TARAYICI KİMLİĞİMİZ
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7"
}

@app.route("/")
def home():
    return "Backend çalışıyor 🚀"

@app.route("/scan", methods=["POST"])
def scan_isbn():
    file = request.files["image"]
    npimg = np.frombuffer(file.read(), np.uint8)
    img = cv2.imdecode(npimg, cv2.IMREAD_COLOR)

    # 1. Önce gri tonlamaya çeviriyoruz
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    # 2. GÖRÜNTÜYÜ KÜÇÜLTÜYORUZ 
    height, width = gray.shape
    if width > 800:
        oran = 800.0 / width
        yeni_boyut = (800, int(height * oran))
        gray = cv2.resize(gray, yeni_boyut, interpolation=cv2.INTER_AREA)

    _, thresh = cv2.threshold(gray, 100, 255, cv2.THRESH_BINARY)

    decoded_objects = decode(thresh)

    if not decoded_objects:
        decoded_objects = decode(gray)

    isbn = None

    for obj in decoded_objects:
        barcode_data = obj.data.decode("utf-8").replace("-", "").strip()

        if barcode_data.isdigit() and (len(barcode_data) == 10 or len(barcode_data) == 13):
            isbn = barcode_data
            break

    if not isbn:
        return jsonify({"error": "Geçerli ISBN bulunamadı."})

    print(f"🎉 ISBN bulundu: {isbn}")
    
    # ... Google, Kitapyurdu vb. scraping kodlarınız buradan itibaren aynı şekilde devam edecek ...
    # ... Kodun geri kalanı aynı kalacak ...

# ---------------- GOOGLE BOOKS ----------------
    try:
        google_url = f"https://www.googleapis.com/books/v1/volumes?q=isbn:{isbn}&langRestrict=tr"
        response = requests.get(google_url, timeout=5)
        data = response.json()

        if "items" in data:
            kitap = data["items"][0]["volumeInfo"]
            return jsonify({
                "isbn": isbn,
                "title": kitap.get("title"),
                "author": ", ".join(kitap.get("authors", [])),
                "publisher": kitap.get("publisher"),
                "year": kitap.get("publishedDate"),
                "source": "Google Books"
            })
    except:
        print("Google API hatası")

# ---------------- OPEN LIBRARY ----------------
    try:
        open_url = f"https://openlibrary.org/api/books?bibkeys=ISBN:{isbn}&format=json&jscmd=data"
        response = requests.get(open_url, timeout=5)
        data = response.json()
        book_data = data.get(f"ISBN:{isbn}")

        if book_data:
            return jsonify({
                "isbn": isbn,
                "title": book_data.get("title"),
                "author": ", ".join([a["name"] for a in book_data.get("authors", [])]),
                "publisher": ", ".join([p["name"] for p in book_data.get("publishers", [])]),
                "year": book_data.get("publish_date"),
                "source": "Open Library"
            })
    except:
        print("Open Library hatası")


# ---------------- D&R SCRAPING ----------------
    try:
        print("D&R aranıyor...")
        dr_url = f"https://www.dr.com.tr/search?q={isbn}"

        response = scraper.get(dr_url, headers=HEADERS)
        soup = BeautifulSoup(response.text, "html.parser")

        title = None
        author = "Kolektif"
        publisher = None # Yayınevi değişkenimizi ekledik

        # 1. Kitap Adını Çekme (Senin önceki bulduğun div ve h1 yapısı)
        prd_name_div = soup.find("div", class_="prd-name")
        if prd_name_div:
            h1_tag = prd_name_div.find("h1")
            if h1_tag:
                title = h1_tag.text.strip()
        
        if not title:
            h1_alt = soup.find("h1", class_="js-text-prd-name") or soup.find("h1", class_="prd-name")
            if h1_alt:
                title = h1_alt.text.strip()

        # 2. Yazar ve Yayınevini Çekme (Güncel HTML yapısına göre 🎯)
        
      # --- YAZAR ---
        author = "Kolektif" # Bulamazsa varsayılan olarak bu kalacak
        
        # 1. Aşama: authors-wrapper içindeki yazar(lar)ı bulma (Birden fazla yazar varsa virgülle ayırır)
        authors_wrapper = soup.find("div", class_="authors-wrapper")
        if authors_wrapper:
            author_tag = authors_wrapper.find("h2", class_="author")
            if author_tag:
                yazar_linkleri = author_tag.find_all("a")
                if yazar_linkleri:
                    author = ", ".join([a.text.strip() for a in yazar_linkleri])

        # 2. Aşama (B Planı): Eğer yukarıdaki yapı yoksa, sitenin herhangi bir yerinde linkinde "/yazar/" geçen etiketi bul
        if author == "Kolektif":
            yazar_link = soup.find("a", href=lambda h: h and "/yazar/" in h.lower())
            if yazar_link:
                author = yazar_link.text.strip()
                
        # 3. Aşama (C Planı): Özellikler tablosunun içinde "Yazar:" yazısını arayıp yanındaki değeri alma
        if author == "Kolektif":
            yazar_etiketi = soup.find("strong", string=lambda t: t and "Yazar:" in t)
            if yazar_etiketi:
                yazar_span = yazar_etiketi.find_next_sibling("span")
                if yazar_span:
                    author = yazar_span.text.strip()

        # --- YAYINEVİ ---
        # 1. Aşama: Attığın fotoğraftaki yapı (id="publisherName" içindeki 'a' etiketi)
        publisher_div = soup.find("div", id="publisherName")
        if publisher_div and publisher_div.find("a"):
            publisher = publisher_div.find("a").text.strip()
            
        # 2. Aşama (B Planı): Eğer yukarıdaki div yoksa, sitenin herhangi bir yerinde 
        # linki "/yayinevi/" ile başlayan etiketi bul (Fotoğrafta a href="..." içinde bu net görünüyor)
        if not publisher:
            yayinevi_link = soup.find("a", href=lambda h: h and "/yayinevi/" in h.lower())
            if yayinevi_link:
                publisher = yayinevi_link.text.strip()

        if title:
            print(f"🎉 D&R bulundu: {title} | Yazar: {author} | Yayınevi: {publisher}")
            return jsonify({
                "isbn": isbn,
                "title": title,
                "author": author,
                "publisher": publisher,
                "year": None,
                "source": "D&R"
            })
        else:
            print("D&R: Siteye girildi ama div class='prd-name' içindeki h1 başlığı bulunamadı.")

    except Exception as e:
        print("D&R scraping hatası:", e)

# ---------------- KİTAPSEÇ SCRAPING ----------------
    try:
        print("Kitapseç'te arama çubuğuna yazılıyor...")
        # 1. Adım: Arama simülasyonu
        arama_url = f"https://www.kitapsec.com/Arama/index.php?a={isbn}"
        response = scraper.get(arama_url, headers=HEADERS)
        soup = BeautifulSoup(response.text, "html.parser")

        title = None
        author = "Kolektif"
        publisher = None 

        # 2. Adım: Acaba arama yapınca Kitapseç bizi doğrudan kitabın içine mi attı?
        ust_cerceve = soup.find("div", class_="Ks_DetayCerceveUst")

        # EĞER KİTABIN İÇİNDE DEĞİLSEK (ARAMA LİSTESİNDEYSEK):
        if not ust_cerceve:
            print("Kitapseç: Arama listesindeyiz. İlk kitaba tıklanıp içine giriliyor...")
            
            ilk_kitap_linki = None
            # Çıkan listedeki tüm linkleri tarayıp ilk "GERÇEK" kitabın linkini alıyoruz
            for a_tag in soup.find_all("a", href=True):
                href = a_tag["href"]
                # Gerçek ürün linkleri /Products/ ile başlar ve .html ile biter
                if "/Products/" in href and href.endswith(".html"):
                    ilk_kitap_linki = href
                    break # İlk kitabı bulduk, aramayı bırak!
            
            # 3. Adım: Bulduğumuz o ilk kitabın üstüne tıklayıp sayfasına giriyoruz
            if ilk_kitap_linki:
                if not ilk_kitap_linki.startswith("http"):
                    ilk_kitap_linki = "https://www.kitapsec.com" + ilk_kitap_linki
                
                # Linke tıklama simülasyonu
                response = scraper.get(ilk_kitap_linki, headers=HEADERS)
                soup = BeautifulSoup(response.text, "html.parser")
                
                # Yeni açılan sayfanın (kitabın içinin) HTML'inde o büyük çerçeveyi tekrar arıyoruz
                ust_cerceve = soup.find("div", class_="Ks_DetayCerceveUst")
            else:
                print("Kitapseç: Arama yapıldı ama çıkan listede tıklanacak bir kitap bulunamadı.")

        # 4. Adım: Artık kitabın içindeyiz, senin bulduğun sınıflardan veriyi çekelim!
        if ust_cerceve:
            sag_blok = ust_cerceve.find("div", class_="dty_SagBlok relative")
            if sag_blok:
                h1_tag = sag_blok.find("h1")
                if h1_tag:
                    title = h1_tag.text.strip()

        # Sonuç Değerlendirmesi
        if title:
            print(f"🎉 Kitapseç bulundu: {title}")
            return jsonify({
                "isbn": isbn,
                "title": title,
                "author": author,
                "publisher": publisher,
                "year": None,
                "source": "Kitapseç"
            })
        else:
            print("Kitapseç: İşlem başarısız. Kitabın içine girildi ama başlık bulunamadı.")

    except Exception as e:
        print("Kitapseç scraping hatası:", e)
# ---------------- SON DURUM ----------------
    return jsonify({
        "error": "Kitap hiçbir veritabanında bulunamadı."
    })

if __name__ == "__main__":
    print("🚀 ISBN Backend başlatılıyor: http://192.168.0.14:8001")
    app.run(host="0.0.0.0", port=8001, debug=False, threaded=True)

