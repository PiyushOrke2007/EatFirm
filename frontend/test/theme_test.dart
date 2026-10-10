import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/app_colors.dart';
import 'package:eatfirm/core/theme/app_typography.dart';
import 'package:eatfirm/core/theme/app_spacing.dart';
import 'package:eatfirm/core/theme/app_radius.dart';
import 'package:eatfirm/core/theme/app_theme.dart';

void main() {
  group('Theme Tokens & Constants', () {
    test('AppColors brand tokens are defined correctly', () {
      expect(AppColors.primary.toARGB32(), equals(0xFFFF5722));
      expect(AppColors.onPrimary.toARGB32(), equals(0xFFFFFFFF));
      expect(AppColors.error.toARGB32(), equals(0xFFEF4444));
      expect(AppColors.success.toARGB32(), equals(0xFF10B981));
    });

    test('AppTypography has correct hierarchy', () {
      expect(AppTypography.display.fontSize, equals(32.0));
      expect(AppTypography.headline.fontSize, equals(24.0));
      expect(AppTypography.title.fontSize, equals(18.0));
      expect(AppTypography.body.fontSize, equals(14.0));
      expect(AppTypography.label.fontSize, equals(12.0));
    });

    test('AppSpacing follows 4-point scale', () {
      expect(AppSpacing.xxs, equals(4.0));
      expect(AppSpacing.xs, equals(8.0));
      expect(AppSpacing.sm, equals(12.0));
      expect(AppSpacing.md, equals(16.0));
      expect(AppSpacing.lg, equals(24.0));
      expect(AppSpacing.xl, equals(32.0));
      expect(AppSpacing.xxl, equals(40.0));
      expect(AppSpacing.xxxl, equals(48.0));
    });

    test('AppRadius tokens are defined correctly', () {
      expect(AppRadius.xs, equals(4.0));
      expect(AppRadius.sm, equals(8.0));
      expect(AppRadius.md, equals(12.0));
      expect(AppRadius.lg, equals(16.0));
    });

    test('AppTheme generates a valid Material 3 theme', () {
      final theme = AppTheme.lightTheme;
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.colorScheme.error, equals(AppColors.error));
    });
  });
}
