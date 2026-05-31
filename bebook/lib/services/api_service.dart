import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ApiService {
  // Web (Chrome) için localhost, mobil için gerçek IP kullan
  static final String baseUrl = kIsWeb
      ? "http://localhost:8002"
      : "http://192.168.0.14:8002";

  // --- Giriş Yap ---
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      debugPrint("Giriş Hatası: $e");
      return null;
    }
  }

  // --- Kayıt Ol ---
  static Future<bool> signup({
    required String email,
    required String password,
    required String university,
    required String department,
    String fullName = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/signup"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "university": university,
          "department": department,
          "full_name": fullName,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Kayıt Hatası: $e");
      return false;
    }
  }

  // --- Kitapları Getir ---
  static Future<List<dynamic>> fetchBooks() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/books"))
          .timeout(const Duration(seconds: 30));
      print("API Response Status: ${response.statusCode}");
      print("API Response Body: ${response.body.substring(0, 200)}...");
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      print("Bağlantı Hatası Detayı: $e");
      return [];
    }
  }

  // --- Ödeme İşlemini Başlat ---
  static Future<Map<String, dynamic>> initiatePayment({
    required int userId,
    required int bookId,
    required double price,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/create-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "book_id": bookId, "price": price}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": "Bağlantı hatası"};
    }
  }

  // --- Toplu Ödeme (Sepet İçin) ---
  static Future<Map<String, dynamic>> makeBulkPayment({
    required int userId,
    required List<int> bookIds,
    required double totalPrice,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/bulk-payment"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "book_ids": bookIds,
          "total_price": totalPrice,
        }),
      );
      return response.statusCode == 200
          ? jsonDecode(response.body)
          : {"status": "error", "message": "Ödeme hatası"};
    } catch (e) {
      return {"status": "error", "message": "Bağlantı hatası"};
    }
  }

  // --- Kitap İlanı Yayınla (Resim Destekli) ---
  static Future<bool> uploadBook({
    required String title,
    required String author,
    required String category,
    required double price,
    required String description,
    required String sellerEmail,
    String publisher = "",
    XFile? imageFile,
  }) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/books"));
      request.fields['title'] = title;
      request.fields['author'] = author;
      request.fields['category'] = category;
      request.fields['price'] = price.toString();
      request.fields['description'] = description;
      request.fields['seller_email'] = sellerEmail;
      request.fields['publisher'] = publisher;

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';
        request.files.add(
          http.MultipartFile.fromBytes('file', bytes, filename: fileName),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await streamedResponse.stream.bytesToString();
      debugPrint("Upload response: ${streamedResponse.statusCode} - $responseBody");
      return streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201;
    } catch (e) {
      debugPrint("Yükleme Hatası: $e");
      return false;
    }
  }

  // --- Kullanıcının Kitaplarını Getir ---
  static Future<List<dynamic>> getMyBooks(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/my-books/$userId'));
    return response.statusCode == 200 ? jsonDecode(response.body) : [];
  }

  // --- Favori Ekle/Çıkar ---
  static Future<Map<String, dynamic>?> toggleFavorite(int userId, int bookId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/favorites/toggle"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"user_id": userId, "book_id": bookId}),
      );
      return response.statusCode == 200 ? jsonDecode(response.body) : null;
    } catch (e) {
      debugPrint("Favori hatası: $e");
      return null;
    }
  }

  // --- Favorileri Getir ---
  static Future<List<dynamic>> getFavorites(int userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/favorites/$userId'));
      return response.statusCode == 200 ? jsonDecode(response.body) : [];
    } catch (e) {
      debugPrint("Favoriler yükleme hatası: $e");
      return [];
    }
  }

  // --- Favori Kontrol ---
  static Future<bool> checkFavorite(int userId, int bookId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/favorites/check/$userId/$bookId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_favorite'] ?? false;
      }
      return false;
    } catch (e) {
      debugPrint("Favori kontrol hatası: $e");
      return false;
    }
  }

  // --- İletişim Formu ---
  static Future<bool> sendContactMessage(String fullName, String email, String message) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/contact"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"full_name": fullName, "email": email, "message": message}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- Sipariş Durumu ---
  static Future<Map<String, dynamic>> getOrderStatus(int? orderId) async {
    if (orderId == null) return {'status': 'FAILURE'};
    try {
      final response = await http.get(Uri.parse('$baseUrl/order-status/$orderId'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return {'status': 'FAILURE'};
      }
    } catch (e) {
      debugPrint("Sorgulama Hatası: $e");
      return {'status': 'ERROR'};
    }
  }

  // --- Kitap Güncelle ---
  static Future<Map<String, dynamic>> updateBook(int bookId, int userId,
      String title, double price, String description) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/update-book'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "book_id": bookId,
          "user_id": userId,
          "title": title,
          "price": price,
          "description": description,
        }),
      );
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint("Güncelleme Hatası: $e");
      return {"status": "error"};
    }
  }

  // --- Kitap Sil ---
  static Future<Map<String, dynamic>> deleteBook(int bookId, int userId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/delete-book/$bookId/$userId'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {"status": "error", "message": "Silme işlemi başarısız."};
      }
    } catch (e) {
      debugPrint("Silme Hatası: $e");
      return {"status": "error", "message": "Bağlantı hatası."};
    }
  }

  // --- Kişiselleştirilmiş Öneriler ---
  static Future<List<dynamic>> getRecommendations(int userId, {int topN = 5}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/recommendations/$userId?top_n=$topN'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) return decoded;
        return [];
      }
      debugPrint("Öneri sistemi HTTP hatası: ${response.statusCode}");
      return [];
    } catch (e) {
      debugPrint("Öneri sistemi hatası: $e");
      return [];
    }
  }

  // ─────────────────────────────────────────
  // YENİ: Şifre Sıfırlama (OTP)
  // ─────────────────────────────────────────

  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/verify-otp"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "otp": otp}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );
      return jsonDecode(response.body);
    } catch (e) {
      return {"status": "error", "message": e.toString()};
    }
  }

  // ─────────────────────────────────────────
  // YENİ: Sepet İşlemleri (Backend tabanlı)
  // ─────────────────────────────────────────

  static Future<List<dynamic>> getCartItems(int userId) async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/cart/$userId"));
      return response.statusCode == 200 ? json.decode(response.body) : [];
    } catch (e) {
      debugPrint("Sepet Çekme Hatası: $e");
      return [];
    }
  }

  static Future<bool> addToCart(int userId, int bookId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/add-to-cart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": userId, "book_id": bookId}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint("Sepete Ekleme Hatası: $e");
      return false;
    }
  }

  static Future<bool> removeFromCart(int userId, int bookId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/remove-from-cart/$userId/$bookId"),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ─────────────────────────────────────────
  // YENİ: Mesajlaşma
  // ─────────────────────────────────────────

  static Future<void> markMessagesAsRead(int receiverId, int senderId, int bookId) async {
    try {
      final url = Uri.parse(
        "$baseUrl/mark_messages_as_read?receiver_id=$receiverId&sender_id=$senderId&book_id=$bookId",
      );
      await http.post(url);
    } catch (e) {
      debugPrint("Okundu hatası: $e");
    }
  }

  // ─────────────────────────────────────────
  // YENİ: Profil Fotoğrafı Yükleme
  // ─────────────────────────────────────────

  static Future<String?> uploadProfilePhoto(int userId, File imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/upload_profile_photo/$userId'),
      );

      // Web ve mobil uyumlu: bytes ile yükle
      final bytes = await imageFile.readAsBytes();
      final fileName = imageFile.path.split('/').last.split('\\').last;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName.isNotEmpty ? fileName : 'profile.jpg',
      ));

      var streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      debugPrint("Profil fotoğrafı yanıtı: ${streamedResponse.statusCode} - $responseBody");

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['image_path']?.toString();
      }
      debugPrint("Profil fotoğrafı hata: ${streamedResponse.statusCode} - $responseBody");
      return null;
    } catch (e) {
      debugPrint("Profil fotoğrafı yükleme hatası: $e");
      return null;
    }
  }

  // XFile ile profil fotoğrafı yükleme (web uyumlu)
  static Future<String?> uploadProfilePhotoXFile(int userId, XFile imageFile) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/user/upload_profile_photo/$userId'),
      );
      final bytes = await imageFile.readAsBytes();
      final fileName = imageFile.name.isNotEmpty ? imageFile.name : 'profile.jpg';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));

      var streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      debugPrint("Profil fotoğrafı yanıtı: ${streamedResponse.statusCode} - $responseBody");

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['image_path']?.toString();
      }
      return null;
    } catch (e) {
      debugPrint("Profil fotoğrafı yükleme hatası: $e");
      return null;
    }
  }
}
