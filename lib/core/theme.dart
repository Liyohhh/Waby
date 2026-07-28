import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Waby brand palette — single source of truth for the app's colours.
/// Values taken directly from the Figma design.
class AppColors {
  // Brand
  static const navy         = Color(0xFF0F2D54); // primary buttons, headings
  static const navyDeep     = Color(0xFF0D1117); // logo wings / darkest text
  static const headerTop    = Color(0xFF008FB4); // wave-header gradient start (dark)
  static const headerBottom = Color(0xFF7AD0E4); // wave-header gradient end (light)
  static const accent       = Color(0xFF3B74BC); // links, info pills
  static const value        = Color(0xFF5187C6); // big stat numbers
  static const dot          = Color(0xFF2AAEE0); // logo dot / bright accent
  static const softBlue     = Color(0xFF8ECEE1); // bottom nav, soft accents

  // Surfaces
  static const field        = Color(0xFFF7F3F3); // input backgrounds
  static const safeCard     = Color(0xFFE0E8F2); // safe child card
  static const warningCard  = Color(0xFFFBE6E5); // warning child card
  static const card         = Color(0xFFFFFFFF);

  // Status
  static const safe         = Color(0xFF56B337); // SAFE green
  static const caution      = Color(0xFFE89827); // CAUTION amber
  static const warning      = Color(0xFFC2291D); // WARNING / critical red
  static const critical     = Color(0xFFC2291D); // CRITICAL red

  // Text
  static const textPrimary   = Color(0xFF0F2D54);
  static const textSecondary = Color(0xFF6B7280);
  static const hint          = Color(0xFFA0A6B1); // form field hints/placeholders — lighter than textSecondary
}

/// Reusable gradient for the curved "wave" header used across screens.
const kHeaderGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [AppColors.headerTop, AppColors.headerBottom],
  stops: [0.31, 0.88],
);

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.navy,
        secondary: AppColors.accent,
        surface: AppColors.card,
        error: AppColors.warning,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme).apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 56),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.field,
        hintStyle: GoogleFonts.poppins(color: AppColors.hint),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
