import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

email = "merveyilmazz0703@gmail.com"
# Şifre: ockl wtne nrst imfs (boşluklar kaldırıldı)
password = "ocklwtnerstimfs"  # 15 harf - kontrol et

print(f"Şifre uzunluğu: {len(password)}")
print(f"Şifre: {password}")

# Doğru şifre: ockl + wtne + nrst + imfs
correct = "ockl" + "wtne" + "nrst" + "imfs"
print(f"Doğru şifre: {correct}")
print(f"Doğru şifre uzunluğu: {len(correct)}")

try:
    msg = MIMEMultipart()
    msg['From'] = email
    msg['To'] = email
    msg['Subject'] = 'BeBook Test Mail'
    msg.attach(MIMEText('Bu bir test mesajıdır.', 'plain', 'utf-8'))

    server = smtplib.SMTP("smtp.gmail.com", 587)
    server.starttls()
    server.login(email, correct)
    server.sendmail(email, email, msg.as_string())
    server.quit()
    print("✅ MAIL BAŞARIYLA GÖNDERİLDİ!")
except smtplib.SMTPAuthenticationError as e:
    print(f"❌ AUTH HATASI: {e}")
    print("App Password yanlış veya 2FA aktif değil!")
except Exception as e:
    print(f"❌ HATA: {e}")
