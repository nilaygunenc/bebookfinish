import 'package:flutter/material.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_detail_screen.dart';

class BookDetailScreen extends StatefulWidget {
  final Book book;

  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  bool _isFavorite = false;
  bool _isLoading = true;
  int? _currentUserId;
  String _currentUserName = '';

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckFavorite();
  }

  Future<void> _loadUserAndCheckFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userEmail = prefs.getString('user_email') ?? '';
      
      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          _currentUserName = userEmail.split('@').first;
        });
        
        // Favori durumunu kontrol et
        final isFav = await ApiService.checkFavorite(userId, widget.book.id);
        setState(() {
          _isFavorite = isFav;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Kullanıcı bilgisi yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Favorilere eklemek için giriş yapmalısınız"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final result = await ApiService.toggleFavorite(_currentUserId!, widget.book.id);
    
    if (result != null && result['status'] == 'added') {
      setState(() => _isFavorite = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Favorilere eklendi ❤️"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (result != null && result['status'] == 'removed') {
      setState(() => _isFavorite = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Favorilerden çıkarıldı"),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // App Bar with Image
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Favori Butonu
              _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : Colors.black,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'book_${widget.book.id}',
                child: Image.network(
                  widget.book.imagePath.isNotEmpty
                      ? widget.book.imagePath
                      : "https://via.placeholder.com/400x600",
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.book, size: 100, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Başlık
                    Text(
                      widget.book.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Yazar
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          widget.book.author,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Yayınevi
                    if (widget.book.publisher.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.business_outlined, size: 20, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(
                            widget.book.publisher,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // Kategori ve Üniversite
                    Row(
                      children: [
                        // Kategori
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.category_outlined, size: 16, color: primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                widget.book.category,
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Üniversite
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.school_outlined, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                widget.book.university,
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Fiyat
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor.withOpacity(0.1), primaryColor.withOpacity(0.05)],
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Fiyat",
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                          Text(
                            "${widget.book.price} TL",
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Açıklama
                    const Text(
                      "Açıklama",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.book.description.isNotEmpty
                          ? widget.book.description
                          : "Bu kitap için açıklama bulunmamaktadır.",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Satıcı Bilgisi
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Satıcı Bilgileri",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                widget.book.sellerEmail,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.school_outlined, size: 18, color: Colors.grey),
                              const SizedBox(width: 8),
                              Text(
                                "${widget.book.university} - ${widget.book.department}",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100), // Buton için boşluk
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // Satın Al Butonu (Sabit Alt Kısım)
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: () async {
              if (_currentUserId != null) {
                try {
                  final result = await ApiService.initiatePayment(
                    userId: _currentUserId!,
                    bookId: widget.book.id,
                    price: widget.book.price,
                  );
                  if (result['status'] == 'success' && result['paymentPageUrl'] != null) {
                    // Ödeme URL'sini aç
                    final paymentUrl = result['paymentPageUrl'] as String;
                    final uri = Uri.parse(paymentUrl);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Ödeme sayfasına yönlendiriliyor..."), backgroundColor: Colors.blue),
                    );
                    
                    // URL'yi tarayıcıda aç
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Ödeme sayfası açılamadı"), backgroundColor: Colors.red),
                      );
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result['errorMessage'] ?? "Ödeme başlatılamadı"), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Bağlantı hatası: $e"), backgroundColor: Colors.red),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Satın almak için giriş yapmalısınız"),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined, size: 24),
                SizedBox(width: 12),
                Text(
                  "Satın Al",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
