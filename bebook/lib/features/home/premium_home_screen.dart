import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/premium_book_card.dart';
import '../../widgets/book_card.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import '../post_ad/premium_add_product_screen.dart';
import 'premium_book_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 💎 Premium Ana Sayfa - Glassmorphism & Advanced UI
class PremiumHomeScreen extends StatefulWidget {
  const PremiumHomeScreen({super.key});

  @override
  State<PremiumHomeScreen> createState() => PremiumHomeScreenState();
}

class PremiumHomeScreenState extends State<PremiumHomeScreen>
    with TickerProviderStateMixin {
  // Data
  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // User
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isLoggedIn = false;
  
  // Recommendations
  List<Book> _recommendedBooks = [];
  bool _isLoadingRecommendations = false;
  
  // Animations
  late AnimationController _fabController;
  late AnimationController _headerController;
  late AnimationController _searchController;
  
  late Animation<double> _fabAnimation;
  late Animation<Offset> _headerSlideAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<double> _searchScaleAnimation;
  
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _init();
    
    // FAB animation
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeOutCubic,
    );
    _fabController.forward();
    
    // Header animation
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    ));
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeIn,
    );
    _headerController.forward();
    
    // Search animation
    _searchController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _searchScaleAnimation = CurvedAnimation(
      parent: _searchController,
      curve: Curves.easeOutBack,
    );
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _searchController.forward();
    });
    
    // Scroll listener
    _scrollController.addListener(_onScroll);
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    _fabController.dispose();
    _headerController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
    
    if (_scrollController.position.pixels > 100 && _showFab) {
      setState(() => _showFab = false);
      _fabController.reverse();
    } else if (_scrollController.position.pixels <= 100 && !_showFab) {
      setState(() => _showFab = true);
      _fabController.forward();
    }
  }

  void _handleLogout() {
    if (logoutNotifier.value == true && mounted) {
      _checkLoginStatus();
      setState(() {
        _recommendedBooks = [];
        _currentUserId = null;
        _currentUserEmail = null;
        _isLoggedIn = false;
      });
    }
  }

  Future<void> _init() async {
    await _checkLoginStatus();
    await _loadBooks();
    if (_isLoggedIn) {
      await _loadRecommendations();
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    final loggedIn = prefs.getBool('is_logged_in') ?? false;

    setState(() {
      _currentUserId = userId;
      _currentUserEmail = prefs.getString('user_email');
      _isLoggedIn = (userId != null && userId > 0 && loggedIn);
    });
  }

  Future<void> _loadRecommendations() async {
    if (!_isLoggedIn || _currentUserId == null) return;

    setState(() => _isLoadingRecommendations = true);
    try {
      final rawData = await ApiService.getRecommendations(_currentUserId!, topN: 6);
      final books = rawData.map((json) => Book.fromJson(json)).toList();
      setState(() {
        _recommendedBooks = books;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      setState(() {
        _recommendedBooks = [];
        _isLoadingRecommendations = false;
      });
    }
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final rawData = await ApiService.fetchBooks();
      if (rawData.isEmpty) {
        // Boş gelirse 2 saniye sonra bir kez daha dene
        await Future.delayed(const Duration(seconds: 2));
        final retryData = await ApiService.fetchBooks();
        final books = retryData.map((json) => Book.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _allBooks = books;
            _filteredBooks = books;
            _isLoading = false;
          });
        }
        return;
      }
      final books = rawData.map((json) => Book.fromJson(json)).toList();
      if (mounted) {
        setState(() {
          _allBooks = books;
          _filteredBooks = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Kitap yükleme hatası: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  Future<void> _refresh() async {
    HapticFeedback.mediumImpact();
    await _loadBooks();
    if (_isLoggedIn) {
      await _loadRecommendations();
    }
  }

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
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Animated background
          _buildAnimatedBackground(),
          
          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium header
              _buildPremiumHeader(),
              
              // Search section
              SliverToBoxAdapter(child: _buildSearchSection()),
              
              // Recommendations
              if (_isLoggedIn && _searchQuery.isEmpty) ...[
                SliverToBoxAdapter(child: _buildRecommendationsSection()),
              ],
              
              // All books grid
              _buildBooksGrid(),
            ],
          ),
        ],
      ),
      
      // Premium FAB
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.accentOrange.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PremiumAddProductScreen(
                    userId: _currentUserId,
                    userEmail: _currentUserEmail,
                  ),
                ),
              );
              if (result == true) _loadBooks();
            },
            backgroundColor: AppTheme.accentOrange,
            elevation: 0,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
            label: Text(
              "İlan Ver",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.neutralLight,
              AppTheme.primaryIndigo.withOpacity(0.02),
              AppTheme.accentCyan.withOpacity(0.02),
            ],
          ),
        ),
        child: CustomPaint(
          painter: _BackgroundPainter(scrollOffset: _scrollOffset),
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    final opacity = (1 - (_scrollOffset / 200)).clamp(0.0, 1.0);
    final scale = (1 - (_scrollOffset / 1000)).clamp(0.8, 1.0);
    
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Glassmorphism background
            Positioned.fill(
              child: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 10,
                    sigmaY: 10,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.8),
                          Colors.white.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: FadeTransition(
                  opacity: _headerFadeAnimation,
                  child: SlideTransition(
                    position: _headerSlideAnimation,
                    child: Transform.scale(
                      scale: scale,
                      child: Opacity(
                        opacity: opacity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Logo and title
                            Row(
                              children: [
                                // Animated logo
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.primaryIndigo.withOpacity(0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_stories_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                
                                // Title
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                                        child: Text(
                                          "Bebook",
                                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            letterSpacing: -1,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Kitap dünyasına hoş geldin",
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: AppTheme.neutralDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Notification button
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.neutralWhite,
                                    shape: BoxShape.circle,
                                    boxShadow: AppTheme.shadowSM,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.notifications_none_rounded),
                                    color: AppTheme.primaryIndigo,
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return ScaleTransition(
      scale: _searchScaleAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: TextField(
                onChanged: _onSearchChanged,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: "Kitap, yazar veya kategori ara...",
                  hintStyle: TextStyle(color: AppTheme.neutralDark.withOpacity(0.6)),
                  prefixIcon: ShaderMask(
                    shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _onSearchChanged('');
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Row(
            children: [
              // AI Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppTheme.sunsetGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentOrange.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Sana Özel Öneriler",
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // Refresh button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.neutralWhite,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.shadowSM,
                ),
                child: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppTheme.primaryIndigo,
                  onPressed: _loadRecommendations,
                ),
              ),
            ],
          ),
        ),
        
        // Recommendations list
        SizedBox(
          height: 300,
          child: _isLoadingRecommendations
              ? Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryIndigo,
                    strokeWidth: 3,
                  ),
                )
              : _recommendedBooks.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.neutralDark.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          Text(
                            "Bölümünüze uygun kitap bulunamadı",
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.neutralDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Bölümünüzle ilgili kitaplar eklenince burada görünecek",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.neutralDark.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : SizedBox(
                      height: 300,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _recommendedBooks.length,
                        itemBuilder: (context, index) {
                          final book = _recommendedBooks[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PremiumBookDetailScreen(
                                    book: book,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 150,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Stack(
                                  children: [
                                    // Arka plan gradient
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
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Görsel
                                        Expanded(
                                          flex: 6,
                                          child: ClipRRect(
                                            borderRadius: const BorderRadius.vertical(
                                                top: Radius.circular(24)),
                                            child: Image.network(
                                              book.imagePath.isNotEmpty
                                                  ? book.imagePath
                                                  : "https://via.placeholder.com/150",
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                decoration: BoxDecoration(
                                                  gradient: AppTheme.primaryGradient,
                                                ),
                                                child: const Icon(Icons.book_rounded,
                                                    color: Colors.white, size: 40),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Bilgi kısmı
                                        Expanded(
                                          flex: 5,
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  book.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    const Icon(
                                                        Icons.person_outline_rounded,
                                                        size: 10,
                                                        color: Colors.grey),
                                                    const SizedBox(width: 2),
                                                    Expanded(
                                                      child: Text(
                                                        book.author,
                                                        style: const TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 9),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const Spacer(),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    gradient: AppTheme.primaryGradient,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    "${book.price.toStringAsFixed(0)} ₺",
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                GestureDetector(
                                                  onTap: () async {
                                                    HapticFeedback.mediumImpact();
                                                    final prefs = await SharedPreferences.getInstance();
                                                    final userId = prefs.getInt('user_id');
                                                    if (userId == null) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text("Sepete eklemek için giriş yapın"),
                                                          backgroundColor: AppTheme.warningAmber,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    if (book.userId == userId) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text("Kendi ilanınızı ekleyemezsiniz"),
                                                          backgroundColor: AppTheme.warningAmber,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    final cart = CartManager.getCart(userId);
                                                    if (!cart.any((b) => b.id == book.id)) {
                                                      CartManager.addToCart(userId, book);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text("Sepete eklendi!"),
                                                          backgroundColor: AppTheme.successGreen,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                      );
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text("Zaten sepetinizde!"),
                                                          backgroundColor: AppTheme.warningAmber,
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  child: Container(
                                                    width: double.infinity,
                                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                                    decoration: BoxDecoration(
                                                      gradient: AppTheme.accentGradient,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 11),
                                                        SizedBox(width: 3),
                                                        Text(
                                                          "Sepete Ekle",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
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
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
        
        const SizedBox(height: 32),
        
        // "All Books" header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 32,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                "Tüm İlanlar",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBooksGrid() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryIndigo,
            strokeWidth: 3,
          ),
        ),
      );
    }

    if (_filteredBooks.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryIndigo.withOpacity(0.1),
                      AppTheme.accentCyan.withOpacity(0.1),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 80,
                  color: AppTheme.neutralDark,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isEmpty ? "Henüz kitap bulunmuyor" : "Sonuç bulunamadı",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _searchQuery.isEmpty ? "İlk ilanı sen ver!" : "Farklı bir arama dene",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neutralDark,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => PremiumBookCard(
            book: _filteredBooks[index],
            index: index,
          ),
          childCount: _filteredBooks.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 0.46,
        ),
      ),
    );
  }
}

// Custom painter for animated background
class _BackgroundPainter extends CustomPainter {
  final double scrollOffset;

  _BackgroundPainter({required this.scrollOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Animated circles
    final offset1 = scrollOffset * 0.1;
    final offset2 = scrollOffset * 0.15;

    // Circle 1
    paint.color = AppTheme.primaryIndigo.withOpacity(0.03);
    canvas.drawCircle(
      Offset(size.width * 0.2, -100 + offset1),
      150,
      paint,
    );

    // Circle 2
    paint.color = AppTheme.accentCyan.withOpacity(0.03);
    canvas.drawCircle(
      Offset(size.width * 0.8, 200 + offset2),
      200,
      paint,
    );

    // Circle 3
    paint.color = AppTheme.accentOrange.withOpacity(0.02);
    canvas.drawCircle(
      Offset(size.width * 0.5, 400 + offset1),
      180,
      paint,
    );
  }

  @override
  bool shouldRepaint(_BackgroundPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset;
  }
}
