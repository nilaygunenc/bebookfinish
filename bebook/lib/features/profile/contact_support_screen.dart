import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bebook/services/api_service.dart';
import '../../core/theme/app_theme.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardAnimation;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
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
    
    _backgroundController.repeat();
    _cardController.forward();
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    _cardController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.neutralLight,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Premium animated background
          _buildPremiumBackground(),
          
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Premium header
                    _buildPremiumHeader(),
                    
                    const SizedBox(height: 40),
                    
                    // Premium contact form
                    FadeTransition(
                      opacity: _cardAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(_cardAnimation),
                        child: _buildPremiumContactForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  icon: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: AppTheme.primaryIndigo,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Bizimle İletişime Geç",
                  style: AppTheme.textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumContactForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
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
            child: Form(
              key: _formKey,
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
                      Icons.support_agent_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  Text(
                    "Size Nasıl Yardımcı Olabiliriz?",
                    style: AppTheme.textTheme.headlineMedium?.copyWith(
                      color: AppTheme.primaryIndigo,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Text(
                    "Sorularınız, önerileriniz veya sorunlarınız için bizimle iletişime geçin.",
                    style: AppTheme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.neutralDark,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Form fields
                  _buildPremiumField(
                    "Adınız Soyadınız",
                    _nameController,
                    Icons.person_outline_rounded,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildPremiumField(
                    "E-posta Adresiniz",
                    _emailController,
                    Icons.email_outlined,
                    isEmail: true,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _buildPremiumField(
                    "Mesajınız",
                    _messageController,
                    Icons.message_outlined,
                    isLong: true,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Premium submit button
                  _buildPremiumSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumField(
    String hint,
    TextEditingController controller,
    IconData icon, {
    bool isEmail = false,
    bool isLong = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryIndigo.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: isLong ? 4 : 1,
        keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Bu alan boş bırakılamaz";
          }
          if (isEmail && !value.contains('@')) {
            return "Geçerli bir e-posta adresi girin";
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: AppTheme.neutralDark.withOpacity(0.6),
            fontSize: 16,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryIndigo.withOpacity(0.2),
                  AppTheme.accentOrange.withOpacity(0.1),
                ],
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryIndigo,
              size: 20,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.neutralDark.withOpacity(0.1),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.primaryIndigo,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.errorRed,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: AppTheme.errorRed,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumSubmitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _isLoading ? null : AppTheme.primaryGradient,
        color: _isLoading ? AppTheme.neutralDark.withOpacity(0.3) : null,
        boxShadow: _isLoading ? null : AppTheme.shadowPrimary,
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Mesajı Gönder",
                    style: AppTheme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      bool success = await ApiService.sendContactMessage(
        _nameController.text,
        _emailController.text,
        _messageController.text,
      );

      if (success) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text("Mesajınız başarıyla iletildi!"),
              ],
            ),
            backgroundColor: AppTheme.successGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception("Mesaj gönderilemedi");
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              const Text("Mesaj gönderilemedi. Lütfen tekrar deneyin."),
            ],
          ),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}