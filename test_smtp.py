import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

email = "merveyilmazz0703@gmail.com"
password = "lrinmgnvnebdbyos"  # BeBook app password

print(f"Email: {email}")
print(f"Şifre uzunluğu: {len(password)}")
print(f"Şifre: {password}")
print()

try:
    print("SMTP bağlantısı kuruluyor...")
    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.set_debuglevel(1)
    server.ehlo()
    server.starttls()
    server.ehlo()
    print("STARTTLS tamam, login deneniyor...")
    server.login(email, password)
    print("✅ LOGIN BAŞARILI!")
    
    msg = MIMEMultipart()
    msg['From'] = email
    msg['To'] = email
    msg['Subject'] = 'BeBook OTP Test'
    msg.attach(MIMEText('Test kodu: 123456', 'plain', 'utf-8'))
    
    server.sendmail(email, email, msg.as_string())
    server.quit()
    print("✅ MAIL GÖNDERİLDİ!")
    
except smtplib.SMTPAuthenticationError as e:
    print(f"❌ AUTH HATASI: {e}")
    print()
    print("ÇÖZÜM:")
    print("1. myaccount.google.com adresine gidin")
    print("2. Güvenlik > 2 Adımlı Doğrulama > AKTİF olmalı")
    print("3. Uygulama Şifreleri > BeBook > Yeni şifre oluşturun")
    
except Exception as e:
    print(f"❌ HATA: {type(e).__name__}: {e}")
