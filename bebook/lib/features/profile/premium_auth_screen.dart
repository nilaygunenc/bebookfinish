import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/theme/app_theme.dart';
import '../../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'forgot_password_screen.dart';

/// 💎 Premium Auth Screen - Modern Login & Signup
class PremiumAuthScreen extends StatefulWidget {
  final bool isLogin;

  const PremiumAuthScreen({super.key, this.isLogin = true});

  @override
  State<PremiumAuthScreen> createState() => _PremiumAuthScreenState();
}

class _PremiumAuthScreenState extends State<PremiumAuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isObscure = true;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _selectedUniversity;
  String? _selectedDepartment;

  final List<String> _universities = [
    'Zonguldak Bülent Ecevit Üniversitesi',
    'İstanbul Teknik Üniversitesi',
    'Orta Doğu Teknik Üniversitesi',
    'Diğer'
  ];

  final List<String> _departments = [
    'Bilgisayar Mühendisliği',
    'Elektrik-Elektronik Mühendisliği',
    'Makine Mühendisliği',
    'İktisat',
    'İşletme',
    'Tıp',
    'Diş Hekimliği',
    'Eczacılık',
    'Psikoloji',
    'İstatistik',
    'Yönetim Bilişim Sistemleri',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final String apiUrl = "${ApiService.baseUrl}/login";

    setState(() => _isLoading = true);

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
        await prefs.setInt('user_id', data['user_id']);
        await prefs.setString('user_email', data['user_email']);
        await prefs.setString('university', data['university']);
        await prefs.setString('department', data['department']);
        await prefs.setBool('is_logged_in', true);
        // full_name kaydet
        final fullName = data['full_name']?.toString() ?? '';
        if (fullName.isNotEmpty) await prefs.setString('full_name', fullName);
        // Profil fotoğrafı varsa kaydet, boş gelirse mevcut değeri koru
        final profilePath = data['profile_image_path']?.toString() ?? '';
        if (profilePath.isNotEmpty) {
          await prefs.setString('profile_image_path', profilePath);
        }

        if (mounted) {
          HapticFeedback.mediumImpact();
          Navigator.pop(context, {
            "user_id": data['user_id'],
            "user_email": data['user_email'],
            "university": data['university'],
            "department": data['department'],
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
    bool success = await ApiService.signup(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
      university: _selectedUniversity ?? "",
      department: _selectedDepartment ?? "",
    );

    if (success) {
      HapticFeedback.mediumImpact();
      _showSnackBar("Başarıyla üye oldun! Giriş yapabilirsin.", AppTheme.successGreen);
      setState(() {
        _isLogin = true;
        _controller.reset();
        _controller.forward();
      });
    } else {
      _showSnackBar(
        "Kayıt başarısız. Bu e-posta zaten kullanımda olabilir.",
        AppTheme.errorRed,
      );
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
      body: Stack(
        children: [
          // Animated Background
          _buildAnimatedBackground(),

          // Content
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
                        const SizedBox(height: 40),
                        _buildHeader(),
                        const SizedBox(height: 40),
                        _buildForm(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
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
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
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
              AppTheme.primaryIndigo.withOpacity(0.1),
              AppTheme.accentCyan.withOpacity(0.1),
              AppTheme.accentOrange.withOpacity(0.05),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryIndigo.withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Icon(
            _isLogin ? Icons.lock_person_rounded : Icons.person_add_rounded,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
          child: Text(
            _isLogin ? "Hoş Geldin!" : "Aramıza Katıl",
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? "Hesabına giriş yap ve kitap dünyasına devam et"
              : "Yeni bir hesap oluştur ve keşfetmeye başla",
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppTheme.neutralDark,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Email
            _buildTextField(
              "E-posta",
              Icons.email_rounded,
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),

            // Password
            _buildTextField(
              "Şifre",
              Icons.lock_rounded,
              controller: _passwordController,
              isPassword: true,
            ),

            // Forgot Password (Login only)
            if (_isLogin) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
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
                      color: AppTheme.primaryIndigo,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],

            // University & Department (Signup only)
            if (!_isLogin) ...[
              const SizedBox(height: 16),
              _buildDropdown(
                "Üniversite",
                Icons.school_rounded,
                _universities,
                _selectedUniversity,
                (val) => setState(() => _selectedUniversity = val),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                "Bölüm",
                Icons.computer_rounded,
                _departments,
                _selectedDepartment,
                (val) => setState(() => _selectedDepartment = val),
              ),
            ],

            const SizedBox(height: 32),

            // Submit Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentOrange.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            HapticFeedback.mediumImpact();
                            if (_isLogin) {
                              _handleLogin();
                            } else {
                              _handleSignup();
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Text(
                          _isLogin ? "Giriş Yap" : "Üye Ol",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Toggle Login/Signup
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? "Hesabın yok mu?" : "Zaten hesabın var mı?",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isLogin = !_isLogin;
                      _controller.reset();
                      _controller.forward();
                    });
                  },
                  child: Text(
                    _isLogin ? "Üye Ol" : "Giriş Yap",
                    style: TextStyle(
                      color: AppTheme.primaryIndigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon, {
    required TextEditingController controller,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && _isObscure,
      keyboardType: keyboardType,
      validator: (v) => (v == null || v.isEmpty) ? "Bu alan gereklidir" : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryIndigo),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppTheme.neutralLight,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    IconData icon,
    List<String> items,
    String? value,
    Function(String?) onChanged,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryIndigo),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: AppTheme.neutralLight,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
      ),
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => (v == null) ? "Lütfen seçim yapın" : null,
      isExpanded: true,
    );
  }
}
