import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_detail_screen.dart';

/// 💎 Premium Kitap Detay Ekranı - Hero Animation & Glassmorphism
class PremiumBookDetailScreen extends StatefulWidget {
  final Book book;

  const PremiumBookDetailScreen({super.key, required this.book});

  @override
  State<PremiumBookDetailScreen> createState() => _PremiumBookDetailScreenState();
}

class _PremiumBookDetailScreenState extends State<PremiumBookDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isLoading = true;
  int? _currentUserId;
  String _currentUserEmail = '';
  String _currentUserName = '';
  
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserAndCheckFavorite();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndCheckFavorite() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final userEmail = prefs.getString('user_email') ?? '';

      if (userId != null) {
        setState(() {
          _currentUserId = userId;
          _currentUserEmail = userEmail;
          _currentUserName = userEmail.split('@').first;
        });
        final isFav = await ApiService.checkFavorite(userId, widget.book.id);
        setState(() {
          _isFavorite = isFav;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_currentUserId == null) {
      _showSnackBar("Favorilere eklemek için giriş yapmalısınız", AppTheme.warningAmber);
      return;
    }

    HapticFeedback.mediumImpact();
    final result = await ApiService.toggleFavorite(_currentUserId!, widget.book.id);

    if (result != null && result['status'] == 'added') {
      setState(() => _isFavorite = true);
      _showSnackBar("Favorilere eklendi ❤️", AppTheme.successGreen);
    } else if (result != null && result['status'] == 'removed') {
      setState(() => _isFavorite = false);
      _showSnackBar("Favorilerden çıkarıldı", AppTheme.neutralDark);
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium App Bar with Hero Image
          _buildPremiumAppBar(),
          
          // Content
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
      
      // Premium Bottom Button
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  Widget _buildPremiumAppBar() {
    return SliverAppBar(
      expandedHeight: 450,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          _isFavorite ? Icons.favorite : Icons.favorite_border,
                          color: _isFavorite ? AppTheme.accentOrange : Colors.white,
                        ),
                        onPressed: _toggleFavorite,
                      ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero Image
            Hero(
              tag: 'book_${widget.book.id}_false',
              child: Image.network(
                widget.book.imagePath.isNotEmpty
                    ? widget.book.imagePath
                    : "https://via.placeholder.com/400x600",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryIndigo.withOpacity(0.3),
                        AppTheme.accentCyan.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: const Icon(Icons.book, size: 100, color: Colors.white),
                ),
              ),
            ),
            
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutralWhite,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.book.title,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 12),

            // Author
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.book.author,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.neutralDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Publisher
            if (widget.book.publisher.isNotEmpty)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business_rounded, size: 20, color: AppTheme.accentCyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.book.publisher,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.neutralDark,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Badges
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildBadge(
                  Icons.category_rounded,
                  widget.book.category,
                  AppTheme.primaryGradient,
                ),
                _buildBadge(
                  Icons.school_rounded,
                  widget.book.university,
                  AppTheme.accentGradient,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Price Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryIndigo.withOpacity(0.1),
                    AppTheme.accentCyan.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.primaryIndigo.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Fiyat",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.neutralDark,
                    ),
                  ),
                  ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: Text(
                      "${widget.book.price.toStringAsFixed(0)} ₺",
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Description
            Text(
              "Açıklama",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.book.description.isNotEmpty
                  ? widget.book.description
                  : "Bu kitap için açıklama bulunmamaktadır.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.8,
                color: AppTheme.neutralDark,
              ),
            ),
            const SizedBox(height: 32),

            // Seller Info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.neutralLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppTheme.accentGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Satıcı Bilgileri",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(Icons.email_rounded, widget.book.sellerEmail),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    Icons.school_rounded,
                    "${widget.book.university} - ${widget.book.department}",
                  ),
                ],
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Gradient gradient) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.neutralDark),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.neutralDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // --- MESAJLAŞMA BUTONU ---
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: AppTheme.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryIndigo.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        if (_currentUserId == null) {
                          _showSnackBar("Mesaj göndermek için giriş yapmalısınız", AppTheme.warningAmber);
                          return;
                        }
                        if (widget.book.userId == _currentUserId) {
                          _showSnackBar("Kendi ilanınıza mesaj gönderemezsiniz", AppTheme.warningAmber);
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(
                              receiverId: widget.book.userId ?? 0,
                              receiverName: widget.book.sellerEmail?.split('@').first ?? 'Satıcı',
                              receiverImage: null,
                              bookTitle: widget.book.title,
                              bookId: widget.book.id,
                              myId: _currentUserId!,
                              myName: _currentUserName,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(56, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Icon(
                        Icons.chat_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // --- SATIN AL BUTONU ---
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        if (_currentUserId != null) {
                          try {
                            final result = await ApiService.initiatePayment(
                              userId: _currentUserId!,
                              bookId: widget.book.id,
                              price: widget.book.price,
                            );
                            if (result['status'] == 'success' && result['paymentPageUrl'] != null) {
                              final paymentUrl = result['paymentPageUrl'] as String;
                              final uri = Uri.parse(paymentUrl);
                              _showSnackBar("Ödeme sayfasına yönlendiriliyor...", AppTheme.infoBlue);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                _showSnackBar("Ödeme sayfası açılamadı", AppTheme.errorRed);
                              }
                            } else {
                              _showSnackBar(
                                result['errorMessage'] ?? "Ödeme başlatılamadı",
                                AppTheme.errorRed,
                              );
                            }
                          } catch (e) {
                            _showSnackBar("Bağlantı hatası: $e", AppTheme.errorRed);
                          }
                        } else {
                          _showSnackBar(
                            "Satın almak için giriş yapmalısınız",
                            AppTheme.warningAmber,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Satın Al",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
