# -*- coding: utf-8 -*-
# BeBook Backend API v2
from fastapi import FastAPI, HTTPException, Request, UploadFile, File, Form
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, EmailStr
import psycopg2
import bcrypt
from fastapi.middleware.cors import CORSMiddleware
import json
import iyzipay
import os
import shutil
import uuid
from typing import List, Optional
import smtplib
import random
import string
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime

# ============================================
# SMTP AYARLARI — Buradan kolayca değiştirin
# ============================================
SMTP_SERVER   = "smtp.gmail.com"
SMTP_PORT     = 587
SENDER_EMAIL  = "nilaygunenc@gmail.com"       # Gönderici e-posta
SENDER_PASSWORD = "nqqunbslbjkkdbom"          # Google App Password (16 hane, boşluksuz)
# ============================================

otp_storage = {}

# ============================================
# 1. APP OLUSTURMA
# ============================================
app = FastAPI()

# --- AYARLAR VE KLASORLER ---
UPLOAD_DIR = "uploads" 
if not os.path.exists(UPLOAD_DIR):
    os.makedirs(UPLOAD_DIR)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")
BASE_URL = "http://192.168.0.14:8002"

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- VERITABANI BAGLANTISI ---
def get_db_connection():
    return psycopg2.connect(
        host="localhost",
        database="bebook",
        user="postgres",
        password="12345",
        port="5432"
    )

# --- IYZICO AYARLARI ---
IYZICO_OPTIONS = {
    'api_key': 'sandbox-2uvQ8EgewWnsUzYohEY9bAe9iHqZwQkB',
    'secret_key': 'sandbox-uA0wxzWZMBF4m7RKBqEf9rNtAYBWEzkr',
    'base_url': 'sandbox-api.iyzipay.com'
}

# --- VERI MODELLERI ---
class UserSignup(BaseModel):
    full_name: Optional[str] = None
    email: str
    password: str
    university: str
    department: str
    profile_image_path: Optional[str] = None

class UserLogin(BaseModel):
    email: str
    password: str

class BookCreate(BaseModel):
    title: str
    author: str
    category: str
    price: float
    description: str
    seller_email: str
    publisher: Optional[str] = ""
    image_path: Optional[str] = ""

class UpdateBook(BaseModel):
    book_id: int
    user_id: int
    title: str
    price: float
    description: str

class ContactRequest(BaseModel):
    full_name: str
    email: str
    message: str

class FavoriteToggle(BaseModel):
    user_id: int
    book_id: int

class CreatePayment(BaseModel):
    user_id: int
    book_id: int
    price: float

class BulkPaymentRequest(BaseModel):
    user_id: int
    book_ids: List[int]
    total_price: float

class CreatePayment(BaseModel):
    user_id: int
    book_id: int
    price: float

class BulkPaymentRequest(BaseModel):
    user_id: int
    book_ids: List[int]
    total_price: float

# ============================================
# 7. ENDPOINTS
# ============================================

# --- KULLANICI KAYIT ---
@app.post("/signup")
async def signup(user: UserSignup):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        hashed_password = bcrypt.hashpw(
            user.password.encode('utf-8')[:72],
            bcrypt.gensalt()
        ).decode('utf-8')

        # Önce tabloyu kontrol edelim
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
        columns = [row[0] for row in cur.fetchall()]
        print(f"Users tablosundaki sütunlar: {columns}")

        # full_name sütunu varsa onu kullan, yoksa sadece email, password vs. kullan
        if 'full_name' in columns:
            cur.execute(
                "INSERT INTO public.users (full_name, email, password_hash, university, department) VALUES (%s, %s, %s, %s, %s)",
                (user.full_name or "", user.email, hashed_password, user.university, user.department)
            )
        else:
            # full_name sütunu yoksa sadece temel bilgileri kaydet
            cur.execute(
                "INSERT INTO public.users (email, password_hash, university, department) VALUES (%s, %s, %s, %s)",
                (user.email, hashed_password, user.university, user.department)
            )
        
        conn.commit()
        return {"status": "success", "message": "Kullanici basariyla kaydedildi!"}
    except Exception as e:
        if conn: conn.rollback()
        print(f"Kayıt hatası: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

# --- KULLANICI GIRISI ---
@app.post("/login")
async def login(user: UserLogin):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Önce tabloyu kontrol edelim
        cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
        columns = [row[0] for row in cur.fetchall()]
        print(f"Users tablosundaki sütunlar: {columns}")
        
        # Temel sütunları seç
        select_columns = ["user_id", "password_hash"]
        if 'university' in columns:
            select_columns.append("university")
        if 'department' in columns:
            select_columns.append("department")
        if 'profile_image_path' in columns:
            select_columns.append("profile_image_path")
        if 'full_name' in columns:
            select_columns.append("full_name")
        
        query = f"SELECT {', '.join(select_columns)} FROM public.users WHERE email = %s"
        cur.execute(query, (user.email,))
        result = cur.fetchone()

        if not result:
            raise HTTPException(status_code=401, detail="E-posta veya sifre hatali.")

        # Sonuçları parse et
        user_id = result[0]
        stored_hash = result[1]
        
        if bcrypt.checkpw(user.password.encode('utf-8')[:72], stored_hash.encode('utf-8')):
            response_data = {
                "status": "success",
                "user_id": user_id,
                "user_email": user.email
            }
            
            # Varsa diğer bilgileri ekle
            idx = 2
            if 'university' in columns:
                response_data["university"] = result[idx] if len(result) > idx else None
                idx += 1
            if 'department' in columns:
                response_data["department"] = result[idx] if len(result) > idx else None
                idx += 1
            if 'profile_image_path' in columns:
                raw_path = result[idx] if len(result) > idx else None
                # Ters slash'ı düzelt
                if raw_path:
                    raw_path = raw_path.replace('\\', '/')
                response_data["profile_image_path"] = raw_path
                print(f"LOGIN - profile_image_path: {raw_path}")
                idx += 1
            if 'full_name' in columns:
                response_data["full_name"] = result[idx] if len(result) > idx else None
                
            print(f"LOGIN response: {response_data}")
            return response_data
        else:
            raise HTTPException(status_code=401, detail="E-posta veya sifre hatali.")
    except Exception as e:
        print(f"Giriş hatası: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()

# --- TUM KITAPLARI GETIR (Ana Sayfa) ---
@app.get("/books")
async def get_all_books():
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        query = """
            SELECT 
                b.id as book_id, u.user_id, b.title, b.author, b.category, b.price, 
                b.description, b.image_path, b.seller_email, b.publisher,
                u.email, u.university, u.department, b.is_sold
            FROM public.books b
            LEFT JOIN public.users u ON LOWER(TRIM(b.seller_email)) = LOWER(TRIM(u.email))
            WHERE b.is_sold = FALSE OR b.is_sold IS NULL
        """
        cur.execute(query)
        books = cur.fetchall()
        
        result = []
        for b in books:
            image_path = b[7]
            if image_path:
                if image_path.startswith('http'):
                    image_url = image_path
                elif image_path.startswith('/uploads/'):
                    image_url = f"{BASE_URL}{image_path}"
                else:
                    image_url = f"{BASE_URL}/uploads/{image_path}"
            else:
                image_url = None
                
            result.append({
                "book_id": b[0],
                "user_id": b[1],
                "title": b[2],
                "author": b[3],
                "category": b[4],
                "price": float(b[5]),
                "description": b[6],
                "image_path": image_url,
                "seller_email": b[8],
                "publisher": b[9],
                "email": b[10],
                "university": b[11],
                "department": b[12],
                "is_sold": b[13] if len(b) > 13 else False
            })
        return result
    finally:
        conn.close()

# --- YENI KITAP EKLEME ---
@app.post("/books")
async def add_book(
    title: str = Form(...),
    author: str = Form(...),
    category: str = Form(...),
    price: float = Form(...),
    description: str = Form(""),
    seller_email: str = Form(...),
    publisher: str = Form(""),
    file: UploadFile = File(None)
):
    conn = None
    image_name = None
    try:
        if file:
            ext = file.filename.split('.')[-1]
            image_name = f"{uuid.uuid4()}.{ext}"
            file_path = os.path.join(UPLOAD_DIR, image_name)
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """INSERT INTO public.books 
            (title, author, category, price, description, seller_email, publisher, image_path) 
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
            (title, author, category, price, description, seller_email, publisher, image_name)
        )
        conn.commit()
        return {"status": "success", "message": "Kitap ve resim yuklendi!"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn: conn.close()

# --- KULLANICININ KITAPLARINI GETIR ---
@app.get("/my-books/{user_id}")
async def get_my_books(user_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT email FROM users WHERE user_id = %s", (user_id,))
        user_result = cur.fetchone()
        
        if not user_result:
            return []
        
        user_email = user_result[0]
        
        cur.execute("""
            SELECT id, title, author, category, publisher, price, description, image_path
            FROM books
            WHERE seller_email = %s AND (is_sold = FALSE OR is_sold IS NULL)
        """, (user_email,))
        books = cur.fetchall()

        result = []
        for b in books:
            image_path = b[7]
            if image_path:
                if image_path.startswith('http'):
                    image_url = image_path
                elif image_path.startswith('/uploads/'):
                    image_url = f"{BASE_URL}{image_path}"
                else:
                    image_url = f"{BASE_URL}/uploads/{image_path}"
            else:
                image_url = None
                
            result.append({
                "book_id": b[0],
                "user_id": user_id,
                "title": b[1],
                "author": b[2],
                "category": b[3],
                "publisher": b[4],
                "price": float(b[5]),
                "description": b[6],
                "image_path": image_url
            })
        return result
    finally:
        conn.close()

# --- KITAP GUNCELLEME ---
@app.put("/update-book")
async def update_book(book: UpdateBook):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT email FROM users WHERE user_id = %s", (book.user_id,))
        user_result = cur.fetchone()
        
        if not user_result:
            raise HTTPException(status_code=404, detail="Kullanici bulunamadi")
        
        user_email = user_result[0]
        
        cur.execute(
            "UPDATE books SET title = %s, price = %s, description = %s WHERE id = %s AND seller_email = %s", 
            (book.title, book.price, book.description, book.book_id, user_email)
        )
        conn.commit()
        return {"status": "success"}
    finally:
        conn.close()

# --- KITAP SILME ---
@app.delete("/delete-book/{book_id}/{user_id}")
async def delete_book(book_id: int, user_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT email FROM users WHERE user_id = %s", (user_id,))
        user_result = cur.fetchone()
        
        if not user_result:
            raise HTTPException(status_code=404, detail="Kullanici bulunamadi")
        
        user_email = user_result[0]
        
        cur.execute("DELETE FROM books WHERE id = %s AND seller_email = %s", (book_id, user_email))
        conn.commit()
        return {"status": "success"}
    finally:
        conn.close()

# --- MESAJLASMA ENDPOINTLERI ---

# Mesaj gonderme icin gerekli veri modeli
class MessageCreate(BaseModel):
    sender_id: int
    receiver_id: int
    book_id: int
    message_text: str

@app.get("/chats/{my_id}")
async def get_chat_list(my_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        # Önce users tablosundaki sütunları kontrol edelim
        cursor.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'")
        columns = [row[0] for row in cursor.fetchall()]
        print(f"Users tablosundaki sütunlar: {columns}")
        
        # full_name sütunu varsa onu kullan, yoksa email kullan
        full_name_column = "u.full_name" if 'full_name' in columns else "u.email"
        profile_image_column = "u.profile_image_path" if 'profile_image_path' in columns else "NULL"
        
        query = f"""
        SELECT DISTINCT ON (m.book_id, LEAST(m.sender_id, m.receiver_id), GREATEST(m.sender_id, m.receiver_id))
            m.sender_id, 
            m.receiver_id, 
            m.message_text, 
            m.book_id, 
            m.created_at,
            u.email, 
            b.title,
            {profile_image_column} as profile_image_path,
            {full_name_column} as other_user_name,
            (SELECT COUNT(*) FROM usermessages 
             WHERE receiver_id = %s 
             AND sender_id = (CASE WHEN m.sender_id = %s THEN m.receiver_id ELSE m.sender_id END) 
             AND book_id = m.book_id 
             AND is_read = FALSE) as unread_count
        FROM usermessages m
        LEFT JOIN users u ON u.user_id = (CASE WHEN m.sender_id = %s THEN m.receiver_id ELSE m.sender_id END)
        LEFT JOIN books b ON m.book_id = b.id
        WHERE m.sender_id = %s OR m.receiver_id = %s
        ORDER BY m.book_id, LEAST(m.sender_id, m.receiver_id), GREATEST(m.sender_id, m.receiver_id), m.created_at DESC
        """
        
        cursor.execute(query, (my_id, my_id, my_id, my_id, my_id))
        rows = cursor.fetchall()
        
        from datetime import datetime
        rows = sorted(rows, key=lambda x: x[4] if x[4] else datetime.min, reverse=True)
        
        chats = []
        for row in rows:
            other_id = row[1] if row[0] == my_id else row[0]
            chats.append({
                "receiver_id": other_id,
                "receiver_name": row[8] if row[8] else row[5],  # other_user_name veya email
                "full_name": row[8] if row[8] else row[5],
                "book_title": row[6] if row[6] else f"Kitap #{row[3]}",
                "book_id": row[3],
                "last_message": row[2],
                "profile_image": row[7],
                "unread_count": row[9]
            })
        return chats

    except Exception as e:
        print(f"Sohbet Listesi Hatasi: {e}")
        return []
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

@app.get("/messages/{sender_id}/{receiver_id}/{book_id}")
async def get_messages_with_book(sender_id: int, receiver_id: int, book_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
            SELECT id, sender_id, receiver_id, message_text, created_at, is_read, is_delivered 
            FROM usermessages 
            WHERE ((sender_id = %s AND receiver_id = %s) OR (sender_id = %s AND receiver_id = %s))
            AND book_id = %s
            ORDER BY created_at ASC
        """
        cursor.execute(query, (sender_id, receiver_id, receiver_id, sender_id, book_id))
        messages = cursor.fetchall()
        
        result = []
        for m in messages:
            result.append({
                "id": m[0],
                "sender_id": m[1],
                "receiver_id": m[2],
                "message_text": m[3],
                "created_at": m[4].isoformat() if m[4] else None,
                "is_read": m[5],
                "is_delivered": m[6],
                "book_id": book_id
            })
        return result
    except Exception as e:
        print(f"Hata: {e}")
        return []
    finally:
        cursor.close()
        conn.close()

@app.post("/messages/send")
async def send_message_fixed(data: dict):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        sender_id = data.get("sender_id")
        receiver_id = data.get("receiver_id")
        book_id = data.get("book_id")
        message_text = data.get("message_text")

        query = """
            INSERT INTO usermessages (sender_id, receiver_id, book_id, message_text, is_read, is_delivered) 
            VALUES (%s, %s, %s, %s, FALSE, FALSE)
            RETURNING id, created_at
        """
        cursor.execute(query, (sender_id, receiver_id, book_id, message_text))
        row = cursor.fetchone()
        conn.commit()
        return {
            "status": "success",
            "id": row[0],
            "created_at": row[1].isoformat() if row[1] else None
        }
    except Exception as e:
        print(f"Mesaj Kayit Hatasi: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        cursor.close()
        conn.close()

@app.post("/mark_messages_as_read")
async def mark_messages_as_read(receiver_id: int, sender_id: int, book_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
        UPDATE usermessages 
        SET is_read = TRUE 
        WHERE receiver_id = %s AND sender_id = %s AND book_id = %s AND is_read = FALSE
        """
        cursor.execute(query, (receiver_id, sender_id, book_id))
        conn.commit()
        return {"status": "success", "message": "Mesajlar okundu olarak isaretlendi"}
    except Exception as e:
        print(f"Okundu isaretleme hatasi: {e}")
        return {"status": "error"}
    finally:
        cursor.close()
        conn.close()

@app.put("/mark_as_delivered/{receiver_id}")
async def mark_as_delivered(receiver_id: int):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        query = """
            UPDATE usermessages 
            SET is_delivered = TRUE 
            WHERE receiver_id = %s AND is_delivered = FALSE
        """
        cursor.execute(query, (receiver_id,))
        conn.commit()
        
        print(f"Bilgi: {receiver_id} ID'li kullanici icin mesajlar iletildi olarak isaretlendi.")
        return {"status": "success", "message": "Mesajlar iletildi yapildi"}
    except Exception as e:
        print(f"Hata olustu: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        cursor.close()
        conn.close()

@app.delete("/chats/delete")
async def delete_chat(my_id: int, other_id: int, book_id: int):
    conn = get_db_connection()
    cursor = None
    try:
        cursor = conn.cursor()
        query = """
        DELETE FROM usermessages 
        WHERE book_id = %s 
        AND (
            (sender_id = %s AND receiver_id = %s) OR 
            (sender_id = %s AND receiver_id = %s)
        )
        """
        cursor.execute(query, (book_id, my_id, other_id, other_id, my_id))
        conn.commit()
        return {"message": "Sohbet basariyla silindi"}
    except Exception as e:
        print(f"Silme hatasi: {e}")
        raise HTTPException(status_code=500, detail="Sohbet silinemedi")
    finally:
        if cursor: cursor.close()
        if conn: conn.close()

# --- FAVORILER SISTEMI ---
@app.post("/favorites/toggle")
async def toggle_favorite(favorite: FavoriteToggle):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        cur.execute(
            "SELECT id FROM public.favorites WHERE user_id = %s AND book_id = %s",
            (favorite.user_id, favorite.book_id)
        )
        existing = cur.fetchone()
        
        if existing:
            cur.execute(
                "DELETE FROM public.favorites WHERE user_id = %s AND book_id = %s",
                (favorite.user_id, favorite.book_id)
            )
            conn.commit()
            return {"status": "removed", "message": "Favorilerden cikarildi"}
        else:
            cur.execute(
                "INSERT INTO public.favorites (user_id, book_id) VALUES (%s, %s)",
                (favorite.user_id, favorite.book_id)
            )
            conn.commit()
            return {"status": "added", "message": "Favorilere eklendi"}
    except Exception as e:
        if conn: conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        conn.close()

@app.get("/favorites/{user_id}")
async def get_favorites(user_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        query = """
            SELECT 
                b.id as book_id, b.title, b.author, b.category, b.price, b.description, 
                b.seller_email, b.image_path, b.publisher,
                u.user_id, u.email, u.university, u.department,
                f.created_at as favorited_at
            FROM public.favorites f
            JOIN public.books b ON f.book_id = b.id
            LEFT JOIN public.users u ON b.seller_email = u.email
            WHERE f.user_id = %s
            ORDER BY f.created_at DESC
        """
        cur.execute(query, (user_id,))
        favorites = cur.fetchall()
        
        result = []
        for f in favorites:
            image_url = f"{BASE_URL}/uploads/{f[7]}" if f[7] else None
            result.append({
                "book_id": f[0],
                "title": f[1],
                "author": f[2],
                "category": f[3],
                "price": float(f[4]),
                "description": f[5],
                "seller_email": f[6],
                "image_path": image_url,
                "publisher": f[8],
                "user_id": f[9],
                "email": f[10],
                "university": f[11],
                "department": f[12],
                "favorited_at": str(f[13])
            })
        return result
    finally:
        cur.close()
        conn.close()

@app.get("/favorites/check/{user_id}/{book_id}")
async def check_favorite(user_id: int, book_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(
            "SELECT id FROM public.favorites WHERE user_id = %s AND book_id = %s",
            (user_id, book_id)
        )
        exists = cur.fetchone() is not None
        return {"is_favorite": exists}
    finally:
        conn.close()

# --- ILETISIM FORMU ---
@app.post("/contact")
async def contact(req: ContactRequest):
    try:
        # bebook.support@gmail.com adresine mail gönder
        success = send_contact_email(req.full_name, req.email, req.message)
        if success:
            return {"status": "success", "message": "Mesajiniz iletildi."}
        else:
            return {"status": "error", "message": "Mail gonderilemedi, lutfen tekrar deneyin."}
    except Exception as e:
        print(f"Iletisim formu hatasi: {e}")
        return {"status": "error", "message": str(e)}

# --- ONERI SISTEMI ---
@app.get("/recommendations/{user_id}")
async def get_recommendations_endpoint(user_id: int, top_n: int = 6):
    """
    Kullanicinin bolumune gore kisisellestirilmis kitap onerileri dondurur.
    """
    import pandas as pd
    from recommendation_engine import get_recommendations
    
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Kullanicilari cek
        cur.execute("SELECT user_id, email, university, department FROM users")
        users_data = cur.fetchall()
        users_df = pd.DataFrame(users_data, columns=["user_id", "email", "university", "department"])
        
        # Kitaplari cek
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
        
        # Kullanicinin department bilgisini al
        user_row = users_df[users_df["user_id"] == user_id]
        if user_row.empty:
            return {"error": "Kullanici bulunamadi"}
        
        # Her kitaba department ekle (seller'in department'i)
        books_with_dept = []
        for _, book in books_df.iterrows():
            seller = users_df[users_df["email"] == book["seller_email"]]
            dept = seller.iloc[0]["department"] if not seller.empty else "Diger"
            
            # Resim yolunu tam URL'e cevir
            image_path = book["image_path"]
            if image_path and isinstance(image_path, str) and image_path.strip():
                if image_path.startswith('http'):
                    image_url = image_path
                elif image_path.startswith('/uploads/'):
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
        
        books_df = pd.DataFrame(books_with_dept)
        
        # Onerileri al
        recommendations = get_recommendations(user_id, users_df, books_df, top_n=top_n)
        print(f"Oneri sayisi: {len(recommendations)}")
        
        # NaN/Inf değerlerini temizle (JSON uyumluluğu için)
        import math
        clean = []
        for item in recommendations:
            clean_item = {}
            for k, v in item.items():
                if isinstance(v, float) and (math.isnan(v) or math.isinf(v)):
                    clean_item[k] = 0.0
                else:
                    clean_item[k] = v
            clean.append(clean_item)
        return clean
        
    except Exception as e:
        print(f"Oneri sistemi hatasi: {e}")
        import traceback
        traceback.print_exc()
        return []
    finally:
        conn.close()

# --- ODEME SISTEMI ---

# TEK KITAP ICIN ODEME BASLATMA
@app.post("/create-payment")
async def create_payment(payment: CreatePayment):
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute(
            "INSERT INTO orders (user_id, book_id, price, status) VALUES (%s, %s, %s, %s) RETURNING order_id",
            (payment.user_id, payment.book_id, payment.price, "PENDING")
        )
        order_id = cur.fetchone()[0]
        conn.commit()

        address_info = {
            'contactName': 'Merve Bebook',
            'city': 'Zonguldak',
            'country': 'Turkey',
            'address': 'Universite Caddesi No:100 Incivez',
            'zipCode': '67100'
        }

        request_data = {
            'locale': 'tr',
            'conversationId': str(order_id),
            'price': str(payment.price),
            'paidPrice': str(payment.price),
            'currency': 'TRY',
            'basketId': str(order_id),
            'paymentGroup': 'PRODUCT',
            'callbackUrl': f'{BASE_URL}/payment-callback',
            'buyer': {
                'id': str(payment.user_id), 'name': 'Merve', 'surname': 'Bebook',
                'gsmNumber': '+905350000000', 'email': 'test@email.com', 'identityNumber': '11111111110',
                'city': 'Zonguldak', 'country': 'Turkey', 'zipCode': '67100', 'registrationAddress': 'ZBEU'
            },
            'shippingAddress': address_info,
            'billingAddress': address_info,
            'basketItems': [
                {
                    'id': str(payment.book_id), 
                    'name': 'Kitap', 
                    'category1': 'Egitim', 
                    'itemType': 'PHYSICAL', 
                    'price': str(payment.price)
                }
            ]
        }
        checkout_form_initialize = iyzipay.CheckoutFormInitialize().create(request_data, IYZICO_OPTIONS)
        iyzico_response = json.loads(checkout_form_initialize.read().decode('utf-8'))
        iyzico_response['orderId'] = order_id  # Flutter için order_id ekle
        return iyzico_response
    except Exception as e:
        print(f"Odeme hatasi: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        cur.close()
        conn.close()

# TOPLU ODEME (Sepet)
@app.post("/bulk-payment")
async def bulk_payment(request: BulkPaymentRequest):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Her kitap için ayrı order satırı ekle, ilk kitabın order_id'sini conversationId olarak kullan
        first_order_id = None
        per_book_price = request.total_price / len(request.book_ids) if request.book_ids else request.total_price

        for b_id in request.book_ids:
            cur.execute(
                "INSERT INTO orders (user_id, book_id, price, status) VALUES (%s, %s, %s, %s) RETURNING order_id",
                (request.user_id, b_id, per_book_price, "PENDING")
            )
            oid = cur.fetchone()[0]
            if first_order_id is None:
                first_order_id = oid

        conn.commit()
        order_id = first_order_id

        # Sepetteki tum kitaplari basket_items'a ekliyoruz
        basket_items = []
        for b_id in request.book_ids:
            item = {
                'id': str(b_id),
                'name': f'Kitap ID: {b_id}',
                'category1': 'Egitim',
                'itemType': 'PHYSICAL',
                'price': str(per_book_price)
            }
            basket_items.append(item)

        iyzico_request = {
            'locale': 'tr',
            'conversationId': str(order_id),
            'price': str(request.total_price),
            'paidPrice': str(request.total_price),
            'currency': 'TRY',
            'basketId': str(order_id),
            'paymentGroup': 'PRODUCT',
            'callbackUrl': f'{BASE_URL}/payment-callback',
            'buyer': {
                'id': str(request.user_id),
                'name': 'Merve',
                'surname': 'Bebook',
                'gsmNumber': '+905350000000',
                'email': 'test@email.com',
                'identityNumber': '11111111110',
                'city': 'Zonguldak',
                'country': 'Turkey',
                'zipCode': '67100',
                'registrationAddress': 'ZBEU Kampusu'
            },
            'shippingAddress': {
                'contactName': 'Merve Bebook', 
                'city': 'Zonguldak', 
                'country': 'Turkey', 
                'address': 'Incivez Mah.', 
                'zipCode': '67100'
            },
            'billingAddress': {
                'contactName': 'Merve Bebook', 
                'city': 'Zonguldak', 
                'country': 'Turkey', 
                'address': 'Incivez Mah.', 
                'zipCode': '67100'
            },
            'basketItems': basket_items
        }

        checkout_form_initialize = iyzipay.CheckoutFormInitialize().create(iyzico_request, IYZICO_OPTIONS)
        iyzico_response = json.loads(checkout_form_initialize.read().decode('utf-8'))
        iyzico_response['orderId'] = order_id  # Flutter için order_id ekle
        return iyzico_response

    except Exception as e:
        print(f"Iyzipay Hatasi: {e}")
        return {"status": "failure", "errorMessage": str(e)}
    finally:
        conn.close()

# ODEME CALLBACK
@app.post("/payment-callback")
async def payment_callback(request: Request):
    form_data = await request.form()
    token = form_data.get('token')

    if not token:
        return HTMLResponse(content="Token yok", status_code=400)

    # Iyzipay'e token ile sonucu sorguluyoruz
    iyzico_request = {'token': token}
    checkout_form_result = iyzipay.CheckoutForm().retrieve(iyzico_request, IYZICO_OPTIONS)
    
    result = json.loads(checkout_form_result.read().decode('utf-8'))
    
    print("--- IYZICO SORGULAMA SONUCU ---")
    print(json.dumps(result, indent=2))

    payment_status = result.get('paymentStatus')
    order_id = result.get('conversationId')

    if payment_status == 'SUCCESS':
        try:
            conn = get_db_connection()
            cur = conn.cursor()
            cur.execute("UPDATE orders SET status = 'SUCCESS' WHERE order_id = %s", (order_id,))
            
            # Satın alınan kitabı is_sold = true yap
            cur.execute("SELECT book_id FROM orders WHERE order_id = %s", (order_id,))
            order_row = cur.fetchone()
            if order_row and order_row[0]:
                cur.execute("UPDATE books SET is_sold = TRUE WHERE id = %s", (order_row[0],))
            
            conn.commit()
            cur.close()
            conn.close()
        except Exception as e:
            print(f"DB Guncelleme Hatasi: {e}")

        status_text = "Ödeme Başarılı!"
        main_color = "#10B981"
        bg_gradient = "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
        icon = "✓"
        sub_text = "Siparişiniz başarıyla tamamlandı. Kitaplarınız en kısa sürede size ulaşacak."
        btn_text = "Ana Sayfaya Dön"
    else:
        status_text = "Ödeme Başarısız"
        main_color = "#EF4444"
        bg_gradient = "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)"
        icon = "✗"
        error_msg = result.get('errorMessage', 'Ödeme onaylanmadı.')
        sub_text = f"İşlem tamamlanamadı: {error_msg}"
        btn_text = "Tekrar Dene"

    html_content = f"""
    <!DOCTYPE html>
    <html lang="tr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <title>Ödeme Sonucu - BeBook</title>
        <style>
            * {{ margin: 0; padding: 0; box-sizing: border-box; }}
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: {bg_gradient};
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                padding: 20px;
            }}
            .card {{
                background: rgba(255,255,255,0.97);
                border-radius: 32px;
                padding: 48px 36px;
                max-width: 380px;
                width: 100%;
                text-align: center;
                box-shadow: 0 25px 60px rgba(0,0,0,0.2);
            }}
            .icon-circle {{
                width: 96px;
                height: 96px;
                border-radius: 50%;
                background: {main_color};
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0 auto 28px;
                font-size: 44px;
                color: white;
                box-shadow: 0 12px 30px {main_color}55;
            }}
            .brand {{
                font-size: 13px;
                font-weight: 700;
                letter-spacing: 3px;
                color: #9CA3AF;
                text-transform: uppercase;
                margin-bottom: 8px;
            }}
            h1 {{
                font-size: 26px;
                font-weight: 800;
                color: #1F2937;
                margin-bottom: 14px;
            }}
            p {{
                font-size: 15px;
                color: #6B7280;
                line-height: 1.6;
                margin-bottom: 36px;
            }}
            .divider {{
                height: 1px;
                background: #F3F4F6;
                margin: 0 -36px 28px;
            }}
            .btn {{
                display: block;
                text-decoration: none;
                background: {main_color};
                color: white;
                padding: 16px 24px;
                border-radius: 16px;
                font-weight: 700;
                font-size: 16px;
                box-shadow: 0 8px 20px {main_color}44;
            }}
            .footer {{
                margin-top: 20px;
                font-size: 12px;
                color: #D1D5DB;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon-circle">{icon}</div>
            <div class="brand">BeBook</div>
            <h1>{status_text}</h1>
            <p>{sub_text}</p>
            <div class="divider"></div>
            <a href="bebook://home" class="btn">{btn_text}</a>
            <div class="footer">BeBook &copy; 2025</div>
        </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)

# SIPARIS TAMAMLANDI (Flutter tarafından manuel tetikleme)
@app.post("/mark-order-complete/{order_id}")
async def mark_order_complete(order_id: int):
    """
    Flutter ödeme sayfasından döndüğünde:
    1. Siparişleri SUCCESS yapar
    2. Satılan kitapları veritabanından siler (ana sayfadan kalkar)
    3. Satıcıya sistem mesajı gönderir: "Kitabınız satıldı"
    """
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        
        # Bu order'ın user_id'sini bul (alıcı)
        cur.execute("SELECT user_id FROM orders WHERE order_id = %s", (order_id,))
        row = cur.fetchone()
        if not row:
            return {"status": "error", "message": "Order bulunamadı"}
        buyer_id = row[0]
        
        # Bu kullanıcının tüm PENDING siparişlerini SUCCESS yap, book_id'leri al
        cur.execute("""
            UPDATE orders SET status = 'SUCCESS' 
            WHERE user_id = %s AND status = 'PENDING'
            RETURNING book_id
        """, (buyer_id,))
        book_ids = [r[0] for r in cur.fetchall() if r[0]]
        
        for bid in book_ids:
            # Kitabın bilgilerini al (satıcı emaili ve başlığı)
            cur.execute("SELECT seller_email, title, author, image_path, category FROM books WHERE id = %s", (bid,))
            book_row = cur.fetchone()
            if not book_row:
                continue
            seller_email, book_title, book_author, book_image, book_category = book_row

            # Satıcının user_id'sini bul
            cur.execute("SELECT user_id FROM users WHERE email = %s", (seller_email,))
            seller_row = cur.fetchone()
            seller_id = seller_row[0] if seller_row else None

            # Kitap bilgilerini orders tablosuna kaydet (kitap silinse bile geçmiş kalır)
            cur.execute("""
                UPDATE orders 
                SET book_title = %s, book_author = %s, book_image = %s, 
                    book_category = %s, seller_email = %s, seller_id = %s
                WHERE book_id = %s AND user_id = %s AND status = 'SUCCESS'
            """, (book_title, book_author, book_image, book_category, seller_email, seller_id, bid, buyer_id))

            # Kitabı veritabanından sil (ana sayfadan kalkar, başkası alamaz)
            cur.execute("DELETE FROM books WHERE id = %s", (bid,))

            # Satıcıya sistem mesajı gönder
            if seller_id:
                system_message = (
                    f'🎉 Tebrikler! "{book_title}" adlı kitabınız satıldı. '
                    f'Ödeme iyzico güvencesiyle alındı. '
                    f'Lütfen kitabı alıcıya en kısa sürede gönderin.'
                )
                cur.execute("""
                    INSERT INTO usermessages 
                        (sender_id, receiver_id, book_id, message_text, is_read, is_delivered)
                    VALUES (%s, %s, %s, %s, FALSE, TRUE)
                """, (buyer_id, seller_id, bid, system_message))

        conn.commit()
        print(f"Order complete: buyer={buyer_id}, books={book_ids}")
        return {"status": "success", "books_marked": len(book_ids)}
    except Exception as e:
        if conn: conn.rollback()
        print(f"Mark order complete hatası: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()

# SIPARIS DURUMU SORGULAMA
@app.get("/order-status/{order_id}")
async def get_order_status(order_id: int):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT status FROM orders WHERE order_id = %s", (order_id,))
        result = cur.fetchone()
        if result:
            return {"status": result[0]}
        raise HTTPException(status_code=404, detail="Siparis bulunamadi")
    finally:
        conn.close()

# SATILAN KİTAPLAR
@app.get("/sold-books/{user_id}")
async def get_sold_books(user_id: int):
    """Kullanıcının satın aldığı kitapları döndürür (kitap silinse bile orders'dan gelir)"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute(""" 
            SELECT DISTINCT ON (o.book_id)
                o.book_id,
                COALESCE(o.book_title, b.title, 'Kitap') as title,
                COALESCE(o.book_author, b.author, '') as author,
                o.price as paid_price,
                COALESCE(o.book_image, b.image_path) as image_path,
                COALESCE(o.book_category, b.category, '') as category,
                COALESCE(o.seller_email, b.seller_email, '') as seller_email,
                o.created_at as order_date
            FROM orders o
            LEFT JOIN books b ON b.id = o.book_id
            WHERE o.user_id = %s AND o.status = 'SUCCESS'
            ORDER BY o.book_id, o.created_at DESC
        """, (user_id,))
        rows = cur.fetchall()
        rows = sorted(rows, key=lambda x: x[7] if x[7] else '', reverse=True)

        result = []
        for r in rows:
            image_path = r[4]
            if image_path:
                if image_path.startswith('http'):
                    image_url = image_path
                elif image_path.startswith('/uploads/'):
                    image_url = f"{BASE_URL}{image_path}"
                else:
                    image_url = f"{BASE_URL}/uploads/{image_path}"
            else:
                image_url = None

            result.append({
                "book_id": r[0],
                "title": r[1],
                "author": r[2],
                "paid_price": float(r[3]) if r[3] else 0,
                "price": float(r[3]) if r[3] else 0,
                "image_path": image_url,
                "category": r[5],
                "seller_email": r[6],
                "order_date": r[7].isoformat() if r[7] else None,
                "is_sold": True
            })
        return result
    except Exception as e:
        print(f"Satın alınan kitaplar hatası: {e}")
        return []
    finally:
        conn.close()

# --- SIFRE SIFIRLAMA SISTEMI ---

# Rastgele 6 haneli kod uretme
def generate_otp():
    return ''.join(random.choices(string.digits, k=6))

# E-posta gonderme fonksiyonu
def send_otp_email(receiver_email, otp_code):
    # Merkezi SMTP ayarlarını kullan (dosyanın başında tanımlı)
    subject = "BeBook - Dogrulama Kodunuz"
    body = f"""Merhaba,

BeBook hesabinizin sifresini sifirlamak icin asagidaki kodu kullanin:

Dogrulama Kodunuz: {otp_code}

Bu kod 2 dakika gecerlidir.
Eger bu istegi siz yapmadiyasaniz bu maili dikkate almayiniz.

BeBook Destek Ekibi
bebook.support@gmail.com"""

    try:
        from email.mime.text import MIMEText
        from email.mime.multipart import MIMEMultipart

        msg = MIMEMultipart()
        msg['From'] = SENDER_EMAIL
        msg['To'] = receiver_email
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'plain', 'utf-8'))

        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(SENDER_EMAIL, receiver_email, msg.as_string())
        server.quit()

        print(f"✅ MAIL GONDERILDI: {receiver_email} -> OTP: {otp_code}")
        return True

    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ SMTP AUTH HATASI: {e}")
        return False
    except Exception as e:
        print(f"❌ MAIL HATASI: {type(e).__name__}: {e}")
        return False

# SIFRE SIFIRLAMA ISTEGI
@app.post("/forgot-password")
async def forgot_password(data: dict):
    try:
        email = str(data.get("email", "")).strip().lower()  # küçük harfe çevir
        if not email:
            return {"status": "error", "message": "Email adresi eksik"}
            
        otp = generate_otp()
        
        # Kodu hafızaya kaydet (email küçük harfle)
        otp_storage[email] = {
            "code": otp,
            "created_at": datetime.now()
        }
        
        print(f"Email: {email}, OTP: {otp}") 
        
        success = send_otp_email(email, otp) 
        
        if success:
            return {"status": "success", "message": "Kod gonderildi"}
        else:
            return {"status": "error", "message": "Mail gonderimi basarisiz"}
            
    except Exception as e:
        print(f"Sistem Hatasi: {str(e)}")
        return {"status": "error", "message": str(e)}

# OTP DOGRULAMA
@app.post("/verify-otp")
async def verify_otp(data: dict):
    print("!!! DOGRULAMA ISTEGI GELDI !!!")
    print(f"Gelen Veri: {data}")
    
    email = str(data.get("email")).strip().lower()
    user_otp = str(data.get("otp")).strip()

    if email in otp_storage:
        stored = otp_storage[email]
        # Eski format (sadece string) ile uyumluluk
        if isinstance(stored, dict):
            code = str(stored["code"])
            created_at = stored["created_at"]
            # 2 dakika = 120 saniye
            elapsed = (datetime.now() - created_at).total_seconds()
            if elapsed > 120:
                del otp_storage[email]
                return {"status": "error", "message": "Kodun suresi doldu! Yeni kod isteyin."}
        else:
            code = str(stored)
        
        if code == user_otp:
            del otp_storage[email]  
            return {"status": "success", "message": "Kod dogrulandi"}
    
    print(f"Hata detayi -> Hafizadaki: {otp_storage.get(email)}, Girilen: {user_otp}")
    return {"status": "error", "message": "Kod eslesmedi veya suresi doldu!"}

# SIFRE SIFIRLAMA
@app.post("/reset-password")
async def reset_password(data: dict):
    conn = None
    try:
        email = str(data.get("email")).strip().lower()
        new_password = data.get("password")

        # Sifreyi Bcrypt ile sifreliyoruz
        hashed_password = bcrypt.hashpw(
            new_password.encode('utf-8'), 
            bcrypt.gensalt()
        ).decode('utf-8')

        conn = get_db_connection()
        cursor = conn.cursor()

        query = 'UPDATE users SET password_hash = %s WHERE email = %s'
        
        cursor.execute(query, (hashed_password, email))
        conn.commit()

        if cursor.rowcount == 0:
            return {"status": "error", "message": "Kullanici bulunamadi."}

        cursor.close()
        print(f"BASARILI: {email} sifresi sifrelenerek guncellendi.")
        return {"status": "success", "message": "Sifreniz basariyla guncellendi."}

    except Exception as e:
        print(f"Sifirlama Hatasi: {e}")
        return {"status": "error", "message": "Sistem hatasi olustu."}
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

# ILETISIM FORMU MAIL GONDERME
def send_contact_email(full_name: str, sender_email: str, message: str):
    """Kullanıcının iletişim formundan gönderdiği mesajı bebook.support@gmail.com'a iletir."""
    # Destek mesajları bu adrese gönderilir
    support_email = "bebook.support@gmail.com"

    subject = "Bebook Uygulama Ici Destek Talebi"
    body = f"""Yeni bir destek talebi alindi.

Gonderen Ad Soyad : {full_name}
Gonderen E-posta  : {sender_email}

Mesaj:
{message}

---
Bu mesaj BeBook uygulamasinin iletisim formundan gonderilmistir.
Cevaplamak icin: {sender_email}
"""

    try:
        from email.mime.text import MIMEText
        from email.mime.multipart import MIMEMultipart

        msg = MIMEMultipart()
        msg['From'] = SENDER_EMAIL          # Gönderici: nilaygunenc@gmail.com
        msg['To'] = support_email           # Alıcı: bebook.support@gmail.com
        msg['Reply-To'] = sender_email      # Cevap kullanıcıya gitsin
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'plain', 'utf-8'))

        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT)
        server.ehlo()
        server.starttls()
        server.ehlo()
        server.login(SENDER_EMAIL, SENDER_PASSWORD)
        server.sendmail(SENDER_EMAIL, support_email, msg.as_string())
        server.quit()

        print(f"✅ Destek maili gonderildi: {full_name} <{sender_email}> -> {support_email}")
        return True
    except smtplib.SMTPAuthenticationError as e:
        print(f"❌ SMTP AUTH HATASI: {e}")
        return False
    except Exception as e:
        print(f"❌ Iletisim formu mail hatasi: {type(e).__name__}: {e}")
        return False


# SIFRE SIFIRLAMA
@app.post("/reset-password")
async def reset_password(data: dict):
    conn = None
    try:
        email = str(data.get("email")).strip().lower()
        new_password = data.get("password")

        # Sifreyi Bcrypt ile sifreliyoruz
        hashed_password = bcrypt.hashpw(
            new_password.encode('utf-8'), 
            bcrypt.gensalt()
        ).decode('utf-8')

        conn = get_db_connection()
        cursor = conn.cursor()

        query = 'UPDATE users SET password_hash = %s WHERE email = %s'
        
        cursor.execute(query, (hashed_password, email))
        conn.commit()

        if cursor.rowcount == 0:
            return {"status": "error", "message": "Kullanici bulunamadi."}

        cursor.close()
        print(f"BASARILI: {email} sifresi sifrelenerek guncellendi.")
        return {"status": "success", "message": "Sifreniz basariyla guncellendi."}

    except Exception as e:
        print(f"Sifirlama Hatasi: {e}")
        return {"status": "error", "message": "Sistem hatasi olustu."}
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

# --- PROFİL FOTOĞRAFI YÜKLEME ---
PROFILE_UPLOAD_DIR = "uploads/profiles"
os.makedirs(PROFILE_UPLOAD_DIR, exist_ok=True)

@app.get("/user/profile/{user_id}")
async def get_user_profile(user_id: int):
    """Kullanıcının profil bilgilerini döndürür (profil fotoğrafı dahil)"""
    conn = None
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT user_id, email, profile_image_path, full_name FROM public.users WHERE user_id = %s",
            (user_id,)
        )
        row = cur.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Kullanici bulunamadi")
        return {
            "user_id": row[0],
            "email": row[1],
            "profile_image_path": row[2] or "",
            "full_name": row[3] or ""
        }
    except Exception as e:
        print(f"Profil getirme hatası: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

@app.post("/user/upload_profile_photo/{user_id}")
async def upload_profile_photo(user_id: int, file: UploadFile = File(...)):
    conn = None
    try:
        # Dosya uzantısını al
        ext = file.filename.split(".")[-1].lower() if "." in file.filename else "jpg"
        file_name = f"profile_{user_id}.{ext}"
        file_path = os.path.join(PROFILE_UPLOAD_DIR, file_name)

        # Dosyayı kaydet
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        # Path'i normalize et (Windows ters slash'ı düz slash'a çevir)
        normalized_path = file_path.replace("\\", "/")

        # Veritabanını güncelle
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "UPDATE public.users SET profile_image_path = %s WHERE user_id = %s",
            (normalized_path, user_id)
        )
        conn.commit()
        cur.close()

        print(f"Profil fotoğrafı yüklendi: user={user_id}, path={normalized_path}")
        return {"status": "success", "image_path": normalized_path}

    except Exception as e:
        print(f"Profil fotoğrafı yükleme hatası: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if conn:
            conn.close()

# SATICI ICIN - Sattigi kitaplar
@app.get("/my-sold-books/{user_id}")
async def get_my_sold_books(user_id: int):
    """Satıcının sattığı kitapları döndürür (kitap silinse bile orders'dan gelir)"""
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT email FROM users WHERE user_id = %s", (user_id,))
        user_row = cur.fetchone()
        if not user_row:
            return []
        user_email = user_row[0]

        cur.execute("""
            SELECT DISTINCT ON (o.book_id)
                o.book_id,
                COALESCE(o.book_title, 'Kitap') as title,
                COALESCE(o.book_author, '') as author,
                o.price as paid_price,
                o.book_image as image_path,
                COALESCE(o.book_category, '') as category,
                o.seller_email,
                o.created_at as order_date,
                buyer.email as buyer_email
            FROM orders o
            LEFT JOIN users buyer ON o.user_id = buyer.user_id
            WHERE o.seller_email = %s AND o.status = 'SUCCESS'
            ORDER BY o.book_id, o.created_at DESC
        """, (user_email,))
        rows = cur.fetchall()
        rows = sorted(rows, key=lambda x: x[7] if x[7] else '', reverse=True)

        result = []
        for r in rows:
            image_path = r[4]
            if image_path:
                if image_path.startswith('http'):
                    image_url = image_path
                elif image_path.startswith('/uploads/'):
                    image_url = f"{BASE_URL}{image_path}"
                else:
                    image_url = f"{BASE_URL}/uploads/{image_path}"
            else:
                image_url = None

            result.append({
                "book_id": r[0],
                "title": r[1],
                "author": r[2],
                "paid_price": float(r[3]) if r[3] else 0,
                "price": float(r[3]) if r[3] else 0,
                "image_path": image_url,
                "category": r[5],
                "seller_email": r[6],
                "order_date": r[7].isoformat() if r[7] else None,
                "buyer_email": r[8] or "Bilinmiyor",
                "is_sold": True
            })
        return result
    except Exception as e:
        print(f"Satici satilan kitaplar hatasi: {e}")
        return []
    finally:
        conn.close()

# KULLANICI BİLGİLERİNİ GÜNCELLE
class UpdateUserInfo(BaseModel):
    user_id: int
    university: Optional[str] = None
    department: Optional[str] = None
    full_name: Optional[str] = None

@app.put("/user/update-info")
async def update_user_info(data: UpdateUserInfo):
    conn = get_db_connection()
    try:
        cur = conn.cursor()
        updates = []
        values = []
        if data.university is not None:
            updates.append("university = %s")
            values.append(data.university)
        if data.department is not None:
            updates.append("department = %s")
            values.append(data.department)
        if data.full_name is not None:
            updates.append("full_name = %s")
            values.append(data.full_name)
        
        if not updates:
            return {"status": "error", "message": "Güncellenecek alan yok"}
        
        values.append(data.user_id)
        cur.execute(
            f"UPDATE public.users SET {', '.join(updates)} WHERE user_id = %s",
            values
        )
        conn.commit()
        return {"status": "success"}
    except Exception as e:
        print(f"Kullanici guncelleme hatasi: {e}")
        return {"status": "error", "message": str(e)}
    finally:
        conn.close()
