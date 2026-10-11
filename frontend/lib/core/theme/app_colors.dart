import 'package:flutter/material.dart';

/// Centralized color tokens for EatFirm.
/// Derived from brand specifications and UI design documents.
class AppColors {
  AppColors._();

  // Primary Brand Colors (Warm, appetizing orange)
  static const Color primary = Color(0xFFFF5722);
  static const Color primaryDark = Color(0xFFE64A19);
  static const Color primaryLight = Color(0xFFFFCCBC);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary / Accent Colors
  static const Color secondary = Color(0xFFFF8A65);
  static const Color secondaryDark = Color(0xFFD84315);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Neutral / Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF9FAFB);
  static const Color neutral100 = Color(0xFFF3F4F6);
  static const Color neutral200 = Color(0xFFE5E7EB);
  static const Color neutral300 = Color(0xFFD1D5DB);
  static const Color neutral400 = Color(0xFF9CA3AF);
  static const Color neutral500 = Color(0xFF6B7280);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Border & Divider Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderFocused = Color(0xFFFF5722);
  static const Color divider = Color(0xFFF3F4F6);

  // Semantic Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successLight = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color error = Color(0xFFEF4444);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorLight = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF3B82F6);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Interactive & Disabled States
  static const Color disabled = Color(0xFFD1D5DB);
  static const Color disabledText = Color(0xFF9CA3AF);
  static const Color disabledSurface = Color(0xFFF3F4F6);

  // Focus Indicator
  static const Color focusRing = Color(0xFFFF5722);
}
