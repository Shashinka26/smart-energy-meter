import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const background = Color(0xFF09110D);
  static const surface = Color(0xFF17211C);
  static const surfaceLight = Color(0xFF1E2D25);
  static const surfaceElevated = Color(0xFF14221B);
  static const navBar = Color(0xFF111A16);

  static const primary = Color(0xFF22C55E);
  static const primaryDark = Color(0xFF16803A);
  static const primaryLight = Color(0xFF4ADE80);
  static const gradientStart = Color(0xFF126B34);
  static const gradientEnd = Color(0xFF28873D);

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);
  static const info = Color(0xFF38BDF8);

  static const amber = Color(0xFFFBBF24);
  static const orange = Color(0xFFFB923C);
  static const cyan = Color(0xFF22D3EE);
  static const purple = Color(0xFFA78BFA);
  static const blue = Color(0xFF60A5FA);

  static Color border([double opacity = 0.08]) =>
      Colors.white.withValues(alpha: opacity);

  static Color tint(Color color, [double opacity = 0.16]) =>
      color.withValues(alpha: opacity);
}
