import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF00C853);
  static const Color primaryDark = Color(0xFF00A846);
  static const Color primaryLight = Color(0xFF69F0AE);

  // Background
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF1C1F2E);
  static const Color surfaceLight = Color(0xFF252836);
  static const Color card = Color(0xFF1C1F2E);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF616161);

  // Semantic
  static const Color income = Color(0xFF43A047); // Green - Thu nhập
  static const Color expense = Color(0xFFF44336); // Red - Chi tiêu
  static const Color transfer = Color(0xFFFFB300); // Amber - Chuyển khoản
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFF44336);

  // Divider & Border
  static const Color divider = Color(0xFF2C2F3E);
  static const Color border = Color(0xFF2C2F3E);

  // Category icon backgrounds
  static const List<Color> categoryColors = [
    Color(0xFFE53935), // Ăn uống - Red
    Color(0xFF1E88E5), // Di chuyển - Blue
    Color(0xFF8E24AA), // Mua sắm - Purple
    Color(0xFF00897B), // Sức khỏe - Teal
    Color(0xFFFB8C00), // Giải trí - Orange
    Color(0xFF43A047), // Thu nhập - Green
    Color(0xFF6D4C41), // Giáo dục - Brown
    Color(0xFF00ACC1), // Hóa đơn - Cyan
    Color(0xFFE91E63), // Du lịch - Pink
    Color(0xFF5E35B1), // Đầu tư - Deep Purple
  ];
}
