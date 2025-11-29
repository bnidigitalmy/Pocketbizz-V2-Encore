import 'package:flutter/material.dart';

/// PocketBizz Brand Colors - Malaysian SME-Friendly
/// Primary: Fresh Green (Growth, Money, Halal-friendly)
/// Accent: Premium Gold (Trust, Value)
class AppColors {
  // Primary Colors - Fresh Emerald Green (PocketBizz Brand)
  static const primary = Color(0xFF10B981);        // Emerald Green
  static const primaryDark = Color(0xFF059669);    // Deep Green
  static const primaryLight = Color(0xFF34D399);   // Light Green
  
  // Accent Colors - Premium Gold
  static const accent = Color(0xFFF59E0B);         // Amber Gold
  static const accentLight = Color(0xFFFCD34D);    // Light Gold
  static const accentDark = Color(0xFFD97706);     // Deep Gold
  
  // Status Colors
  static const success = Color(0xFF10B981);        // Same as primary (green = success)
  static const successLight = Color(0xFF6EE7B7);
  static const warning = Color(0xFFF59E0B);        // Same as accent (gold = warning)
  static const warningLight = Color(0xFFFBBF24);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFF87171);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFF60A5FA);
  
  // Neutral Colors - Clean & Professional
  static const background = Color(0xFFF9FAFB);     // Very light grey
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF3F4F6);
  
  // Text Colors - Professional Charcoal
  static const textPrimary = Color(0xFF1F2937);    // Deep charcoal
  static const textSecondary = Color(0xFF6B7280);  // Medium grey
  static const textHint = Color(0xFF9CA3AF);       // Light grey
  
  // Gradients - PocketBizz Signature
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
  
  // Premium gradient for special cards
  static const premiumGradient = LinearGradient(
    colors: [primary, accent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Shadows - Soft & Modern
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: primary.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> accentButtonShadow = [
    BoxShadow(
      color: accent.withOpacity(0.25),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];
}

