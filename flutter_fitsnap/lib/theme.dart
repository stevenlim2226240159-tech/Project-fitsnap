import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF3C1D6D);
  static const Color secondary = Color(0xFF7B59C8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F3FF);
  static const Color accent = Color(0xFFB487FF);
  static const Color textPrimary = Color(0xFF2F224B);
  static const Color textSecondary = Color(0xFF6C5E87);
  static const Color border = Color(0xFFE4D8F8);
  static const Color shadow = Color(0xFFCDC2E6);
}

final ThemeData appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.background,
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    secondary: AppColors.secondary,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    error: Colors.red.shade700,
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onError: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: AppColors.primary,
    elevation: 0,
    centerTitle: true,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      foregroundColor: Colors.white,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.secondary),
    ),
    labelStyle: TextStyle(color: AppColors.textSecondary),
  ),
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      fontSize: 28,
    ),
    headlineSmall: TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      fontSize: 24,
    ),
    bodyMedium: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 16,
    ),
    titleMedium: TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.bold,
      fontSize: 18,
    ),
  ),
);