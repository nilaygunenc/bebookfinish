import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

class AboutBebookScreen extends StatefulWidget {
  const AboutBebookScreen({super.key});

  @override
  State<AboutBebookScreen> createState() => _AboutBebookScreenState();
}

class _AboutBebookScreenState extends State<AboutBebookScreen> with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardAnimation;

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
                    
                    // Premium content cards
                    FadeTransition(
                      opacity: _cardAnimation,
                      child: Column(
                        children: [
                          _buildPremiumWelcomeCard(),
                          const SizedBox(height: 24),
                          _buildPremiumInfoCard(
                            "BEBOOK NEDİR?",
                            "Öğrencilerin okul için alıp kullanmadıkları ders kitaplarını siteye fotoğrafları ile yükleyip haberleşerek birbirlerine elden sattıkları bir e-ticaret sitesidir.",
                            Icons.auto_stories_rounded,
                            AppTheme.primaryGradient,
                          ),
                          const SizedBox(height: 20),
                          _buildPremiumInfoCard(
                            "BEBOOK KATKILARI",
                            "• İthal Kitap Talebini Azaltma\n• Öğrencilere Ekonomik Fayda\n• Kaynakların Verimli Kullanımı\n• Döngüsel Ekonomi\n• Eğitime Katkı",
                            Icons.eco_rounded,
                            AppTheme.accentGradient,
                          ),
                          const SizedBox(height: 20),
                          _buildPremiumInfoCard(
                            "BEBOOK HEDEF KİTLE",
                            "Bülent Ecevit Üniversitesinde okuyan, ders kitaplarını veya notlarını elden çıkartmak ya da almak isteyen tüm öğrenciler için tasarlanmıştır.",
                            Icons.school_rounded,
                            AppTheme.cyanGradient,
                          ),
                          const SizedBox(height: 20),
                          _buildPremiumUsageCard(),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
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
                  "Bebook Hakkında",
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

  Widget _buildPremiumWelcomeCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: AppTheme.shadowPrimary,
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  "HOŞGELDİN",
                  style: AppTheme.textTheme.displaySmall?.copyWith(
                    color: AppTheme.primaryIndigo,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  "Kitapları görmek ve satın almak için önce hesabın yoksa üye olmalısın, hesabın varsa giriş yapmalısın.",
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.neutralDark,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumInfoCard(
    String title,
    String content,
    IconData icon,
    LinearGradient gradient,
  ) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(32),
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
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
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
                    Expanded(
                      child: Text(
                        title,
                        style: AppTheme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryIndigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                Text(
                  content,
                  style: AppTheme.textTheme.bodyLarge?.copyWith(
                    color: AppTheme.neutralDark,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.left,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumUsageCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 600),
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
                  AppTheme.accentOrange.withOpacity(0.1),
                  Colors.white.withOpacity(0.8),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: AppTheme.sunsetGradient,
                        boxShadow: AppTheme.shadowPrimary,
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(
                        "BEBOOK NASIL KULLANILIR?",
                        style: AppTheme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primaryIndigo,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                ...[
                  "Üye değilseniz ilk olarak kendinize hesap oluşturun",
                  "Hesabınız oluşturulduktan sonra giriş yap butonundan giriş yapınız",
                  "Giriş yaptığınızda anasayfanızdaki kitabın üzerine tıklayıp satıcıya ulaşabilir ve kitabı elden alabilirsiniz",
                  "Ürün yükle butonundan kendi kitabınızı satılığa çıkarabilirsiniz",
                ].asMap().entries.map((entry) {
                  final index = entry.key;
                  final text = entry.value;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accentOrange,
                                AppTheme.accentOrange.withOpacity(0.7),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "${index + 1}",
                              style: AppTheme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            text,
                            style: AppTheme.textTheme.bodyLarge?.copyWith(
                              color: AppTheme.neutralDark,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}