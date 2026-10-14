import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color background = Color(0xFFF4F2FD);
  static const Color surface = Colors.white;
  static const Color primary = Color(0xFF7B6BF2);
  static const Color primaryDark = Color(0xFF5B4BD6);
  static const Color primarySoft = Color(0xFFEDEAFD);
  static const Color accent = Color(0xFFFF8A3D);
  static const Color accentSoft = Color(0xFFFFF0E4);
  static const Color success = Color(0xFF2FCB6E);
  static const Color successSoft = Color(0xFFE4F9EE);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSoft = Color(0xFFFDE8E8);
  static const Color ink = Color(0xFF1F1D2B);
  static const Color inkSoft = Color(0xFF6B6A7B);
  static const Color inkFaint = Color(0xFFA5A4B4);
  static const Color divider = Color(0xFFECEAF6);

  static const Color literature = Color(0xFFF0699A);
  static const Color geography = Color(0xFF3AA8F0);
  static const Color history = Color(0xFFFB923C);
  static const Color math = Color(0xFF2FCB6E);
  static const Color language = Color(0xFF8B5CF6);
  static const Color science = Color(0xFF06B6D4);
  static const Color social = Color(0xFFE11D48);

  static const Color flame = Color(0xFFFF7A1A);
}

class AppGradients {
  AppGradients._();

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6F3FE), Color(0xFFEDE9FC), Color(0xFFF9F1FA)],
  );

  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B7BF6), Color(0xFF6A57E8)],
  );

  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFA75C), Color(0xFFFF7A3D)],
  );
}
