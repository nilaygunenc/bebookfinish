import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';
import '../services/api_service.dart';
import '../models/book_model.dart';
import '../features/home/premium_book_detail_screen.dart';
import 'book_card.dart';

/// 💎 Premium Kitap Kartı - Glassmorphism & Advanced Animations
class PremiumBookCard extends StatefulWidget {
  final Book book;
  final VoidCallback? onUpdated;
  final bool isMyPost;
  final int index;

  const PremiumBookCard({
    super.key,
    required this.book,
    this.onUpdated,
    this.isMyPost = false,
    this.index = 0,
  });

  @override
  State<PremiumBookCard> createState() => _PremiumBookCardState();
}

class _PremiumBookCardState extends State<PremiumBookCard>
    with TickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  int? _currentUserId;
  bool _isHovered = false;

  late AnimationController _hoverController;
  late AnimationController _favoriteController;
  late AnimationController _shimmerController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _favoriteScaleAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckFavorite();
    
    // Hover animation
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );
    
    // Favorite animation
    _favoriteController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _favoriteScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(
      parent: _favoriteController,
      curve: Curves.elasticOut,
    ));
    
    // Shimmer animation — devre dışı bırakıldı (dispose hatası veriyordu)
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    // repeat() kaldırıldı
    
    logoutNotifier.addListener(_handleLogout);
    // favoriteChangeNotifier listener kaldırıldı — GlobalKey çakışmasına yol açıyordu
  }

  @override
  void dispose() {
    _hoverController.stop();
    _favoriteController.stop();
    _shimmerController.stop();
    _hoverController.dispose();
    _favoriteController.dispose();
    _shimmerController.dispose();
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _onFavoriteChanged() {
    if (mounted) {
      _loadUserAndCheckFavorite();
    }
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
        if (mounted) {
          setState(() {
            _isFavorite = isFav;
            _isLoadingFavorite = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFavorite = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      _showSnackBar("Favorilere eklemek için giriş yapmalısınız", AppTheme.warningAmber);
      return;
    }
    
    HapticFeedback.mediumImpact();
    _favoriteController.forward(from: 0);
    
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (!widget.isMyPost) {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          PremiumBookDetailScreen(book: widget.book),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withOpacity(_isHovered ? 0.3 : 0.1),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Background gradient
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.neutralWhite,
                                AppTheme.primaryIndigo.withOpacity(0.03),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Main content
                      widget.isMyPost
                          ? _buildMyPostLayout()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildImageSection(),
                                Expanded(
                                  child: ClipRect(
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  widget.book.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.person_outline_rounded, size: 11, color: Colors.grey),
                                                    const SizedBox(width: 3),
                                                    Expanded(
                                                      child: Text(
                                                        widget.book.author,
                                                        style: const TextStyle(
                                                          color: Colors.grey,
                                                          fontSize: 10,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildBottomSection(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      
                      // Shimmer effect on hover
                      if (_isHovered)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    stops: [
                                      (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                                      _shimmerAnimation.value.clamp(0.0, 1.0),
                                      (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                                    ],
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withOpacity(0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        // Main image with hero animation
        Hero(
          tag: 'book_${widget.book.id}_${widget.isMyPost}',
          child: AspectRatio(
            aspectRatio: widget.isMyPost ? 2.5 : 0.75,
            child: Image.network(
              widget.book.imagePath.isNotEmpty
                  ? widget.book.imagePath
                  : "https://via.placeholder.com/300x400",
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryIndigo.withOpacity(0.2),
                      AppTheme.accentCyan.withOpacity(0.2),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 64,
                    color: AppTheme.neutralMedium,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.3),
                ],
              ),
            ),
          ),
        ),
        
        // Category badge with glassmorphism
        Positioned(
          top: 12,
          left: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.book.category,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
        
        // Favorite button with glassmorphism
        if (!widget.isMyPost)
          Positioned(
            top: 12,
            right: 12,
            child: ScaleTransition(
              scale: _favoriteScaleAnimation,
              child: GestureDetector(
                onTap: _toggleFavorite,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: _isLoadingFavorite
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? AppTheme.accentOrange : Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMyPostLayout() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst: resim + bilgi yan yana
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resim
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80,
                  height: 100,
                  child: Image.network(
                    widget.book.imagePath.isNotEmpty
                        ? widget.book.imagePath
                        : "https://via.placeholder.com/80x100",
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.primaryIndigo.withOpacity(0.2),
                      child: Icon(Icons.menu_book_rounded, color: AppTheme.neutralMedium, size: 36),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Bilgi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.book.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.book.author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.neutralDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${widget.book.price.toStringAsFixed(0)} ₺",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Alt: düzenle / sil butonları
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final titleController = TextEditingController(text: widget.book.title);
                    final priceController = TextEditingController(text: widget.book.price.toStringAsFixed(0));
                    final descController = TextEditingController(text: widget.book.description);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("İlanı Düzenle"),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: titleController, decoration: const InputDecoration(labelText: "Başlık")),
                              const SizedBox(height: 8),
                              TextField(controller: priceController, decoration: const InputDecoration(labelText: "Fiyat"), keyboardType: TextInputType.number),
                              const SizedBox(height: 8),
                              TextField(controller: descController, decoration: const InputDecoration(labelText: "Açıklama"), maxLines: 3),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Kaydet")),
                        ],
                      ),
                    );
                    if (confirmed == true && _currentUserId != null) {
                      final result = await ApiService.updateBook(
                        widget.book.id, _currentUserId!,
                        titleController.text,
                        double.tryParse(priceController.text) ?? widget.book.price,
                        descController.text,
                      );
                      if (result['status'] == 'success') {
                        _showSnackBar("İlan güncellendi ✅", AppTheme.successGreen);
                        widget.onUpdated?.call();
                      } else {
                        _showSnackBar("Güncelleme başarısız", AppTheme.errorRed);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo, size: 18),
                        const SizedBox(width: 6),
                        Text("Düzenle", style: TextStyle(color: AppTheme.primaryIndigo, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("İlanı Sil"),
                        content: const Text("Bu ilanı silmek istediğinize emin misiniz?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Sil", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && _currentUserId != null) {
                      final result = await ApiService.deleteBook(widget.book.id, _currentUserId!);
                      if (result['status'] == 'success') {
                        _showSnackBar("İlan silindi 🗑️", AppTheme.successGreen);
                        widget.onUpdated?.call();
                      } else {
                        _showSnackBar("Silme başarısız", AppTheme.errorRed);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 18),
                        const SizedBox(width: 6),
                        Text("Sil", style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Fiyat
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            "${widget.book.price.toStringAsFixed(0)} ₺",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),

        const SizedBox(height: 3),

        // Sepete ekle butonu (başkasının ilanı)
        if (!widget.isMyPost)
          GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              final prefs = await SharedPreferences.getInstance();
              final userId = prefs.getInt('user_id');
              if (userId == null) {
                _showSnackBar("Sepete eklemek için giriş yapmalısınız", AppTheme.warningAmber);
                return;
              }
              // Kendi kitabını sepete ekleyemez
              if (widget.book.userId == userId) {
                _showSnackBar("Kendi ilanınızı sepete ekleyemezsiniz", AppTheme.warningAmber);
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
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text(
                    "Sepete Ekle",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Düzenle / Sil butonları (kendi ilanı)
        if (widget.isMyPost)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final titleController = TextEditingController(text: widget.book.title);
                    final priceController = TextEditingController(text: widget.book.price.toStringAsFixed(0));
                    final descController = TextEditingController(text: widget.book.description);

                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("İlanı Düzenle"),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextField(controller: titleController, decoration: const InputDecoration(labelText: "Başlık")),
                              const SizedBox(height: 8),
                              TextField(controller: priceController, decoration: const InputDecoration(labelText: "Fiyat"), keyboardType: TextInputType.number),
                              const SizedBox(height: 8),
                              TextField(controller: descController, decoration: const InputDecoration(labelText: "Açıklama"), maxLines: 3),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Kaydet")),
                        ],
                      ),
                    );

                    if (confirmed == true && _currentUserId != null) {
                      final result = await ApiService.updateBook(
                        widget.book.id,
                        _currentUserId!,
                        titleController.text,
                        double.tryParse(priceController.text) ?? widget.book.price,
                        descController.text,
                      );
                      if (result['status'] == 'success') {
                        _showSnackBar("İlan güncellendi ✅", AppTheme.successGreen);
                        widget.onUpdated?.call();
                      } else {
                        _showSnackBar("Güncelleme başarısız", AppTheme.errorRed);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_outlined, color: AppTheme.primaryIndigo, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("İlanı Sil"),
                        content: const Text("Bu ilanı silmek istediğinize emin misiniz?"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("İptal")),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Sil", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && _currentUserId != null) {
                      final result = await ApiService.deleteBook(widget.book.id, _currentUserId!);
                      if (result['status'] == 'success') {
                        _showSnackBar("İlan silindi 🗑️", AppTheme.successGreen);
                        widget.onUpdated?.call();
                      } else {
                        _showSnackBar("Silme başarısız", AppTheme.errorRed);
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.errorRed.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 18),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
