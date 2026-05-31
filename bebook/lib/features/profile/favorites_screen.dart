import 'package:flutter/material.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import '../../widgets/book_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Book> _favoriteBooks = [];
  bool _isLoading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    
    // Favori değişikliklerini dinle
    favoriteChangeNotifier.addListener(_onFavoriteChanged);
    
    // Logout dinleyicisi ekle
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    favoriteChangeNotifier.removeListener(_onFavoriteChanged);
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _onFavoriteChanged() {
    // Favori değiştiğinde listeyi yenile
    _loadFavorites();
  }

  void _handleLogout() {
    if (logoutNotifier.value == true) {
      // Logout yapıldığında favorileri temizle
      if (mounted) {
        setState(() {
          _favoriteBooks = [];
          _currentUserId = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      
      if (userId != null) {
        setState(() => _currentUserId = userId);
        
        final rawData = await ApiService.getFavorites(userId);
        final favorites = rawData.map((json) => Book.fromJson(json)).toList();
        
        setState(() {
          _favoriteBooks = favorites;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Favoriler yükleme hatası: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          "Favorilerim ❤️",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (_favoriteBooks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadFavorites();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
            )
          : _currentUserId == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.login,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Favorileri görmek için giriş yapmalısınız",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : _favoriteBooks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Henüz favori kitap eklemedin",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Beğendiğin kitapları favorilere ekle!",
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _favoriteBooks.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                          childAspectRatio: 0.75,
                        ),
                        itemBuilder: (context, index) {
                          return BookCard(
                            book: _favoriteBooks[index],
                            onUpdated: () {
                              // Favori durumu değiştiğinde listeyi yenile
                              _loadFavorites();
                            },
                          );
                        },
                      ),
                    ),
    );
  }
}