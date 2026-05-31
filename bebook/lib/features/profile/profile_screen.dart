import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'ultra_premium_auth_screen.dart';
import 'contact_support_screen.dart';
import 'about_bebook_screen.dart';
import 'premium_favorites_screen.dart';
import '../../widgets/premium_book_card.dart';
import '../../services/api_service.dart';
import '../../models/book_model.dart';
import '../../core/theme/app_theme.dart';
import '../../features/main_wrapper.dart'; // logoutNotifier için
import 'sold_books_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  List<Book> myBooks = [];
  bool isLoading = false;
  bool isLoggedIn = false;

  String? userEmail;
  String? userUniversity;
  String? userDepartment;
  String? userFullName;
  int? userId;
  String? profileImagePath; // Profil fotoğrafı yolu

  final String baseUrl = "${ApiService.baseUrl}/uploads/";

  /// Backend'den gelen path'i tam URL'e çevirir
  /// "uploads/profiles/x.png" → "http://host:8001/uploads/profiles/x.png"
  /// "/uploads/profiles/x.png" → "http://host:8001/uploads/profiles/x.png"
  /// "http://..." → olduğu gibi
  String _buildImageUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final clean = path.startsWith('/') ? path.substring(1) : path;
    return '${ApiService.baseUrl}/$clean';
  }

  // Animation controllers for premium effects
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_backgroundController);
    
    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );
    
    // Start animations
    _backgroundController.repeat();
    _cardController.forward();
    
    _checkLoginStatus(); // ✅ Sayfa açılınca giriş durumunu kontrol et
    if (isLoggedIn && userId != null) {
      fetchMyBooks();
    }
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  // ✅ YENİ: Giriş durumunu kontrol et
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool('is_logged_in') ?? false;
    final id = prefs.getInt('user_id');
    
    if (loggedIn && id != null) {
      setState(() {
        isLoggedIn = true;
        userId = id;
        userEmail = prefs.getString('user_email');
        userUniversity = prefs.getString('university');
        userDepartment = prefs.getString('department');
        userFullName = prefs.getString('full_name');
        // SharedPreferences'tan oku
        profileImagePath = prefs.getString('profile_image_path');
      });

      // Her zaman backend'den güncel profil fotoğrafını çek
      _fetchProfileImageFromBackend(id, prefs);
      fetchMyBooks();
    }
  }

  Future<void> _fetchProfileImageFromBackend(int id, SharedPreferences prefs) async {
    try {
      final response = await http.get(
        Uri.parse("${ApiService.baseUrl}/user/profile/$id"),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final path = data['profile_image_path']?.toString() ?? '';
        final fullName = data['full_name']?.toString() ?? '';
        debugPrint("Backend'den gelen profil path: $path");
        if (path.isNotEmpty && mounted) {
          await prefs.setString('profile_image_path', path);
          setState(() => profileImagePath = path);
        }
        if (fullName.isNotEmpty && mounted) {
          await prefs.setString('full_name', fullName);
          setState(() => userFullName = fullName);
        }
      }
    } catch (e) {
      debugPrint("Profil fotoğrafı çekme hatası: $e");
    }
  }

  Future<void> fetchMyBooks() async {
    if (userId == null) return;
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getMyBooks(userId!);

      setState(() {
        myBooks = data.map<Book>((b) {
          return Book.fromJson(b);
        }).toList();
      });
    } catch (e) {
      debugPrint("Profil Kitapları Yükleme Hatası: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Profil bilgilerini düzenle
  Future<void> _showEditProfileDialog() async {
    HapticFeedback.lightImpact();

    final List<String> universities = [
      'Zonguldak Bülent Ecevit Üniversitesi',
      'İstanbul Teknik Üniversitesi',
      'Orta Doğu Teknik Üniversitesi',
      'Boğaziçi Üniversitesi',
      'Hacettepe Üniversitesi',
      'Bilkent Üniversitesi',
      'Koç Üniversitesi',
      'Sabancı Üniversitesi',
      'Diğer',
    ];
    final List<String> departments = [
      'Bilgisayar Mühendisliği',
      'Elektrik-Elektronik Mühendisliği',
      'Makine Mühendisliği',
      'Endüstri Mühendisliği',
      'İktisat',
      'İşletme',
      'Tıp',
      'Diş Hekimliği',
      'Eczacılık',
      'Psikoloji',
      'İstatistik',
      'Matematik',
      'Fizik',
      'Kimya',
      'Yönetim Bilişim Sistemleri',
      'Diğer',
    ];

    String? selectedUniversity = universities.contains(userUniversity)
        ? userUniversity
        : null;
    String? selectedDepartment = departments.contains(userDepartment)
        ? userDepartment
        : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text("Bilgileri Düzenle",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Üniversite
                DropdownButtonFormField<String>(
                  value: selectedUniversity,
                  decoration: InputDecoration(
                    labelText: "Üniversite",
                    prefixIcon: const Icon(Icons.school_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryIndigo, width: 2),
                    ),
                  ),
                  items: universities
                      .map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedUniversity = v),
                  isExpanded: true,
                ),
                const SizedBox(height: 16),
                // Bölüm
                DropdownButtonFormField<String>(
                  value: selectedDepartment,
                  decoration: InputDecoration(
                    labelText: "Bölüm",
                    prefixIcon: const Icon(Icons.auto_stories_rounded),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryIndigo, width: 2),
                    ),
                  ),
                  items: departments
                      .map((d) => DropdownMenuItem(value: d, child: Text(d, overflow: TextOverflow.ellipsis)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => selectedDepartment = v),
                  isExpanded: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("İptal",
                  style: TextStyle(color: AppTheme.neutralDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryIndigo,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await _updateUserInfo(
                    selectedUniversity, selectedDepartment);
              },
              child: const Text("Kaydet",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateUserInfo(
      String? university, String? department) async {
    if (userId == null) return;
    try {
      final response = await http.put(
        Uri.parse("${ApiService.baseUrl}/user/update-info"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "university": university,
          "department": department,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          // SharedPreferences güncelle
          final prefs = await SharedPreferences.getInstance();
          if (university != null) {
            await prefs.setString('university', university);
          }
          if (department != null) {
            await prefs.setString('department', department);
          }
          if (mounted) {
            setState(() {
              userUniversity = university;
              userDepartment = department;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Text("Bilgiler güncellendi!"),
                  ],
                ),
                backgroundColor: AppTheme.successGreen,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Profil güncelleme hatası: $e");
    }
  }

  // Profil fotoğrafı seç ve yükle
  Future<void> _pickAndUploadProfilePhoto() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();

    // Seçenek sun: galeri veya kamera
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Profil Fotoğrafı",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: AppTheme.primaryIndigo),
                ),
                title: const Text("Galeriden Seç"),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: AppTheme.accentOrange),
                ),
                title: const Text("Kamerayı Aç"),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final XFile? picked = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 800,
      );
      if (picked == null) return;

      // Yükleniyor göster
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 12),
                Text("Fotoğraf yükleniyor..."),
              ],
            ),
            duration: Duration(seconds: 10),
            backgroundColor: Colors.blueGrey,
          ),
        );
      }

      final imagePath = await ApiService.uploadProfilePhotoXFile(userId!, picked);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (imagePath != null) {
        // Backend'den gelen gerçek path'i kaydet
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', imagePath);

        if (mounted) {
          setState(() => profileImagePath = imagePath);
        }

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text("Profil fotoğrafı güncellendi!"),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Fotoğraf yüklenemedi, tekrar dene."),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint("Fotoğraf yükleme hatası: $e");
    }
  }
  Widget build(BuildContext context) {
    if (isLoggedIn && myBooks.isEmpty && !isLoading && userId != null) {
      fetchMyBooks();
    }

    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Premium animated background
          _buildPremiumBackground(),
          
          // Main content
          SafeArea(
            child: isLoggedIn
                ? _buildPremiumProfileDashboard()
                : _buildPremiumAuthUI(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🎨 PREMIUM UI COMPONENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPremiumBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryIndigo.withOpacity(0.1),
                AppTheme.accentCyan.withOpacity(0.05),
                AppTheme.accentOrange.withOpacity(0.03),
                AppTheme.neutralLight,
              ],
              stops: [
                0.0,
                0.3 + (_backgroundAnimation.value * 0.1),
                0.7 + (_backgroundAnimation.value * 0.1),
                1.0,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Floating premium elements
              ...List.generate(6, (index) {
                final offset = _backgroundAnimation.value * 2 * 3.14159;
                return Positioned(
                  left: 50 + (index * 100) + (30 * (index % 2 == 0 ? 1 : -1) * _backgroundAnimation.value),
                  top: 100 + (index * 120) + (40 * (index % 2 == 0 ? 1 : -1) * _backgroundAnimation.value),
                  child: Transform.rotate(
                    angle: offset + (index * 0.5),
                    child: Container(
                      width: 20 + (index * 3),
                      height: 20 + (index * 3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryIndigo.withOpacity(0.1),
                            AppTheme.accentOrange.withOpacity(0.05),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumAuthUI() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Premium header with glassmorphism
            _buildPremiumHeader(),
            
            const SizedBox(height: 60),
            
            // Premium welcome card
            FadeTransition(
              opacity: _cardAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(_cardAnimation),
                child: _buildPremiumWelcomeCard(),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.2),
                  Colors.white.withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Profil",
                  style: AppTheme.textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildPremiumHeaderButton(
                      Icons.info_outline_rounded,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutBebookScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPremiumHeaderButton(
                      Icons.support_agent_rounded,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactSupportScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumHeaderButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryIndigo.withOpacity(0.2),
            AppTheme.accentOrange.withOpacity(0.1),
          ],
        ),
      ),
      child: IconButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        icon: Icon(
          icon,
          color: AppTheme.primaryIndigo,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildPremiumWelcomeCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowXL,
            ),
            child: Column(
              children: [
                // Premium icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.shadowPrimary,
                  ),
                  child: Icon(
                    Icons.account_circle_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  "Bebook'a Hoş Geldin",
                  style: AppTheme.textTheme.headlineLarge?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  "Profilini yönetmek ve ilanlarını görmek için giriş yapmalısın.",
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.neutralDark,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 40),
                
                // Premium login button
                _buildPremiumAuthButton(
                  "Giriş Yap",
                  Icons.login_rounded,
                  AppTheme.primaryGradient,
                  () async {
                    HapticFeedback.mediumImpact();
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UltraPremiumAuthScreen(isLogin: true),
                      ),
                    );

                    if (result != null && result is Map) {
                      final prefs = await SharedPreferences.getInstance();
                      final imgPath = result['profile_image_path']?.toString() ?? '';
                      if (imgPath.isNotEmpty) {
                        await prefs.setString('profile_image_path', imgPath);
                      }
                      final fullName = result['full_name']?.toString() ?? '';
                      if (fullName.isNotEmpty) {
                        await prefs.setString('full_name', fullName);
                      }
                      setState(() {
                        isLoggedIn = true;
                        userEmail = result['user_email'];
                        userUniversity = result['university'];
                        userDepartment = result['department'];
                        userId = result['user_id'];
                        userFullName = fullName.isNotEmpty ? fullName : null;
                        if (imgPath.isNotEmpty) profileImagePath = imgPath;
                      });
                      fetchMyBooks();
                    }                  },
                ),
                
                const SizedBox(height: 16),
                
                // Premium signup button
                _buildPremiumAuthButton(
                  "Üye Ol",
                  Icons.person_add_rounded,
                  AppTheme.accentGradient,
                  () {
                    HapticFeedback.mediumImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UltraPremiumAuthScreen(isLogin: false),
                      ),
                    );
                  },
                  isOutlined: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumAuthButton(
    String text,
    IconData icon,
    LinearGradient gradient,
    VoidCallback onPressed, {
    bool isOutlined = false,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isOutlined ? null : gradient,
        border: isOutlined
            ? Border.all(
                color: AppTheme.accentOrange,
                width: 2,
              )
            : null,
        boxShadow: isOutlined ? null : AppTheme.shadowMD,
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.transparent : Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isOutlined ? AppTheme.accentOrange : Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: AppTheme.textTheme.titleLarge?.copyWith(
                color: isOutlined ? AppTheme.accentOrange : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumProfileDashboard() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Premium header
            _buildPremiumHeader(),
            
            const SizedBox(height: 32),
            
            // Premium user info card
            FadeTransition(
              opacity: _cardAnimation,
              child: _buildPremiumUserCard(),
            ),
            
            const SizedBox(height: 32),
            
            // Premium menu items
            ..._buildPremiumMenuItems(),
            
            const SizedBox(height: 32),
            
            // Premium logout button
            _buildPremiumLogoutButton(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumUserCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.9),
                  Colors.white.withOpacity(0.7),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowXL,
            ),
            child: Row(
              children: [
                // Tıklanabilir profil fotoğrafı avatarı
                GestureDetector(
                  onTap: _pickAndUploadProfilePhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: AppTheme.shadowPrimary,
                        ),
                        child: ClipOval(
                          child: profileImagePath != null && profileImagePath!.isNotEmpty
                              ? Image.network(
                                  _buildImageUrl(profileImagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      (userEmail != null && userEmail!.isNotEmpty)
                                          ? userEmail![0].toUpperCase()
                                          : "?",
                                      style: AppTheme.textTheme.displaySmall?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    (userEmail != null && userEmail!.isNotEmpty)
                                        ? userEmail![0].toUpperCase()
                                        : "?",
                                    style: AppTheme.textTheme.displaySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Kamera ikonu — fotoğraf ekle/değiştir
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentOrange,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 24),
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userFullName != null && userFullName!.isNotEmpty
                                  ? userFullName!
                                  : userEmail ?? "Kullanıcı",
                              style: AppTheme.textTheme.titleLarge?.copyWith(
                                color: AppTheme.primaryIndigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Düzenleme butonu
                          GestureDetector(
                            onTap: _showEditProfileDialog,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryIndigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.edit_rounded,
                                  size: 16, color: AppTheme.primaryIndigo),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.accentCyan.withOpacity(0.2),
                              AppTheme.accentOrange.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Text(
                          userUniversity ?? "Zonguldak Bülent Ecevit Üniversitesi",
                          style: AppTheme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.neutralDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPremiumMenuItems() {
    final menuItems = [
      {
        'icon': Icons.favorite_border_rounded,
        'title': 'Favorilediğim Kitaplar',
        'subtitle': 'Beğendiğin kitapları görüntüle',
        'gradient': AppTheme.accentGradient,
        'onTap': () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PremiumFavoritesScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.sell_outlined,
        'title': 'Satışa Sunduğum Kitaplar',
        'subtitle': 'İlanlarını yönet ve düzenle',
        'gradient': AppTheme.cyanGradient,
        'onTap': () {
          HapticFeedback.lightImpact();
          _showPremiumMyBooksSheet();
        },
      },
      {
        'icon': Icons.assignment_turned_in_outlined,
        'title': 'Satış Geçmişim',
        'subtitle': 'Satış geçmişini görüntüle',
        'gradient': AppTheme.sunsetGradient,
        'onTap': () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SoldBooksScreen(),
            ),
          );
        },
      },
    ];

    return menuItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0.3, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _cardController,
            curve: Interval(
              index * 0.1,
              0.6 + (index * 0.1),
              curve: Curves.easeOutCubic,
            ),
          )),
          child: _buildPremiumMenuItem(
            item['icon'] as IconData,
            item['title'] as String,
            item['subtitle'] as String,
            item['gradient'] as LinearGradient,
            item['onTap'] as VoidCallback,
          ),
        ),
      );
    }).toList();
  }

  Widget _buildPremiumMenuItem(
    IconData icon,
    String title,
    String subtitle,
    LinearGradient gradient,
    VoidCallback onTap,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.8),
                  Colors.white.withOpacity(0.6),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowMD,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      // Premium icon container
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: gradient,
                          boxShadow: [
                            BoxShadow(
                              color: gradient.colors.first.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      
                      const SizedBox(width: 20),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTheme.textTheme.titleLarge?.copyWith(
                                color: AppTheme.primaryIndigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: AppTheme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.neutralDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Arrow icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppTheme.primaryIndigo.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: AppTheme.primaryIndigo,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumLogoutButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppTheme.errorRed.withOpacity(0.1),
                  AppTheme.errorRed.withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: AppTheme.errorRed.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  
                  // Show confirmation dialog
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    builder: (context) => _buildPremiumLogoutDialog(),
                  );
                  
                  if (shouldLogout == true) {
                    await _performLogout();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.exit_to_app_rounded,
                        color: AppTheme.errorRed,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Çıkış Yap",
                        style: AppTheme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // 🎯 HELPER METHODS
  // ═══════════════════════════════════════════════════════════════

  void _showPremiumMyBooksSheet() {
    // Sayfa açılırken veriler boşsa tekrar çekelim
    if (myBooks.isEmpty && !isLoading) {
      fetchMyBooks();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.95),
                    AppTheme.neutralLight.withOpacity(0.95),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Handle bar
                  Container(
                    width: 50,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.neutralDark.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: AppTheme.cyanGradient,
                          ),
                          child: const Icon(
                            Icons.sell_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "İlanlarım",
                          style: AppTheme.textTheme.headlineMedium?.copyWith(
                            color: AppTheme.primaryIndigo,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryIndigo,
                            ),
                          )
                        : myBooks.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 80,
                                      color: AppTheme.neutralDark.withOpacity(0.3),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      "Henüz bir ilanınız bulunmuyor.",
                                      style: AppTheme.textTheme.bodyLarge?.copyWith(
                                        color: AppTheme.neutralDark,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(20),
                                physics: const BouncingScrollPhysics(),
                                itemCount: myBooks.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: PremiumBookCard(
                                    book: myBooks[index],
                                    isMyPost: true,
                                    onUpdated: () {
                                      fetchMyBooks();
                                      Navigator.pop(context);
                                    },
                                  ),
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

  Widget _buildPremiumLogoutDialog() {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.85),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowXL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.errorRed.withOpacity(0.2),
                        AppTheme.errorRed.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 48,
                    color: AppTheme.errorRed,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  "Çıkış Yapmak İstediğine Emin Misin?",
                  style: AppTheme.textTheme.headlineSmall?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  "Tüm oturum bilgilerin temizlenecek.",
                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutralDark,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 32),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.neutralDark.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context, false);
                          },
                          child: Text(
                            "İptal",
                            style: AppTheme.textTheme.titleMedium?.copyWith(
                              color: AppTheme.neutralDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.errorRed,
                              AppTheme.errorRed.withOpacity(0.8),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.errorRed.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context, true);
                          },
                          child: Text(
                            "Çıkış Yap",
                            style: AppTheme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _performLogout() async {
    HapticFeedback.heavyImpact();
    
    // 1. SharedPreferences'ı temizle
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('university');
    await prefs.remove('department');
    await prefs.remove('full_name');
    // profile_image_path'i silmiyoruz — tekrar giriş yapınca backend'den gelecek
    await prefs.setBool('is_logged_in', false);
    
    // 2. Global logout bildirimi gönder — MainWrapper'ın _loadUser çağırmasını sağlar
    logoutNotifier.value = true;
    
    // 3. Kısa bir gecikme sonra notifier'ı sıfırla
    await Future.delayed(const Duration(milliseconds: 200));
    logoutNotifier.value = false;
    
    // 4. Local state'i temizle
    if (mounted) {
      setState(() {
        isLoggedIn = false;
        userEmail = null;
        userId = null;
        userFullName = null;
        profileImagePath = null;
        myBooks = [];
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text("Çıkış yapıldı. Tüm veriler temizlendi."),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

}