import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';

/// Reusable card component for EatFirm.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final BorderSide? border;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brLg,
        child: cardContent,
      );
    }

    return Material(
      color: backgroundColor ?? AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brLg,
        side: border ?? const BorderSide(color: AppColors.border, width: 1),
      ),
      child: cardContent,
    );
  }
}
