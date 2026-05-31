import 'package:flutter/material.dart';
import '../../widgets/book_card.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import '../post_ad/add_product_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState(); // public state
}

class HomeScreenState extends State<HomeScreen> {
  // ── Tüm kitaplar ──────────────────────────────────────────────────────
  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // ── Kullanıcı bilgisi ─────────────────────────────────────────────────
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isLoggedIn = false; // GİRİŞ DURUMU BAYRAGI

  // ── Öneri sistemi ─────────────────────────────────────────────────────
  List<Book> _recommendedBooks = [];
  bool _isLoadingRecommendations = false;

  @override
  void initState() {
    super.initState();
    _init();
    
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
      // Logout yapıldığında kullanıcı bilgilerini temizle ve yenile
      if (mounted) {
        _checkLoginStatus();
        setState(() {
          _recommendedBooks = [];
          _currentUserId = null;
          _currentUserEmail = null;
          _isLoggedIn = false;
        });
      }
    }
  }

  /// Uygulama açılınca çalışır:
  /// 1. Kullanıcı giriş durumunu kontrol et
  /// 2. Tüm kitapları yükle
  /// 3. Sadece giriş yapılmışsa önerileri yükle
  Future<void> _init() async {
    await _checkLoginStatus();
    await _loadBooks();
    if (_isLoggedIn) {
      await _loadRecommendations();
    }
  }

  /// SharedPreferences'tan kullanıcı bilgisini okur.
  /// user_id VE is_logged_in bayrağı birlikte kontrol edilir.
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final loggedIn = prefs.getBool('is_logged_in') ?? false;

    setState(() {
      _currentUserId = userId;
      _currentUserEmail = prefs.getString('user_email');
      // Her iki koşul da sağlanmalı: user_id var VE is_logged_in = true
      _isLoggedIn = (userId != null && userId > 0 && loggedIn);
    });
  }

  /// Backend'den giriş yapan kullanıcının bölümüne özel önerileri çeker.
  /// Giriş yapılmamışsa hiç çağrılmaz.
  Future<void> _loadRecommendations() async {
    if (!_isLoggedIn || _currentUserId == null) return;

    setState(() => _isLoadingRecommendations = true);
    try {
      final rawData = await ApiService.getRecommendations(
        _currentUserId!,
        topN: 5,
      );
      final books = rawData.map((json) => Book.fromJson(json)).toList();
      setState(() {
        _recommendedBooks = books;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      // Öneri sistemi hata verse de uygulama çalışmaya devam eder
      setState(() {
        _recommendedBooks = [];
        _isLoadingRecommendations = false;
      });
    }
  }

  /// Tüm kitapları yükler (giriş durumundan bağımsız).
  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final rawData = await ApiService.fetchBooks();
      final books = rawData.map((json) => Book.fromJson(json)).toList();
      setState(() {
        _allBooks = books;
        _filteredBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// Arama çubuğu değişince filtreleme yapar.
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filteredBooks = query.isEmpty
          ? _allBooks
          : _allBooks.where((book) {
              final q = query.toLowerCase();
              return book.title.toLowerCase().contains(q) ||
                  book.author.toLowerCase().contains(q) ||
                  book.category.toLowerCase().contains(q);
            }).toList();
    });
  }

  /// Yenile: kitapları ve (giriş yapılmışsa) önerileri yeniden çeker.
  Future<void> _refresh() async {
    await _loadBooks();
    if (_isLoggedIn) {
      await _loadRecommendations();
    }
  }

  /// Profil sekmesinden giriş/çıkış yapılınca dışarıdan çağrılır.
  Future<void> refreshAfterLogin() async {
    await _checkLoginStatus();
    await _loadBooks();
    if (_isLoggedIn) {
      await _loadRecommendations();
    } else {
      setState(() => _recommendedBooks = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF6C63FF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Bebook Keşfet",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh, color: Colors.black),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Arama Çubuğu ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Kitap, yazar veya bölüm ara...",
                prefixIcon: const Icon(Icons.search, color: primaryColor),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── İçerik ────────────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : _filteredBooks.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.book_outlined,
                                size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? "Henüz satılık kitap bulunmuyor."
                                  : "\"$_searchQuery\" için sonuç bulunamadı.",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refresh,
                        child: CustomScrollView(
                          slivers: [
                            // ── 🤖 SANA ÖZEL (SADECE GİRİŞ YAPILMIŞSA) ──
                            if (_isLoggedIn && _searchQuery.isEmpty) ...[
                              // Başlık
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                                  child: Row(
                                    children: [
                                      const Text(
                                        "🤖 Sana Özel",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: primaryColor,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          "AI",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Öneri listesi veya yükleniyor göstergesi
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  height: 220,
                                  child: _isLoadingRecommendations
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                              color: primaryColor),
                                        )
                                      : _recommendedBooks.isEmpty
                                          ? const Center(
                                              child: Text(
                                                "Henüz öneri oluşturulamadı.",
                                                style: TextStyle(
                                                    color: Colors.grey),
                                              ),
                                            )
                                          : ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12),
                                              itemCount:
                                                  _recommendedBooks.length,
                                              itemBuilder: (context, index) {
                                                return SizedBox(
                                                  width: 140,
                                                  child: Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 4),
                                                    child: BookCard(
                                                      book: _recommendedBooks[
                                                          index],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                ),
                              ),

                              // "Tüm İlanlar" başlığı
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding:
                                      EdgeInsets.fromLTRB(16, 12, 16, 4),
                                  child: Text(
                                    "Tüm İlanlar",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // ── 📚 TÜM KİTAPLAR GRID ─────────────────────
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => BookCard(
                                      book: _filteredBooks[index]),
                                  childCount: _filteredBooks.length,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                  childAspectRatio: 0.62,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),

      // ── Kitap Ekle Butonu ──────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProductScreen(
                userId: _currentUserId,
                userEmail: _currentUserEmail,
              ),
            ),
          );
          if (result == true) _loadBooks();
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
