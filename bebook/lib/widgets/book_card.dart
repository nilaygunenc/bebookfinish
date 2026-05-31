import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../models/book_model.dart';
import '../features/post_ad/edit_book_screen.dart';
import '../features/home/book_detail_screen.dart';

List<Book> favoriteBooks = [];

// ✅ YENİ: Kullanıcı bazlı sepet yönetimi
class CartManager {
  static final Map<int, List<Book>> _userCarts = {};
  
  static List<Book> getCart(int? userId) {
    if (userId == null) return [];
    return _userCarts[userId] ?? [];
  }
  
  static void addToCart(int? userId, Book book) {
    if (userId == null) return;
    _userCarts[userId] ??= [];
    if (!_userCarts[userId]!.any((item) => item.id == book.id)) {
      _userCarts[userId]!.add(book);
    }
  }
  
  static void removeFromCart(int? userId, int bookId) {
    if (userId == null) return;
    _userCarts[userId]?.removeWhere((book) => book.id == bookId);
  }
  
  static void clearCart(int? userId) {
    if (userId == null) return;
    _userCarts[userId]?.clear();
  }
  
  static void clearAllCarts() {
    _userCarts.clear();
  }
}

// ✅ ESKI: Global sepet listesi (geriye dönük uyumluluk için)
List<Book> get cartBooks {
  // Mevcut kullanıcının sepetini döndür
  return CartManager.getCart(_currentUserId);
}

int? _currentUserId;

// Global favori değişiklik bildirimi için ValueNotifier
final ValueNotifier<int> favoriteChangeNotifier = ValueNotifier<int>(0);

// Global logout bildirimi için ValueNotifier
final ValueNotifier<bool> logoutNotifier = ValueNotifier<bool>(false);

class BookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onUpdated;
  final bool isMyPost;

  const BookCard({
    super.key,
    required this.book,
    this.onUpdated,
    this.isMyPost = false,
  });

  @override
  State<BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<BookCard> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckFavorite();
    
    // Logout dinleyicisi ekle
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _handleLogout() {
    if (logoutNotifier.value == true) {
      // Logout yapıldığında tüm favori state'lerini temizle
      if (mounted) {
        setState(() {
          _isFavorite = false;
          _currentUserId = null;
          _isLoadingFavorite = false;
        });
      }
    }
  }

  Future<void> _loadUserAndCheckFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          // ✅ Global _currentUserId'yi güncelle (sepet için)
          _currentUserId = userId;
        });
        final isFav = await ApiService.checkFavorite(userId, widget.book.id);
        setState(() {
          _isFavorite = isFav;
          _isLoadingFavorite = false;
        });
      } else {
        setState(() => _isLoadingFavorite = false);
      }
    } catch (e) {
      setState(() => _isLoadingFavorite = false);
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
      // Favoriler listesini güncelle
      favoriteChangeNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Favorilere eklendi ❤️"), backgroundColor: Colors.green, duration: Duration(seconds: 1)),
      );
      // onUpdated callback'i varsa çağır
      widget.onUpdated?.call();
    } else if (result != null && result['status'] == 'removed') {
      setState(() => _isFavorite = false);
      // Favoriler listesini güncelle
      favoriteChangeNotifier.value++;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Favorilerden çıkarıldı"), backgroundColor: Colors.grey, duration: Duration(seconds: 1)),
      );
      // onUpdated callback'i varsa çağır
      widget.onUpdated?.call();
    }
  }

  void _deleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("İlanı Sil"),
        content: const Text("Bu ilanı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Vazgeç")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sil", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final res = await ApiService.deleteBook(widget.book.id, widget.book.userId);
      if (res['status'] == 'success') {
        widget.onUpdated?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF6C63FF);

    return GestureDetector(
      // Kart'a tıklanınca detay sayfasına git
      // Ama butonlara tıklanınca detay sayfasına gitme (onTap butonlarda override edilir)
      onTap: widget.isMyPost
          ? null // Kendi ilanımsa detay sayfasına gitme
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailScreen(book: widget.book),
                ),
              );
            },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📘 Kitap Resmi
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      widget.book.imagePath.isNotEmpty
                          ? widget.book.imagePath
                          : "https://via.placeholder.com/150",
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.book, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),

                // 📘 Kitap Bilgileri
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.book.author,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${widget.book.price.toStringAsFixed(2)} TL",
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            widget.book.university.length > 3
                                ? widget.book.university.substring(0, 3)
                                : widget.book.university,
                            style: const TextStyle(color: Colors.grey, fontSize: 9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Kendi ilanım → Düzenle/Sil butonları
                      if (widget.isMyPost)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditBookScreen(
                                        book: {
                                          'book_id': widget.book.id,
                                          'user_id': widget.book.userId,
                                          'title': widget.book.title,
                                          'price': widget.book.price.toString(),
                                          'description': widget.book.description,
                                        },
                                      ),
                                    ),
                                  );
                                  if (result == true) widget.onUpdated?.call();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: primaryColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: EdgeInsets.zero,
                                ),
                                child: const Text("Düzenle",
                                    style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: _deleteAd,
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        )
                      else
                        // Başkasının ilanı → Sepete Ekle butonu
                        SizedBox(
                          width: double.infinity,
                          height: 32,
                          child: ElevatedButton(
                            onPressed: () async {
                              // ✅ Kullanıcı kontrolü
                              final prefs = await SharedPreferences.getInstance();
                              final userId = prefs.getInt('user_id');
                              
                              if (userId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Sepete eklemek için giriş yapmalısınız"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              // ✅ Kullanıcı bazlı sepet kontrolü
                              final userCart = CartManager.getCart(userId);
                              final isAlreadyInCart = userCart.any((item) => item.id == widget.book.id);
                              
                              if (!isAlreadyInCart) {
                                CartManager.addToCart(userId, widget.book);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("${widget.book.title} sepete eklendi!"),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Bu kitap zaten sepetinizde!"),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Text("Sepete Ekle", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // ❤️ Favori butonu (kendi ilanımızda gösterme)
            if (!widget.isMyPost)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    // Favori butonuna tıklanınca detay sayfasına gitme
                    _toggleFavorite();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: _isLoadingFavorite
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: _isFavorite ? Colors.red : Colors.grey,
                            size: 16,
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
