import psycopg2
import pandas as pd
import traceback

conn = psycopg2.connect(host='localhost', database='bebook', user='postgres', password='12345', port='5432')
cur = conn.cursor()

user_id = 18

# Kullanıcıları çek
cur.execute("SELECT user_id, email, university, department FROM users")
users_data = cur.fetchall()
users_df = pd.DataFrame(users_data, columns=["user_id", "email", "university", "department"])
print(f"Kullanici sayisi: {len(users_df)}")

user_row = users_df[users_df["user_id"] == user_id]
print(f"User {user_id}: {user_row.to_dict('records')}")

# Kitapları çek
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
print(f"Kitap sayisi: {len(books_df)}")
if not books_df.empty:
    print("Ilk kitap:", books_df.iloc[0].to_dict())

# department ekle
books_with_dept = []
for _, book in books_df.iterrows():
    seller = users_df[users_df["email"] == book["seller_email"]]
    dept = seller.iloc[0]["department"] if not seller.empty else "Diger"
    books_with_dept.append({
        "book_id": book["book_id"],
        "title": book["title"],
        "author": book["author"],
        "category": book["category"],
        "price": book["price"],
        "description": book["description"],
        "seller_email": book["seller_email"],
        "image_path": book["image_path"],
        "publisher": book["publisher"],
        "department": dept,
        "is_sold": False
    })

books_df2 = pd.DataFrame(books_with_dept)
print(f"Department eklenince kitap sayisi: {len(books_df2)}")

# Öneri motoru
try:
    from recommendation_engine import get_recommendations
    recs = get_recommendations(user_id, users_df, books_df2, top_n=6)
    print(f"Oneri sayisi: {len(recs)}")
    for r in recs:
        print(f"  - {r['title']} [{r['match_percentage']}%]")
except Exception as e:
    print(f"HATA: {e}")
    traceback.print_exc()

conn.close()
