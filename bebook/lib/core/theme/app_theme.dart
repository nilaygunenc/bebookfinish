import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 Bebook Modern Tema Sistemi
/// Organik, sıcak ve premium hissettiren renk paleti
class AppTheme {
  // ═══════════════════════════════════════════════════════════════
  // 🎨 RENK PALETİ - Soft Indigo & Warm Orange
  // ═══════════════════════════════════════════════════════════════
  
  // Ana renkler - Deep Purple & Electric Blue
  static const Color primaryIndigo = Color(0xFF5B21B6);      // Deep purple
  static const Color primaryIndigoLight = Color(0xFF7C3AED); // Vibrant purple
  static const Color primaryIndigoDark = Color(0xFF4C1D95);  // Dark purple
  
  // Aksan renk - Electric Cyan & Sunset Orange
  static const Color accentOrange = Color(0xFFFF6B35);       // Sunset orange
  static const Color accentOrangeLight = Color(0xFFFF8C42);  // Light orange
  static const Color accentOrangeDark = Color(0xFFE85D2C);   // Dark orange
  
  static const Color accentCyan = Color(0xFF06B6D4);         // Electric cyan
  static const Color accentCyanLight = Color(0xFF22D3EE);    // Light cyan
  static const Color accentPink = Color(0xFFEC4899);         // Hot pink
  
  // Nötr renkler - Organik gri tonları
  static const Color neutralWhite = Color(0xFFFAFAFA);       // Soft white
  static const Color neutralLight = Color(0xFFF5F5F7);       // Light gray
  static const Color neutralMedium = Color(0xFFE5E7EB);      // Medium gray
  static const Color neutralDark = Color(0xFF6B7280);        // Dark gray
  static const Color neutralBlack = Color(0xFF1F2937);       // Soft black
  
  // Durum renkleri - Yumuşak tonlar
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color infoBlue = Color(0xFF3B82F6);
  
  // Gradient'ler - Premium ve dinamik
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFF5B21B6), Color(0xFF4C1D95)],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFEC4899)],
  );
  
  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B35), Color(0xFFFBBF24), Color(0xFFEC4899)],
  );
  
  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F7)],
  );
  
  // ═══════════════════════════════════════════════════════════════
  // 📐 SPACING & SIZING - Organik ritim
  // ═══════════════════════════════════════════════════════════════
  
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;
  static const double space2XL = 48.0;
  
  // Border radius - Yumuşak köşeler
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 999.0;
  
  // ═══════════════════════════════════════════════════════════════
  // 🎭 SHADOWS - Zarif derinlik
  // ═══════════════════════════════════════════════════════════════
  
  static List<BoxShadow> get shadowSM => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get shadowMD => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get shadowLG => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get shadowXL => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
  
  // Colored shadows - Premium his
  static List<BoxShadow> get shadowPrimary => [
    BoxShadow(
      color: primaryIndigo.withOpacity(0.20),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get shadowAccent => [
    BoxShadow(
      color: accentOrange.withOpacity(0.20),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
  
  // ═══════════════════════════════════════════════════════════════
  // 🔤 TYPOGRAPHY - Poppins & Inter
  // ═══════════════════════════════════════════════════════════════
  
  static TextTheme get textTheme => TextTheme(
    // Display - Büyük başlıklar
    displayLarge: GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: neutralBlack,
      height: 1.2,
    ),
    displayMedium: GoogleFonts.poppins(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: neutralBlack,
      height: 1.3,
    ),
    displaySmall: GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.3,
    ),
    
    // Headline - Bölüm başlıkları
    headlineLarge: GoogleFonts.poppins(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.4,
    ),
    headlineMedium: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.4,
    ),
    headlineSmall: GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.4,
    ),
    
    // Title - Kart başlıkları
    titleLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.5,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.5,
    ),
    titleSmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      height: 1.5,
    ),
    
    // Body - İçerik metinleri
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: neutralDark,
      height: 1.6,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: neutralDark,
      height: 1.6,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: neutralDark,
      height: 1.6,
    ),
    
    // Label - Buton ve etiketler
    labelLarge: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      letterSpacing: 0.5,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: neutralBlack,
      letterSpacing: 0.5,
    ),
  );
  
  // ═══════════════════════════════════════════════════════════════
  // 🎨 THEME DATA - Flutter tema yapılandırması
  // ═══════════════════════════════════════════════════════════════
  
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary: primaryIndigo,
      secondary: accentOrange,
      surface: neutralWhite,
      background: neutralLight,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: neutralBlack,
      onBackground: neutralBlack,
      onError: Colors.white,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor: neutralLight,
    appBarTheme: AppBarTheme(
      backgroundColor: neutralWhite,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: neutralBlack,
      ),
      iconTheme: const IconThemeData(color: neutralBlack),
    ),
    cardTheme: CardThemeData(
      color: neutralWhite,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLG),
      ),
      shadowColor: Colors.black.withOpacity(0.06),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: neutralWhite,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: primaryIndigo, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: GoogleFonts.inter(
        color: neutralDark,
        fontSize: 14,
      ),
    ),
  );
}
