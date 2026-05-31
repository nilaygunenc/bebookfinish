import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/modern_book_card.dart';
import '../../widgets/book_card.dart';
import '../../models/book_model.dart';
import '../../services/api_service.dart';
import '../post_ad/premium_add_product_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🏠 Modern Ana Sayfa - Organik ve premium tasarım
/// Standart AI şablonlarından tamamen farklı
class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => ModernHomeScreenState();
}

class ModernHomeScreenState extends State<ModernHomeScreen> 
    with SingleTickerProviderStateMixin {
  // ── Veri ──────────────────────────────────────────────────────────────
  List<Book> _allBooks = [];
  List<Book> _filteredBooks = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // ── Kullanıcı ─────────────────────────────────────────────────────────
  int? _currentUserId;
  String? _currentUserEmail;
  bool _isLoggedIn = false;
  
  // ── Öneri sistemi ─────────────────────────────────────────────────────
  List<Book> _recommendedBooks = [];
  bool _isLoadingRecommendations = false;
  
  // ── Animasyon ─────────────────────────────────────────────────────────
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _init();
    
    // FAB animasyonu
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _fabAnimationController.forward();
    
    // Scroll dinleyicisi
    _scrollController.addListener(_onScroll);
    
    // Logout dinleyicisi
    logoutNotifier.addListener(_handleLogout);
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _scrollController.dispose();
    logoutNotifier.removeListener(_handleLogout);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels > 100 && _showFab) {
      setState(() => _showFab = false);
      _fabAnimationController.reverse();
    } else if (_scrollController.position.pixels <= 100 && !_showFab) {
      setState(() => _showFab = true);
      _fabAnimationController.forward();
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
      final rawData = await ApiService.getRecommendations(_currentUserId!, topN: 5);
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
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ═══════════════════════════════════════════════════════════
          // 🎨 MODERN APP BAR - Organik ve sıcak
          // ═══════════════════════════════════════════════════════════
          _buildModernAppBar(),
          
          // ═══════════════════════════════════════════════════════════
          // 🔍 ARAMA BÖLÜMÜ - Yumuşak ve zarif
          // ═══════════════════════════════════════════════════════════
          SliverToBoxAdapter(child: _buildSearchSection()),
          
          // ═══════════════════════════════════════════════════════════
          // 🤖 ÖNERİLER - AI destekli (sadece giriş yapılmışsa)
          // ═══════════════════════════════════════════════════════════
          if (_isLoggedIn && _searchQuery.isEmpty) ...[
            SliverToBoxAdapter(child: _buildRecommendationsSection()),
          ],
          
          // ═══════════════════════════════════════════════════════════
          // 📚 TÜM KİTAPLAR - Asimetrik grid
          // ═══════════════════════════════════════════════════════════
          _buildBooksGrid(),
        ],
      ),
      
      // ═══════════════════════════════════════════════════════════════
      // ➕ FLOATING ACTION BUTTON - Animasyonlu
      // ═══════════════════════════════════════════════════════════════
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
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
          elevation: 8,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            "İlan Ver",
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // 🎨 WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildModernAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: false,
      snap: true,
      backgroundColor: AppTheme.neutralWhite,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.neutralWhite,
                AppTheme.primaryIndigo.withOpacity(0.02),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Logo ve başlık
                  Row(
                    children: [
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.shadowPrimary,
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Başlık
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bebook",
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.neutralBlack,
                              ),
                            ),
                            Text(
                              "Kitap keşfet, paylaş",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.neutralDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Bildirim butonu
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.neutralLight,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_none_rounded),
                          color: AppTheme.neutralBlack,
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
    );
  }

  Widget _buildSearchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.neutralWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: AppTheme.shadowSM,
        ),
        child: TextField(
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: "Kitap, yazar veya kategori ara...",
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppTheme.primaryIndigo,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              // AI badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  boxShadow: AppTheme.shadowPrimary,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      "Sana Özel",
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              // Yenile butonu
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: AppTheme.neutralDark,
                onPressed: _loadRecommendations,
              ),
            ],
          ),
        ),
        
        // Öneri listesi
        SizedBox(
          height: 240,
          child: _isLoadingRecommendations
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
                )
              : _recommendedBooks.isEmpty
                  ? Center(
                      child: Text(
                        "Henüz öneri oluşturulamadı",
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.neutralDark,
                        ),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _recommendedBooks.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 150,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          child: ModernBookCard(
                            book: _recommendedBooks[index],
                            isCompact: true,
                          ),
                        );
                      },
                    ),
        ),
        
        const SizedBox(height: 24),
        
        // "Tüm İlanlar" başlığı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Tüm İlanlar",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBooksGrid() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryIndigo),
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
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.neutralWhite,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.shadowMD,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: AppTheme.neutralDark,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _searchQuery.isEmpty
                    ? "Henüz kitap bulunmuyor"
                    : "Sonuç bulunamadı",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _searchQuery.isEmpty
                    ? "İlk ilanı sen ver!"
                    : "Farklı bir arama dene",
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => ModernBookCard(book: _filteredBooks[index]),
          childCount: _filteredBooks.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.62,
        ),
      ),
    );
  }
}
