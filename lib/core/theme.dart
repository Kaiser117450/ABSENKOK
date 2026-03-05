import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand color palette for Ayam Guling Enakko
/// Theme: Clean White background, Primary Red, Accent Yellow/Amber
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFFDC2626); // Red - main brand color
  static const Color primaryDark = Color(0xFFB91C1C); // Darker red for pressed states
  static const Color primaryLight = Color(0xFFFEE2E2); // Very light red for backgrounds

  // Accent
  static const Color accent = Color(0xFFF59E0B); // Amber/Yellow - highlights & badges
  static const Color accentDark = Color(0xFFD97706);
  static const Color accentLight = Color(0xFFFEF3C7);

  // Semantic colors
  static const Color success = Color(0xFF16A34A); // Green - Masuk
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B); // Amber - Break
  static const Color warningLight = Color(0xFFFEF9C3);
  static const Color danger = Color(0xFFDC2626); // Red - Pulang / errors
  static const Color dangerLight = Color(0xFFFEE2E2);

  // Surface colors
  static const Color background = Color(0xFFFFFFFF); // Pure white
  static const Color surface = Color(0xFFF9FAFB); // Very light gray for cards
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Colors.white;

  // Status badge backgrounds
  static const Color badgeMasukBg = Color(0xFFDCFCE7);
  static const Color badgeMasukText = Color(0xFF15803D);
  static const Color badgeBreakBg = Color(0xFFFEF9C3);
  static const Color badgeBreakText = Color(0xFF92400E);
  static const Color badgePulangBg = Color(0xFFFEE2E2);
  static const Color badgePulangText = Color(0xFFDC2626);

  // Sakit badge
  static const Color badgeSakitBg = Color(0xFFFEF3C7);     // Warm amber light
  static const Color badgeSakitText = Color(0xFF92400E);    // Dark amber

  // Izin badge
  static const Color badgeIzinBg = Color(0xFFDBEAFE);      // Light blue
  static const Color badgeIzinText = Color(0xFF1E40AF);     // Dark blue

  // Belum Pulang badge
  static const Color badgeBelumPulangBg = Color(0xFFFEF9C3); // Light yellow
  static const Color badgeBelumPulangText = Color(0xFF854D0E); // Dark yellow-brown

  // Special
  static const Color kioskBackground = Color(0xFFFFFFFF);
  static const Color nfcRingColor = Color(0xFFDC2626);

  // Kiosk dark palette (idle screen only — NOT app-wide)
  static const Color kioskDarkBase = Color(0xFF0F0F14);        // Near-black base
  static const Color kioskDarkWarm = Color(0xFF1A1410);         // Warm dark (subtle amber)
  static const Color kioskDarkNeutral = Color(0xFF121218);      // Cool neutral dark
  static const Color kioskGlowCenter = Color(0xFFDC2626);      // Brand red center glow
  static const Color kioskGlowCenterDim = Color(0x26DC2626);   // 15% opacity brand red
  static const Color kioskShimmerPeak = Color(0x0AFFFFFF);      // 4% white shimmer peak
  static const Color kioskShimmerMid = Color(0x05FFFFFF);       // 2% white shimmer edge
  static const Color kioskTextPrimary = Color(0xFFFFFFFF);      // White text on dark
  static const Color kioskTextSecondary = Color(0xFFD1D5DB);    // Gray-300 equivalent
  static const Color kioskTextMuted = Color(0xFF9CA3AF);        // Gray-400
  static const Color kioskSurfaceDim = Color(0xFF1F1F26);       // Slightly lighter dark for cards/bars
  static const Color kioskDivider = Color(0xFF2A2A33);          // Subtle dark divider

  // Pre-defined opacity variants (avoid withOpacity() in build/paint)
  static const Color kioskNfcRingOuter = Color(0x33F59E0B);    // 20% amber
  static const Color kioskNfcRingMiddle = Color(0x1FDC2626);   // 12% brand red
  static const Color kioskNfcRingBorder = Color(0x33DC2626);   // 20% brand red
  static const Color kioskNfcGlowRed = Color(0x14DC2626);      // 8% red shadow
  static const Color kioskNfcGlowAmber = Color(0x0FF59E0B);    // 6% amber shadow
}

/// Build the main app theme
ThemeData buildAppTheme() {
  final colorScheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentLight,
    onSecondaryContainer: AppColors.accentDark,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: AppColors.danger,
    onError: Colors.white,
    outline: AppColors.border,
  );

  final textTheme = GoogleFonts.plusJakartaSansTextTheme(
    const TextTheme(
      displayLarge: TextStyle(fontWeight: FontWeight.w800),
      displayMedium: TextStyle(fontWeight: FontWeight.w800),
      displaySmall: TextStyle(fontWeight: FontWeight.w700),
      headlineLarge: TextStyle(fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(fontWeight: FontWeight.w600),
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      titleSmall: TextStyle(fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(fontWeight: FontWeight.w400),
      bodyMedium: TextStyle(fontWeight: FontWeight.w400),
      bodySmall: TextStyle(fontWeight: FontWeight.w400),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
      labelMedium: TextStyle(fontWeight: FontWeight.w600),
      labelSmall: TextStyle(fontWeight: FontWeight.w500),
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.background,

    // AppBar - Red header
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),

    // Cards
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),

    // Elevated Buttons - Red
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // Outlined Buttons
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Text Buttons
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),

    // Bottom Navigation Bar
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Chips
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      selectedColor: AppColors.primary,
      labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: AppColors.border),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
        return AppColors.border;
      }),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.textPrimary,
      contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
