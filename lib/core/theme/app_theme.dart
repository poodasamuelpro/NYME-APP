import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'NymeFont',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.bleuPrimaire,
        primary: AppColors.bleuPrimaire,
        secondary: AppColors.orange,
        surface: AppColors.fondPrincipal,
        error: AppColors.erreur,
      ),
      scaffoldBackgroundColor: AppColors.fondPrincipal,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.blanc,
        foregroundColor: AppColors.noir,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'NymeFont',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.noir,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bleuPrimaire,
          foregroundColor: AppColors.blanc,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NymeFont',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fondInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.bleuPrimaire, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.erreur),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.grisClair),
      ),
      cardTheme: CardTheme(
        color: AppColors.blanc,
        elevation: 2,
        shadowColor: AppColors.ombre,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.blanc,
        selectedItemColor: AppColors.bleuPrimaire,
        unselectedItemColor: AppColors.grisClair,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme; // TODO: implémenter mode sombre
}
