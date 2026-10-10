import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';

enum AppButtonVariant { primary, secondary, outline, destructive, text }

/// Standard button widget supporting multiple visual variants,
/// loading spinner, disabled state, and accessible touch target.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final bool isFullWidth;
  final Widget? icon;
  final double height;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = 48.0,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    final Widget content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_getSpinnerColor()),
            ),
          )
        : Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: AppSpacing.xs),
              ],
              Flexible(
                child: Text(
                  label,
                  style: _getTextStyle(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            disabledBackgroundColor: AppColors.disabled,
            disabledForegroundColor: AppColors.disabledText,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.secondary:
        button = ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: AppColors.onSecondary,
            disabledBackgroundColor: AppColors.disabled,
            disabledForegroundColor: AppColors.disabledText,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.outline:
        button = OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: BorderSide(
              color: isDisabled ? AppColors.disabled : AppColors.primary,
              width: 1.5,
            ),
            disabledForegroundColor: AppColors.disabledText,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.destructive:
        button = ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.onError,
            disabledBackgroundColor: AppColors.disabled,
            disabledForegroundColor: AppColors.disabledText,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: content,
        );
        break;

      case AppButtonVariant.text:
        button = TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            disabledForegroundColor: AppColors.disabledText,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.brMd),
            minimumSize: Size(isFullWidth ? double.infinity : 0, height),
          ),
          child: content,
        );
        break;
    }

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: label,
      child: button,
    );
  }

  Color _getSpinnerColor() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.destructive:
        return Colors.white;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppColors.primary;
    }
  }

  TextStyle _getTextStyle() {
    switch (variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.secondary:
      case AppButtonVariant.destructive:
        return AppTypography.button;
      case AppButtonVariant.outline:
      case AppButtonVariant.text:
        return AppTypography.button.copyWith(color: AppColors.primary);
    }
  }
}
