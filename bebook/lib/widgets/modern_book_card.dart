import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/book_model.dart';
import '../features/home/book_detail_screen.dart';
import 'book_card.dart'; // CartManager için

/// 🎨 Modern Kitap Kartı - Asimetrik ve organik tasarım
/// AI şablonlarından farklı, insan elinden çıkmış gibi
class ModernBookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onUpdated;
  final bool isMyPost;
  final bool isCompact; // Öneri listesi için küçük versiyon

  const ModernBookCard({
    super.key,
    required this.book,
    this.onUpdated,
    this.isMyPost = false,
    this.isCompact = false,
  });

  @override
  State<ModernBookCard> createState() => _ModernBookCardState();
}

class _ModernBookCardState extends State<ModernBookCard> 
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  int? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _favoriteAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckFavorite();
    
    // Animasyon controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _favoriteAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    
    // Logout dinleyicisi
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    _animationController.dispose();
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _handleLogout() {
    if (logoutNotifier.value == true && mounted) {
      setState(() {
        _isFavorite = false;
        _currentUserId = null;
        _isLoadingFavorite = false;
      });
    }
  }

  Future<void> _loadUserAndCheckFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      if (userId != null) {
        setState(() => _currentUserId = userId);
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
      _showSnackBar("Favorilere eklemek için giriş yapmalısınız", AppTheme.warningAmber);
      return;
    }
    
    // Animasyon başlat
    _animationController.forward().then((_) => _animationController.reverse());
    
    final result = await ApiService.toggleFavorite(_currentUserId!, widget.book.id);
    if (result != null && result['status'] == 'added') {
      setState(() => _isFavorite = true);
      favoriteChangeNotifier.value++;
      _showSnackBar("Favorilere eklendi ❤️", AppTheme.successGreen);
      widget.onUpdated?.call();
    } else if (result != null && result['status'] == 'removed') {
      setState(() => _isFavorite = false);
      favoriteChangeNotifier.value++;
      _showSnackBar("Favorilerden çıkarıldı", AppTheme.neutralDark);
      widget.onUpdated?.call();
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _animationController.forward(),
        onTapUp: (_) {
          _animationController.reverse();
          if (!widget.isMyPost) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookDetailScreen(book: widget.book),
              ),
            );
          }
        },
        onTapCancel: () => _animationController.reverse(),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.neutralWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: AppTheme.shadowMD,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📸 Görsel Bölümü - Asimetrik kesim
              _buildImageSection(),
              
              // 📝 İçerik Bölümü
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Text(
                        widget.book.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      
                      // Yazar
                      Text(
                        widget.book.author,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.neutralDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const Spacer(),
                      
                      // Alt Bölüm - Fiyat ve Aksiyon
                      _buildBottomSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        // Ana görsel
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppTheme.radiusLG),
            topRight: Radius.circular(AppTheme.radiusLG),
            // Asimetrik kesim için alt köşeleri farklı yap
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(20),
          ),
          child: AspectRatio(
            aspectRatio: widget.isCompact ? 0.7 : 0.65,
            child: Image.network(
              widget.book.imagePath.isNotEmpty
                  ? widget.book.imagePath
                  : "https://via.placeholder.com/300x450",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryIndigo.withOpacity(0.1),
                      AppTheme.accentOrange.withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 48,
                  color: AppTheme.neutralMedium,
                ),
              ),
            ),
          ),
        ),
        
        // Kategori badge - Sol üst
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              boxShadow: AppTheme.shadowSM,
            ),
            child: Text(
              widget.book.category,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
        
        // Favori butonu - Sağ üst (kendi ilanımızda gösterme)
        if (!widget.isMyPost)
          Positioned(
            top: 8,
            right: 8,
            child: ScaleTransition(
              scale: _favoriteAnimation,
              child: GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.shadowSM,
                  ),
                  child: _isLoadingFavorite
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? AppTheme.accentOrange : AppTheme.neutralDark,
                          size: 18,
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Fiyat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: AppTheme.shadowPrimary,
          ),
          child: Text(
            "${widget.book.price.toStringAsFixed(0)} ₺",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        // Aksiyon butonu
        if (!widget.isMyPost)
          GestureDetector(
            onTap: () async {
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('user_id');
              
              if (userId == null) {
                _showSnackBar("Sepete eklemek için giriş yapmalısınız", AppTheme.warningAmber);
                return;
              }
              
              final userCart = CartManager.getCart(userId);
              final isAlreadyInCart = userCart.any((item) => item.id == widget.book.id);
              
              if (!isAlreadyInCart) {
                CartManager.addToCart(userId, widget.book);
                _showSnackBar("Sepete eklendi!", AppTheme.successGreen);
              } else {
                _showSnackBar("Zaten sepetinizde!", AppTheme.warningAmber);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange,
                shape: BoxShape.circle,
                boxShadow: AppTheme.shadowAccent,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}
