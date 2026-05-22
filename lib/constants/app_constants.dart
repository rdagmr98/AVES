import 'package:flutter/material.dart';

class AppColors {
  // Tema militare AVES
  static const Color primary = Color(0xFF1B4332); // verde militare scuro
  static const Color primaryLight = Color(0xFF2D6A4F); // verde militare chiaro
  static const Color secondary = Color(0xFFD4AC0D); // oro
  static const Color background = Color(0xFF1A1A2E); // blu notte
  static const Color surface = Color(0xFF16213E); // superficie
  static const Color cardBg = Color(0xFF0F3460); // card
  static const Color cardBgLight = Color(0xFF1E3A5F); // card chiaro

  // Currency status
  static const Color currencyValid = Color(0xFF27AE60); // verde
  static const Color currencyWarning = Color(0xFFE67E22); // arancione
  static const Color currencyExpired = Color(0xFFC0392B); // rosso

  // Testi
  static const Color textPrimary = Color(0xFFECF0F1);
  static const Color textSecondary = Color(0xFF95A5A6);
  static const Color textDark = Color(0xFF2C3E50);

  // Bordi e divisori
  static const Color divider = Color(0xFF34495E);
  static const Color border = Color(0xFF2C3E50);
}

class AppStrings {
  // App
  static const String appName = 'AVES Currency';
  static const String appFullName =
      'Aviazione dell\'Esercito\nGestione Currency';

  // Admin email (iniziali, modificabili in app)
  static const String adminPrivEmail = 'admin.privilegi@aves.esercito.it';
  static const String adminCrewEmail = 'admin.equipaggi@aves.esercito.it';
  static const String adminPrivPassword = 'AvesPriv2024!';
  static const String adminCrewPassword = 'AvesCrew2024!';

  // Currency status
  static const String currencyValid = 'VALIDA';
  static const String currencyWarning = 'IN SCADENZA';
  static const String currencyExpired = 'SCADUTA';

  // Warning threshold
  static const int warningDays = 30;

  // Roles
  static const String roleUser = 'user';
  static const String roleAdminPriv = 'admin_priv';
  static const String roleAdminCrew = 'admin_crew';
}

class AppTheme {
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.currencyExpired,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.secondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.secondary, width: 2),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardBg,
        selectedColor: AppColors.primary,
        disabledColor: AppColors.border,
        labelStyle: const TextStyle(fontSize: 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 0.5,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(color: AppColors.textPrimary),
        titleSmall: TextStyle(color: AppColors.textSecondary),
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textSecondary),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.cardBgLight,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.black,
      ),
    );
  }
}
