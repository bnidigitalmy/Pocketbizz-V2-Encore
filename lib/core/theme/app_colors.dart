import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors - Modern Purple/Blue Gradient
  static const primary = Color(0xFF6C63FF);
  static const primaryDark = Color(0xFF5548E8);
  static const primaryLight = Color(0xFF8B84FF);
  
  // Accent Colors
  static const accent = Color(0xFFFF6584);
  static const accentLight = Color(0xFFFF8FA3);
  
  // Status Colors
  static const success = Color(0xFF4CAF50);
  static const successLight = Color(0xFF81C784);
  static const warning = Color(0xFFFF9800);
  static const warningLight = Color(0xFFFFB74D);
  static const error = Color(0xFFF44336);
  static const errorLight = Color(0xFFE57373);
  static const info = Color(0xFF2196F3);
  static const infoLight = Color(0xFF64B5F6);
  
  // Neutral Colors
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF5F5F5);
  
  // Text Colors
  static const textPrimary = Color(0xFF2C3E50);
  static const textSecondary = Color(0xFF7F8C8D);
  static const textHint = Color(0xFFBDC3C7);
  
  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const accentGradient = LinearGradient(
    colors: [accent, accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const successGradient = LinearGradient(
    colors: [success, successLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const warningGradient = LinearGradient(
    colors: [warning, warningLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primary.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

