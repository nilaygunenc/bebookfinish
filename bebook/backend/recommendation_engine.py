"""
Bebook - Dinamik İçerik Tabanlı Filtreleme Öneri Motoru
========================================================
Kurallar:
  1. Giriş yapmayan kullanıcıya öneri verilmez.
  2. Tüm veriler dışarıdan (DataFrame) parametre olarak alınır → dinamik yapı.
  3. Kullanıcının "department" alanı baz alınarak Cosine Similarity hesaplanır.
  4. Yeni kullanıcı / kitap eklendiğinde sistem otomatik güncellenir.
"""

import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from typing import Optional


# ─────────────────────────────────────────────
# KURAL 1 – GİRİŞ KONTROLÜ
# ─────────────────────────────────────────────

def is_logged_in(user_id: Optional[int]) -> bool:
    """
    Kullanıcının giriş yapıp yapmadığını kontrol eder.
    user_id None veya 0 ise giriş yapılmamış sayılır.
    """
    return user_id is not None and user_id > 0


# ─────────────────────────────────────────────
# KURAL 2 – ÖZELLİK METNİ OLUŞTURMA (dinamik)
# ─────────────────────────────────────────────

def build_book_feature_text(row: pd.Series) -> str:
    """
    Bir kitap satırından TF-IDF için özellik metni üretir.
    Bölüm 3×, kategori/açıklama 1× ağırlıklandırılır.
    """
    department = " ".join([str(row.get("department", ""))] * 3)
    category   = str(row.get("category", ""))
    title      = str(row.get("title", ""))
    author     = str(row.get("author", ""))
    desc       = str(row.get("description", ""))
    return f"{department} {category} {title} {author} {desc}".strip()


def build_user_profile_text(row: pd.Series) -> str:
    """
    Bir kullanıcı satırından TF-IDF için profil metni üretir.
    Bölüm 3× ağırlıklandırılır.
    """
    department = " ".join([str(row.get("department", ""))] * 3)
    university = str(row.get("university", ""))
    return f"{department} {university}".strip()


# ─────────────────────────────────────────────
# KURAL 3 – COSINE SIMILARITY TABANLI ÖNERİ
# ─────────────────────────────────────────────

def get_recommendations(
    user_id: int,
    users_df: pd.DataFrame,
    books_df: pd.DataFrame,
    top_n: int = 5
) -> list[dict]:
    """
    Belirli bir kullanıcı için kişiselleştirilmiş kitap önerileri döndürür.

    Parametreler
    ------------
    user_id   : Giriş yapmış kullanıcının ID'si
    users_df  : Tüm kullanıcıları içeren DataFrame (veritabanından dinamik çekilir)
    books_df  : Tüm kitapları içeren DataFrame  (veritabanından dinamik çekilir)
    top_n     : Kaç öneri döndürüleceği (varsayılan 5)

    Döndürür
    --------
    Öneri listesi: [{"book_id", "title", "author", "department",
                     "price", "similarity_score", "match_percentage"}, ...]
    """

    # ── Kural 1: Giriş kontrolü ──────────────────────────────────────────
    if not is_logged_in(user_id):
        raise PermissionError("Kişiselleştirilmiş öneriler için giriş yapmalısınız.")

    # ── Kullanıcıyı bul ──────────────────────────────────────────────────
    user_row = users_df[users_df["user_id"] == user_id]
    if user_row.empty:
        raise ValueError(f"user_id={user_id} bulunamadı.")
    user_row = user_row.iloc[0]

    # ── Satılmamış kitapları filtrele ─────────────────────────────────────
    if "is_sold" in books_df.columns:
        available_books = books_df[books_df["is_sold"] != True].copy()
    else:
        available_books = books_df.copy()
    if available_books.empty:
        return []

    # ── Özellik metinlerini oluştur (dinamik) ────────────────────────────
    available_books["feature_text"] = available_books.apply(build_book_feature_text, axis=1)
    user_text = build_user_profile_text(user_row)

    # ── TF-IDF vektörizasyonu ─────────────────────────────────────────────
    vectorizer = TfidfVectorizer(ngram_range=(1, 2), max_features=500)

    # Kullanıcı profili + kitap metinlerini birlikte fit et
    all_texts = [user_text] + available_books["feature_text"].tolist()
    vectorizer.fit(all_texts)

    user_vec  = vectorizer.transform([user_text])
    book_vecs = vectorizer.transform(available_books["feature_text"])

    # ── Cosine Similarity ─────────────────────────────────────────────────
    import numpy as np
    scores = cosine_similarity(user_vec, book_vecs)[0]
    # NaN / Inf değerlerini temizle
    scores = np.nan_to_num(scores, nan=0.0, posinf=0.0, neginf=0.0)
    available_books = available_books.copy()
    available_books["similarity_score"] = scores

    # ── Top-N seç — minimum eşik: 0.05 (5%) ──────────────────────────────
    # Önce bölüme uygun kitapları filtrele (skor > 0.05)
    MIN_SCORE = 0.05
    relevant_books = available_books[available_books["similarity_score"] >= MIN_SCORE]
    
    if relevant_books.empty:
        # Hiç uygun kitap yoksa boş liste döndür
        return []
    
    top_books = relevant_books.nlargest(top_n, "similarity_score")

    # ── Sonuçları formatla ────────────────────────────────────────────────
    results = []
    for _, book in top_books.iterrows():
        score = float(book["similarity_score"])
        # Güvenli float dönüşümü
        if not np.isfinite(score):
            score = 0.0
        results.append({
            "book_id":          int(book["book_id"]),
            "title":            book.get("title", ""),
            "author":           book.get("author", ""),
            "department":       book.get("department", ""),
            "category":         book.get("category", ""),
            "price":            float(book.get("price", 0)),
            "seller_email":     book.get("seller_email", ""),
            "image_path":       book.get("image_path", None) if isinstance(book.get("image_path"), str) else None,
            "similarity_score": round(score, 4),
            "match_percentage": round(score * 100, 1),
        })

    return results


# ─────────────────────────────────────────────
# TEST VERİSİ (sadece demo/test için)
# ─────────────────────────────────────────────

def get_test_data():
    """
    Prompt'ta verilen örnek kullanıcı ve kitap verilerini döndürür.
    Gerçek sistemde bu veriler veritabanından çekilir.
    """

    users = pd.DataFrame([
        {"user_id": 1,  "email": "snsns@gmail.com",        "university": "İstanbul Teknik Üniversitesi",          "department": "Psikoloji"},
        {"user_id": 2,  "email": "nilaygunenc@gmail.com",   "university": "Zonguldak Bülent Ecevit Üniversitesi",  "department": "Psikoloji"},
        {"user_id": 3,  "email": "sateylul2@gmail.com",     "university": "İstanbul Teknik Üniversitesi",          "department": "İşletme"},
        {"user_id": 4,  "email": "sateylul5@gmail.com",     "university": "Diğer",                                 "department": "Psikoloji"},
        {"user_id": 5,  "email": "ilayda787@gmail.com",     "university": "Zonguldak Bülent Ecevit Üniversitesi",  "department": "Psikoloji"},
        {"user_id": 6,  "email": "nil@gmail.com",           "university": "Zonguldak Bülent Ecevit Üniversitesi",  "department": "Bilgisayar Mühendisliği"},
        {"user_id": 7,  "email": "a@gmail.com",             "university": "Zonguldak Bülent Ecevit Üniversitesi",  "department": "Tıp"},
        {"user_id": 8,  "email": "ahmet.yilmaz@gmail.com",  "university": "İTÜ",                                   "department": "Bilgisayar Mühendisliği"},
        {"user_id": 9,  "email": "ayse.demir@gmail.com",    "university": "ODTÜ",                                  "department": "Elektrik-Elektronik Mühendisliği"},
        {"user_id": 10, "email": "mehmet.kaya@gmail.com",   "university": "YTÜ",                                   "department": "İnşaat Mühendisliği"},
        {"user_id": 11, "email": "zeynep.celik@gmail.com",  "university": "Hacettepe Üniversitesi",                "department": "Psikoloji"},
        {"user_id": 12, "email": "can.arslan@gmail.com",    "university": "Boğaziçi Üniversitesi",                 "department": "İşletme"},
        {"user_id": 13, "email": "elif.sahin@gmail.com",    "university": "Ege Üniversitesi",                      "department": "Bilgisayar Mühendisliği"},
        {"user_id": 14, "email": "burak.kurt@gmail.com",    "university": "Gazi Üniversitesi",                     "department": "Elektrik-Elektronik Mühendisliği"},
        {"user_id": 15, "email": "selin.oz@gmail.com",      "university": "Marmara Üniversitesi",                  "department": "Psikoloji"},
        {"user_id": 16, "email": "emre.aydin@gmail.com",    "university": "Karadeniz Teknik Üniversitesi",         "department": "İnşaat Mühendisliği"},
        {"user_id": 17, "email": "deniz.turan@gmail.com",   "university": "Dokuz Eylül Üniversitesi",              "department": "İşletme"},
    ])

    books = pd.DataFrame([
        {"book_id": 9,  "title": "Clean Code",                              "author": "Robert C. Martin",    "department": "Bilgisayar Mühendisliği",         "category": "Yazılım",       "price": 320.00, "description": "Temiz kod yazma rehberi.",              "seller_email": "ahmet.yilmaz@gmail.com", "is_sold": False},
        {"book_id": 10, "title": "Introduction to Algorithms",              "author": "Thomas H. Cormen",    "department": "Bilgisayar Mühendisliği",         "category": "Algoritma",     "price": 850.00, "description": "Algoritmaların temel kitabı.",           "seller_email": "elif.sahin@gmail.com",   "is_sold": False},
        {"book_id": 11, "title": "Electric Circuits",                       "author": "Nilsson",             "department": "Elektrik-Elektronik Mühendisliği","category": "Devre",         "price": 600.00, "description": "Devre analizi kitabı.",                 "seller_email": "ayse.demir@gmail.com",   "is_sold": False},
        {"book_id": 12, "title": "Signals and Systems",                     "author": "Oppenheim",           "department": "Elektrik-Elektronik Mühendisliği","category": "Sinyal",        "price": 720.00, "description": "Sinyaller ve sistemler.",                "seller_email": "burak.kurt@gmail.com",   "is_sold": False},
        {"book_id": 13, "title": "Engineering Mechanics",                   "author": "Meriam",              "department": "İnşaat Mühendisliği",             "category": "Statik",        "price": 500.00, "description": "Statik kitabı.",                        "seller_email": "mehmet.kaya@gmail.com",  "is_sold": False},
        {"book_id": 14, "title": "Structural Analysis",                     "author": "Hibbeler",            "department": "İnşaat Mühendisliği",             "category": "Yapı",          "price": 650.00, "description": "Yapı analizi.",                         "seller_email": "emre.aydin@gmail.com",   "is_sold": False},
        {"book_id": 15, "title": "Thinking Fast and Slow",                  "author": "Daniel Kahneman",     "department": "Psikoloji",                       "category": "Psikoloji",     "price": 290.00, "description": "Düşünme sistemleri.",                   "seller_email": "zeynep.celik@gmail.com", "is_sold": False},
        {"book_id": 16, "title": "Man's Search for Meaning",                "author": "Viktor Frankl",       "department": "Psikoloji",                       "category": "Psikoloji",     "price": 180.00, "description": "Anlam arayışı.",                        "seller_email": "selin.oz@gmail.com",     "is_sold": False},
        {"book_id": 17, "title": "Principles of Marketing",                 "author": "Philip Kotler",       "department": "İşletme",                         "category": "Pazarlama",     "price": 400.00, "description": "Pazarlama kitabı.",                     "seller_email": "can.arslan@gmail.com",   "is_sold": False},
        {"book_id": 18, "title": "Rich Dad Poor Dad",                       "author": "Robert Kiyosaki",     "department": "İşletme",                         "category": "Finans",        "price": 150.00, "description": "Finans kitabı.",                        "seller_email": "deniz.turan@gmail.com",  "is_sold": False},
        {"book_id": 19, "title": "Design Patterns",                         "author": "Erich Gamma",         "department": "Bilgisayar Mühendisliği",         "category": "Yazılım",       "price": 420.00, "description": "Yazılım tasarım kalıpları.",            "seller_email": "ahmet.yilmaz@gmail.com", "is_sold": False},
        {"book_id": 20, "title": "The Pragmatic Programmer",                "author": "Andrew Hunt",         "department": "Bilgisayar Mühendisliği",         "category": "Yazılım",       "price": 380.00, "description": "Yazılım geliştirme pratikleri.",         "seller_email": "elif.sahin@gmail.com",   "is_sold": False},
        {"book_id": 21, "title": "Operating System Concepts",               "author": "Silberschatz",        "department": "Bilgisayar Mühendisliği",         "category": "İşletim",       "price": 700.00, "description": "İşletim sistemleri temel kitabı.",      "seller_email": "elif.sahin@gmail.com",   "is_sold": False},
        {"book_id": 22, "title": "Database System Concepts",                "author": "Abraham Silberschatz","department": "Bilgisayar Mühendisliği",         "category": "Veritabanı",    "price": 650.00, "description": "Veritabanı sistemleri.",                "seller_email": "ahmet.yilmaz@gmail.com", "is_sold": False},
        {"book_id": 23, "title": "Power System Analysis",                   "author": "Hadi Saadat",         "department": "Elektrik-Elektronik Mühendisliği","category": "Güç Sistemleri","price": 750.00, "description": "Güç sistemleri analizi.",               "seller_email": "ayse.demir@gmail.com",   "is_sold": False},
        {"book_id": 24, "title": "Digital Signal Processing",               "author": "Proakis",             "department": "Elektrik-Elektronik Mühendisliği","category": "DSP",           "price": 680.00, "description": "DSP temel kitabı.",                     "seller_email": "burak.kurt@gmail.com",   "is_sold": False},
        {"book_id": 25, "title": "Reinforced Concrete Design",              "author": "Jack McCormac",       "department": "İnşaat Mühendisliği",             "category": "Betonarme",     "price": 600.00, "description": "Betonarme tasarım.",                    "seller_email": "mehmet.kaya@gmail.com",  "is_sold": False},
        {"book_id": 26, "title": "Geotechnical Engineering",                "author": "Braja Das",           "department": "İnşaat Mühendisliği",             "category": "Zemin",         "price": 580.00, "description": "Zemin mekaniği.",                       "seller_email": "emre.aydin@gmail.com",   "is_sold": False},
        {"book_id": 27, "title": "Cognitive Psychology",                    "author": "Robert Sternberg",    "department": "Psikoloji",                       "category": "Psikoloji",     "price": 310.00, "description": "Bilişsel psikoloji.",                   "seller_email": "zeynep.celik@gmail.com", "is_sold": False},
        {"book_id": 28, "title": "Psychology of Learning",                  "author": "Edward Thorndike",    "department": "Psikoloji",                       "category": "Psikoloji",     "price": 260.00, "description": "Öğrenme psikolojisi.",                  "seller_email": "selin.oz@gmail.com",     "is_sold": False},
        {"book_id": 29, "title": "Management Principles",                   "author": "Stephen Robbins",     "department": "İşletme",                         "category": "Yönetim",       "price": 350.00, "description": "Yönetim ilkeleri.",                     "seller_email": "can.arslan@gmail.com",   "is_sold": False},
        {"book_id": 30, "title": "Financial Intelligence",                  "author": "Karen Berman",        "department": "İşletme",                         "category": "Finans",        "price": 280.00, "description": "Finansal okuryazarlık.",                "seller_email": "deniz.turan@gmail.com",  "is_sold": False},
        {"book_id": 31, "title": "Atomic Habits",                           "author": "James Clear",         "department": "Kişisel Gelişim",                 "category": "Gelişim",       "price": 200.00, "description": "Alışkanlık oluşturma kitabı.",          "seller_email": "can.arslan@gmail.com",   "is_sold": False},
        {"book_id": 32, "title": "Deep Work",                               "author": "Cal Newport",         "department": "Kişisel Gelişim",                 "category": "Gelişim",       "price": 210.00, "description": "Derin çalışma konsepti.",               "seller_email": "elif.sahin@gmail.com",   "is_sold": False},
        {"book_id": 33, "title": "Clean Architecture",                      "author": "Robert C. Martin",    "department": "Bilgisayar Mühendisliği",         "category": "Yazılım",       "price": 390.00, "description": "Yazılım mimarisi prensipleri.",         "seller_email": "nilaygunenc@gmail.com",  "is_sold": False},
        {"book_id": 34, "title": "Artificial Intelligence: A Modern Approach","author": "Stuart Russell",    "department": "Bilgisayar Mühendisliği",         "category": "Yapay Zeka",    "price": 950.00, "description": "Yapay zeka temel kitabı.",              "seller_email": "nilaygunenc@gmail.com",  "is_sold": False},
    ])

    return users, books


# ─────────────────────────────────────────────
# DEMO – doğrudan çalıştırma
# ─────────────────────────────────────────────

if __name__ == "__main__":
    users_df, books_df = get_test_data()

    print("=" * 65)
    print("  BEBOOK – KİŞİSELLEŞTİRİLMİŞ ÖNERİ SİSTEMİ  ")
    print("=" * 65)

    # ── Senaryo 1: Giriş yapılmamış kullanıcı ────────────────────────────
    print("\n🔒 Senaryo 1 – Giriş yapılmamış kullanıcı (user_id=None)")
    try:
        get_recommendations(None, users_df, books_df)
    except PermissionError as e:
        print(f"   ✅ Beklenen hata yakalandı → {e}")

    # ── Senaryo 2: Psikoloji bölümü (user_id=2, Nilay) ───────────────────
    print("\n" + "─" * 65)
    print("👤 Senaryo 2 – Nilay (Psikoloji, ZBEU) → user_id=2")
    print("─" * 65)
    recs = get_recommendations(2, users_df, books_df, top_n=5)
    for i, r in enumerate(recs, 1):
        print(f"  {i}. [{r['match_percentage']:5.1f}%] {r['title']:<45} {r['price']:.0f} TL")

    # ── Senaryo 3: Bilgisayar Mühendisliği (user_id=6, nil) ──────────────
    print("\n" + "─" * 65)
    print("👤 Senaryo 3 – nil (Bilgisayar Mühendisliği, ZBEU) → user_id=6")
    print("─" * 65)
    recs = get_recommendations(6, users_df, books_df, top_n=5)
    for i, r in enumerate(recs, 1):
        print(f"  {i}. [{r['match_percentage']:5.1f}%] {r['title']:<45} {r['price']:.0f} TL")

    # ── Senaryo 4: İşletme bölümü (user_id=3) ────────────────────────────
    print("\n" + "─" * 65)
    print("👤 Senaryo 4 – sateylul2 (İşletme, İTÜ) → user_id=3")
    print("─" * 65)
    recs = get_recommendations(3, users_df, books_df, top_n=5)
    for i, r in enumerate(recs, 1):
        print(f"  {i}. [{r['match_percentage']:5.1f}%] {r['title']:<45} {r['price']:.0f} TL")

    # ── Senaryo 5: Tıp bölümü – eşleşme az olmalı (user_id=7) ───────────
    print("\n" + "─" * 65)
    print("👤 Senaryo 5 – a@gmail.com (Tıp, ZBEU) → user_id=7")
    print("─" * 65)
    recs = get_recommendations(7, users_df, books_df, top_n=5)
    for i, r in enumerate(recs, 1):
        print(f"  {i}. [{r['match_percentage']:5.1f}%] {r['title']:<45} {r['price']:.0f} TL")

    print("\n" + "=" * 65)
    print("  ✅ Tüm senaryolar tamamlandı.")
    print("=" * 65)
