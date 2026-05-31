import psycopg2
import pandas as pd
import traceback

BASE_URL = "http://192.168.0.14:8002"
user_id = 18
top_n = 6

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
try:
    cur = conn.cursor()
    
    # Kullanıcıları çek
    cur.execute("SELECT user_id, email, university, department FROM users")
    users_data = cur.fetchall()
    users_df = pd.DataFrame(users_data, columns=["user_id", "email", "university", "department"])
    print(f"1. Kullanici sayisi: {len(users_df)}")
    
    # Kitapları çek - DÜZELTILMIS SORGU
    cur.execute("""
        SELECT id as book_id, title, author, category, price, description, 
               seller_email, image_path, publisher
        FROM books
        WHERE is_sold = FALSE OR is_sold IS NULL
    """)
    books_data = cur.fetchall()
    books_df = pd.DataFrame(books_data, columns=[
        "book_id", "title", "author", "category", "price", 
        "description", "seller_email", "image_path", "publisher"
    ])
    print(f"2. Kitap sayisi: {len(books_df)}")
    
    # Kullanıcı var mı?
    user_row = users_df[users_df["user_id"] == user_id]
    print(f"3. User {user_id} bulundu mu: {not user_row.empty}")
    if user_row.empty:
        print("   HATA: Kullanici bulunamadi!")
    else:
        print(f"   User: {user_row.iloc[0].to_dict()}")
    
    # Department ekle
    books_with_dept = []
    for _, book in books_df.iterrows():
        seller = users_df[users_df["email"] == book["seller_email"]]
        dept = seller.iloc[0]["department"] if not seller.empty else "Diger"
        image_path = book["image_path"]
        if image_path:
            if str(image_path).startswith('http'):
                image_url = image_path
            elif str(image_path).startswith('/uploads/'):
                image_url = f"{BASE_URL}{image_path}"
            else:
                image_url = f"{BASE_URL}/uploads/{image_path}"
        else:
            image_url = None
        books_with_dept.append({
            "book_id": book["book_id"],
            "title": book["title"],
            "author": book["author"],
            "category": book["category"],
            "price": book["price"],
            "description": book["description"],
            "seller_email": book["seller_email"],
            "image_path": image_url,
            "publisher": book["publisher"],
            "department": dept,
            "is_sold": False
        })
    
    books_df2 = pd.DataFrame(books_with_dept)
    print(f"4. Department eklenince kitap sayisi: {len(books_df2)}")
    
    # Öneri motoru
    from recommendation_engine import get_recommendations
    recommendations = get_recommendations(user_id, users_df, books_df2, top_n=top_n)
    print(f"5. Oneri sayisi: {len(recommendations)}")
    for r in recommendations:
        print(f"   - {r['title']} [{r['match_percentage']}%]")

except Exception as e:
    print(f"HATA: {e}")
    traceback.print_exc()
finally:
    conn.close()
