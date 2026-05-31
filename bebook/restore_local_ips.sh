#!/bin/bash
# IP Adreslerini Geri Yükleme Script'i

echo "🔧 Lokal IP adreslerini geri yüklüyorum..."

# API Service
sed -i 's|baseUrl = "http://192.168.1.7:8000"|baseUrl = "http://192.168.1.30:8000"|g' lib/services/api_service.dart

# Main.dart
sed -i 's|baseUrl = "http://192.168.1.7:8000"|baseUrl = "http://192.168.1.30:8000"|g' lib/main.dart

# Login Screen
sed -i 's|http://192.168.1.7:8000/login|http://192.168.1.30:8000/login|g' lib/features/profile/login_screen.dart

# Backend
sed -i 's|password="senem2003"|password="senem2003"|g' backend/main.py
sed -i 's|BASE_URL = "http://192.168.1.7:8000"|BASE_URL = "http://192.168.1.30:8000"|g' backend/main.py

echo "✅ IP adresleri geri yüklendi!"
