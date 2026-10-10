import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';

enum AppBadgeType { success, warning, error, info, neutral }

/// Reusable status badge chip conveying state via text, color, and optional icon.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeType type;
  final IconData? icon;

  const AppBadge({
    super.key,
    required this.label,
    this.type = AppBadgeType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: AppRadius.brPill,
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colors.foreground),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  ({Color background, Color foreground, Color border}) _getColors() {
    switch (type) {
      case AppBadgeType.success:
        return (
          background: AppColors.successLight,
          foreground: AppColors.success,
          border: AppColors.success.withAlpha(76),
        );
      case AppBadgeType.warning:
        return (
          background: AppColors.warningLight,
          foreground: AppColors.warning,
          border: AppColors.warning.withAlpha(76),
        );
      case AppBadgeType.error:
        return (
          background: AppColors.errorLight,
          foreground: AppColors.error,
          border: AppColors.error.withAlpha(76),
        );
      case AppBadgeType.info:
        return (
          background: AppColors.infoLight,
          foreground: AppColors.info,
          border: AppColors.info.withAlpha(76),
        );
      case AppBadgeType.neutral:
        return (
          background: AppColors.background,
          foreground: AppColors.textSecondary,
          border: AppColors.border,
        );
    }
  }
}
