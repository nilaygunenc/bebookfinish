import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class NewPasswordScreen extends StatefulWidget {
  final String email;
  const NewPasswordScreen({super.key, required this.email});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmVisible = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    if (password.isEmpty || password.length < 6) {
      _showSnack("Şifre en az 6 karakter olmalıdır!", AppTheme.warningAmber);
      return;
    }
    if (password != confirm) {
      _showSnack("Şifreler birbiriyle uyuşmuyor!", AppTheme.errorRed);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final result = await ApiService.resetPassword(widget.email, password);
    setState(() => _isLoading = false);

    if (result['status'] == 'success') {
      HapticFeedback.heavyImpact();
      _showSnack(
          "Şifreniz başarıyla güncellendi! Giriş yapabilirsiniz.",
          AppTheme.successGreen);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
    } else {
      _showSnack(result['message'] ?? "Bir hata oluştu", AppTheme.errorRed);
    }
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF3F0FF),
                    Color(0xFFFFF5F0),
                    Color(0xFFF5F5F7),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppTheme.shadowSM,
                        ),
                        child: const Icon(Icons.arrow_back_ios_rounded,
                            color: AppTheme.primaryIndigo, size: 20),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              gradient: AppTheme.cyanGradient,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.accentCyan.withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.lock_reset_rounded,
                                size: 56, color: Colors.white),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            "Yeni Şifre Belirle",
                            style: AppTheme.textTheme.headlineLarge
                                ?.copyWith(
                              color: AppTheme.primaryIndigo,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Güvenli bir şifre seç.\nEn az 6 karakter olmalı.",
                            textAlign: TextAlign.center,
                            style: AppTheme.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.neutralDark,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 40),

                          Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: AppTheme.shadowLG,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Yeni şifre
                                Text("Yeni Şifre",
                                    style: AppTheme.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    hintText: "En az 6 karakter",
                                    prefixIcon: const Icon(
                                        Icons.lock_outline_rounded,
                                        color: AppTheme.primaryIndigo),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: AppTheme.neutralDark,
                                      ),
                                      onPressed: () => setState(() =>
                                          _isPasswordVisible =
                                              !_isPasswordVisible),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.neutralLight,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppTheme.primaryIndigo,
                                          width: 2),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Şifre tekrar
                                Text("Şifre Tekrar",
                                    style: AppTheme.textTheme.titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _confirmController,
                                  obscureText: !_isConfirmVisible,
                                  decoration: InputDecoration(
                                    hintText: "Şifreni tekrar gir",
                                    prefixIcon: const Icon(
                                        Icons.lock_rounded,
                                        color: AppTheme.primaryIndigo),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmVisible
                                            ? Icons.visibility_rounded
                                            : Icons.visibility_off_rounded,
                                        color: AppTheme.neutralDark,
                                      ),
                                      onPressed: () => setState(() =>
                                          _isConfirmVisible =
                                              !_isConfirmVisible),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.neutralLight,
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                          color: AppTheme.primaryIndigo,
                                          width: 2),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 28),

                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _updatePassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: Ink(
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                      ),
                                      child: Container(
                                        alignment: Alignment.center,
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2.5,
                                                ),
                                              )
                                            : const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .check_circle_rounded,
                                                      color: Colors.white,
                                                      size: 20),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    "Şifreyi Güncelle",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
