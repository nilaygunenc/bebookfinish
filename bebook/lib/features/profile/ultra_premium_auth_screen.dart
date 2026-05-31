import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_screen.dart';

/// 💎 Ultra Premium Auth Screen - Next Level Design
class UltraPremiumAuthScreen extends StatefulWidget {
  final bool isLogin;

  const UltraPremiumAuthScreen({super.key, this.isLogin = true});

  @override
  State<UltraPremiumAuthScreen> createState() => _UltraPremiumAuthScreenState();
}

class _UltraPremiumAuthScreenState extends State<UltraPremiumAuthScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isObscure = true;
  bool _isLoading = false;

  late AnimationController _mainController;
  late AnimationController _backgroundController;
  late AnimationController _formController;
  
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _backgroundAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  String? _selectedUniversity;
  String? _selectedDepartment;

  // Şifre gücü
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.transparent;

  // Şifre gücü hesaplama
  void _checkPasswordStrength(String password) {
    double strength = 0;
    String label = '';
    Color color = Colors.transparent;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0;
        _passwordStrengthLabel = '';
        _passwordStrengthColor = Colors.transparent;
      });
      return;
    }

    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))) strength += 0.25;

    if (strength <= 0.25) {
      label = 'Çok Zayıf';
      color = const Color(0xFFE53935);
    } else if (strength <= 0.50) {
      label = 'Zayıf';
      color = const Color(0xFFFF7043);
    } else if (strength <= 0.75) {
      label = 'Orta';
      color = const Color(0xFFFFB300);
    } else {
      label = 'Güçlü ✓';
      color = const Color(0xFF43A047);
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
      _passwordStrengthColor = color;
    });
  }

  // Şifre güçlü mü?
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Bu alan gereklidir';
    if (value.length < 8) return 'En az 8 karakter olmalı';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'En az 1 büyük harf içermeli';
    if (!value.contains(RegExp(r'[0-9]'))) return 'En az 1 rakam içermeli';
    if (!value.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))) {
      return 'En az 1 özel karakter içermeli (!@#\$%^&* vb.)';
    }
    return null;
  }

  final List<String> _universities = [
    'Zonguldak Bülent Ecevit Üniversitesi',
    'İstanbul Teknik Üniversitesi',
    'Orta Doğu Teknik Üniversitesi',
    'Boğaziçi Üniversitesi',
    'Hacettepe Üniversitesi',
    'Bilkent Üniversitesi',
    'Koç Üniversitesi',
    'Sabancı Üniversitesi',
    'Diğer'
  ];

  final List<String> _departments = [
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
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;

    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Background animation controller
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    // Form animation controller
    _formController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _mainController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _formController,
      curve: Curves.elasticOut,
    ));

    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_backgroundController);

    _mainController.forward();
    _formController.forward();
    _backgroundController.repeat();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _backgroundController.dispose();
    _formController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final String apiUrl = "${ApiService.baseUrl}/login";

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', data['user_id'] ?? 0);
        await prefs.setString('user_email', data['user_email'] ?? '');
        await prefs.setString('university', data['university'] ?? '');
        await prefs.setString('department', data['department'] ?? '');
        await prefs.setBool('is_logged_in', true);
        // full_name kaydet
        final fullName = data['full_name']?.toString() ?? '';
        if (fullName.isNotEmpty) {
          await prefs.setString('full_name', fullName);
        }
        // Profil fotoğrafı varsa kaydet
        final profilePath = data['profile_image_path']?.toString() ?? '';
        debugPrint("LOGIN - profile_image_path: $profilePath");
        if (profilePath.isNotEmpty) {
          await prefs.setString('profile_image_path', profilePath);
        }
        // Boş gelirse mevcut değeri koru (silme)

        if (mounted) {
          HapticFeedback.heavyImpact();
          _showSnackBar("Hoş geldin! 🎉", AppTheme.successGreen);
          
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pop(context, {
            "user_id": data['user_id'] ?? 0,
            "user_email": data['user_email'] ?? '',
            "university": data['university'] ?? '',
            "department": data['department'] ?? '',
            "profile_image_path": profilePath,
            "full_name": data['full_name'] ?? '',
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        _showSnackBar(
          errorData['detail'] ?? "E-posta veya şifre hatalı!",
          AppTheme.errorRed,
        );
      }
    } catch (e) {
      _showSnackBar("Bağlantı hatası: Sunucuya erişilemiyor.", AppTheme.errorRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    // Form validasyonu (şifre gücü dahil)
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    bool success = await ApiService.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      university: _selectedUniversity ?? "",
      department: _selectedDepartment ?? "",
      fullName: _fullNameController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (success) {
      HapticFeedback.heavyImpact();
      _showSnackBar("Başarıyla üye oldun! 🎉", AppTheme.successGreen);
      
      await Future.delayed(const Duration(milliseconds: 500));

      // Kayıt bilgilerini sakla
      final registeredEmail = _emailController.text.trim();
      final registeredPassword = _passwordController.text.trim();
      final registeredFullName = _fullNameController.text.trim();

      setState(() {
        _isLogin = true;
        _selectedUniversity = null;
        _selectedDepartment = null;
        _passwordStrength = 0;
        _passwordStrengthLabel = '';
        _passwordStrengthColor = Colors.transparent;
        _formController.reset();
        _formController.forward();
      });

      // Giriş formuna email ve şifreyi otomatik doldur
      _emailController.text = registeredEmail;
      _passwordController.text = registeredPassword;
      
      // full_name'i hemen SharedPreferences'a kaydet
      if (registeredFullName.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('full_name', registeredFullName);
      }
      
      // Otomatik giriş yap
      await _handleLogin();
    } else {
      _showSnackBar(
        "Kayıt başarısız. Bu e-posta zaten kullanımda olabilir.",
        AppTheme.errorRed,
      );
    }
  }

  void _toggleMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isLogin = !_isLogin;
      _formController.reset();
      _formController.forward();
    });
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppTheme.successGreen ? Icons.check_circle : Icons.error,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralBlack,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ultra Dynamic Background
          _buildUltraDynamicBackground(),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        _buildUltraHeader(),
                        const SizedBox(height: 60),
                        _buildUltraForm(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Premium Back Button
          _buildPremiumBackButton(),
        ],
      ),
    );
  }

  Widget _buildUltraDynamicBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryIndigo.withOpacity(0.9),
                AppTheme.primaryIndigoLight.withOpacity(0.8),
                AppTheme.accentCyan.withOpacity(0.7),
                AppTheme.accentOrange.withOpacity(0.6),
                AppTheme.accentPink.withOpacity(0.8),
              ],
              stops: [
                0.0,
                0.25 + (_backgroundAnimation.value * 0.1),
                0.5 + (_backgroundAnimation.value * 0.15),
                0.75 + (_backgroundAnimation.value * 0.1),
                1.0,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Premium floating elements - more sophisticated
              ...List.generate(8, (index) {
                final offset = _backgroundAnimation.value * 2 * 3.14159;
                final size = 15.0 + (index * 8);
                final opacity = 0.05 + (index % 3) * 0.03;
                
                return Positioned(
                  left: 30 + (index * 80) + (50 * (index % 2 == 0 ? 1 : -1) * _backgroundAnimation.value),
                  top: 80 + (index * 90) + (60 * (index % 2 == 0 ? 1 : -1) * _backgroundAnimation.value),
                  child: Transform.rotate(
                    angle: offset + (index * 0.8),
                    child: Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(size * 0.3),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(opacity),
                            Colors.white.withOpacity(opacity * 0.5),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 15,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              
              // Premium mesh gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topRight,
                    radius: 1.5,
                    colors: [
                      Colors.white.withOpacity(0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              
              // Bottom mesh gradient
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.bottomLeft,
                    radius: 1.2,
                    colors: [
                      AppTheme.accentOrange.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumBackButton() {
    return Positioned(
      top: 50,
      left: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUltraHeader() {
    return Column(
      children: [
        // Premium Animated Logo with glassmorphism
        ScaleTransition(
          scale: _scaleAnimation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.25),
                      Colors.white.withOpacity(0.1),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withOpacity(0.3),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.white,
                      AppTheme.accentOrange.withOpacity(0.8),
                      AppTheme.accentPink.withOpacity(0.8),
                    ],
                  ).createShader(bounds),
                  child: Icon(
                    _isLogin ? Icons.lock_person_rounded : Icons.person_add_alt_1_rounded,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        
        // Premium Animated Title with gradient text
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.9),
              AppTheme.accentOrange.withOpacity(0.8),
            ],
          ).createShader(bounds),
          child: Text(
            _isLogin ? "Tekrar Hoş Geldin!" : "Aramıza Katıl!",
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 16),
        
        // Premium subtitle with better typography
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _isLogin
                ? "Hesabına giriş yap ve kitap dünyasına devam et"
                : "Yeni bir hesap oluştur ve keşfetmeye başla",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.white.withOpacity(0.85),
              height: 1.6,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildUltraForm() {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.12),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: AppTheme.primaryIndigo.withOpacity(0.2),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Field
                    _buildUltraTextField(
                      "E-posta Adresin",
                      Icons.alternate_email_rounded,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),

                    // Password Field
                    _buildUltraTextField(
                      "Şifren",
                      Icons.lock_outline_rounded,
                      controller: _passwordController,
                      isPassword: true,
                    ),

                    // Şifre gücü göstergesi (sadece kayıt ekranında)
                    if (!_isLogin && _passwordStrength > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Şifre Gücü',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _passwordStrengthLabel,
                                  style: TextStyle(
                                    color: _passwordStrengthColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _passwordStrength,
                                minHeight: 6,
                                backgroundColor: Colors.white.withOpacity(0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
                              ),
                            ),
                            if (_passwordStrength < 1.0) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _buildPasswordHint('8+ karakter', _passwordController.text.length >= 8),
                                  _buildPasswordHint('Büyük harf', _passwordController.text.contains(RegExp(r'[A-Z]'))),
                                  _buildPasswordHint('Rakam', _passwordController.text.contains(RegExp(r'[0-9]'))),
                                  _buildPasswordHint('Özel karakter', _passwordController.text.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-]'))),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // Forgot Password (Login only)
                    if (_isLogin) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withOpacity(0.1),
                          ),
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: Text(
                              "Şifremi Unuttum",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // University & Department (Signup only)
                    if (!_isLogin) ...[
                      const SizedBox(height: 24),
                      _buildUltraTextField(
                        "Ad Soyad",
                        Icons.person_rounded,
                        controller: _fullNameController,
                        validator: (v) => (v == null || v.isEmpty) ? "Ad soyad gereklidir" : null,
                      ),
                      const SizedBox(height: 24),
                      _buildUltraDropdown(
                        "Üniversiten",
                        Icons.school_rounded,
                        _universities,
                        _selectedUniversity,
                        (val) => setState(() => _selectedUniversity = val),
                      ),
                      const SizedBox(height: 24),
                      _buildUltraDropdown(
                        "Bölümün",
                        Icons.auto_stories_rounded,
                        _departments,
                        _selectedDepartment,
                        (val) => setState(() => _selectedDepartment = val),
                      ),
                    ],

                    const SizedBox(height: 40),

                    // Submit Button
                    _buildUltraSubmitButton(),

                    const SizedBox(height: 32),

                    // Toggle Mode
                    _buildToggleMode(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUltraTextField(
    String label,
    IconData icon, {
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.08),
          ],
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword && _isObscure,
        keyboardType: keyboardType,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        onChanged: isPassword && !_isLogin
            ? (value) => _checkPasswordStrength(value)
            : null,
        validator: isPassword && !_isLogin
            ? _validatePassword
            : (v) => (v == null || v.isEmpty) ? "Bu alan gereklidir" : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentOrange.withOpacity(0.3),
                  AppTheme.accentPink.withOpacity(0.3),
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white.withOpacity(0.9),
              size: 20,
            ),
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: Icon(
                      _isObscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _isObscure = !_isObscure);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
          ),
          errorStyle: const TextStyle(
            color: Color(0xFFFF7043),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          filled: false,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        ),
      ),
    );
  }

  Widget _buildPasswordHint(String text, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: met
            ? const Color(0xFF43A047).withOpacity(0.25)
            : Colors.white.withOpacity(0.1),
        border: Border.all(
          color: met
              ? const Color(0xFF43A047).withOpacity(0.6)
              : Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 12,
            color: met ? const Color(0xFF43A047) : Colors.white.withOpacity(0.5),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: met ? const Color(0xFF43A047) : Colors.white.withOpacity(0.6),
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUltraDropdown(
    String label,
    IconData icon,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    // Text field ile birebir aynı dış container stili
    final boxDecoration = BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.15),
          Colors.white.withOpacity(0.08),
        ],
      ),
      border: Border.all(
        color: Colors.white.withOpacity(0.3),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );

    // Text field ile birebir aynı InputDecoration stili
    final inputDecoration = InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.white.withOpacity(0.8),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFF7043),
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.accentOrange.withOpacity(0.3),
              AppTheme.accentPink.withOpacity(0.3),
            ],
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white.withOpacity(0.9),
          size: 20,
        ),
      ),
      filled: false,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
    );

    return Container(
      decoration: boxDecoration,
      child: DropdownButtonFormField<String>(
        value: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: const Color(0xFF2D2B6B),
        menuMaxHeight: 300,
        decoration: inputDecoration,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (v) => (v == null) ? "Lütfen seçim yapın" : null,
        isExpanded: true,
        icon: Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.1),
          ),
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.8),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildUltraSubmitButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accentOrange,
            AppTheme.accentPink,
            AppTheme.accentCyan.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentOrange.withOpacity(0.4),
            blurRadius: 25,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppTheme.accentPink.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : () {
                HapticFeedback.mediumImpact();
                if (_formKey.currentState!.validate()) {
                  if (_isLogin) {
                    _handleLogin();
                  } else {
                    _handleSignup();
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: _isLoading
            ? Container(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: Icon(
                      _isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isLogin ? "Giriş Yap" : "Üye Ol",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildToggleMode() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              _isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?",
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 6),
          TextButton(
            onPressed: _toggleMode,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: AppTheme.accentOrange.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _isLogin ? "Üye Ol" : "Giriş Yap",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}