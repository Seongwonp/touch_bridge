import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Pure dark background and bright foreground for low-vision readability.
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF121212);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color outline = Color(0xFF8A8A8A);

  // Primary color communicates clarity and trust.
  static const Color primary = Color(0xFF00B8FF);

  // Red is reserved for emergency-related actions only.
  static const Color emergency = Color(0xFFFF3B30);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFFFB020);
}
