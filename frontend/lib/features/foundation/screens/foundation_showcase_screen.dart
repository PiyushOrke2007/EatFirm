import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// Comprehensive interactive design system and foundation showroom.
/// Validates and demonstrates all tokens, components, responsive states,
/// error handling, and live REST API connectivity.
class FoundationShowcaseScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const FoundationShowcaseScreen({super.key, this.apiClient});

  @override
  State<FoundationShowcaseScreen> createState() =>
      _FoundationShowcaseScreenState();
}

class _FoundationShowcaseScreenState extends State<FoundationShowcaseScreen> {
  late final ApiClient _apiClient;

  // Form Field State
  final _emailController = TextEditingController(text: 'alex@example.com');
  final _passwordController = TextEditingController(text: 'password123');
  final _nameController = TextEditingController();
  String? _emailError;
  String? _nameError;

  // Button Loading State
  bool _isButtonLoading = false;

  // Live Backend Check State
  bool _isCheckingBackend = false;
  Map<String, dynamic>? _backendHealthData;
  Map<String, dynamic>? _backendReadyData;
  String? _backendError;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _fetchBackendStatus();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchBackendStatus() async {
    setState(() {
      _isCheckingBackend = true;
      _backendError = null;
    });

    try {
      final healthRes = await _apiClient.get('/health');
      final readyRes = await _apiClient.get('/ready');

      if (mounted) {
        setState(() {
          _isCheckingBackend = false;
          _backendHealthData = healthRes.data as Map<String, dynamic>?;
          _backendReadyData = readyRes.data as Map<String, dynamic>?;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingBackend = false;
          _backendError = e.toString();
        });
      }
    }
  }

  void _validateForm() {
    setState(() {
      final email = _emailController.text.trim();
      final name = _nameController.text.trim();

      if (name.isEmpty) {
        _nameError = 'Name is required';
      } else {
        _nameError = null;
      }

      if (email.isEmpty) {
        _emailError = 'Email address cannot be empty';
      } else if (!email.contains('@') || !email.contains('.')) {
        _emailError = 'Please enter a valid email address';
      } else {
        _emailError = null;
      }

      if (_nameError == null && _emailError == null) {
        AppSnackbar.showSuccess(context, 'Form validated successfully!');
      } else {
        AppSnackbar.showError(context, 'Please correct the validation errors');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return AppScaffold(
      title: '${AppConstants.appName} — Design System & Foundations',
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Hero Banner
            _buildHeaderBanner(),
            const SizedBox(height: AppSpacing.lg),

            // 1. Live Backend Status Card
            _buildBackendStatusCard(),
            const SizedBox(height: AppSpacing.xl),

            // Responsive Two-Column or Single-Column Layout
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildButtonSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildFormSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      children: [
                        _buildBadgeAndToastSection(),
                        const SizedBox(height: AppSpacing.xl),
                        _buildDialogAndStatesSection(),
                      ],
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildButtonSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildFormSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildBadgeAndToastSection(),
                  const SizedBox(height: AppSpacing.xl),
                  _buildDialogAndStatesSection(),
                ],
              ),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return AppCard(
      backgroundColor: AppColors.primary,
      border: BorderSide.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.brSm,
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'EatFirm Foundation Baseline',
                  style: AppTypography.headline.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Centralized tokens, accessible controls, responsive scaffolding, and REST backend contracts.',
            style: AppTypography.body.copyWith(
              color: Colors.white.withAlpha(220),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendStatusCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Backend & Infrastructure Readiness',
                        style: AppTypography.title,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: _isCheckingBackend
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isCheckingBackend ? null : _fetchBackendStatus,
                tooltip: 'Refresh Status',
              ),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          if (_backendError != null)
            AppErrorState(
              icon: Icons.cloud_off,
              title: 'Backend Unreachable',
              message: _backendError!,
              retryLabel: 'Retry Health Check',
              onRetry: _fetchBackendStatus,
            )
          else ...[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('API Service: ', style: AppTypography.label),
                    AppBadge(
                      label: _backendHealthData?['service'] ?? 'Connecting...',
                      type: AppBadgeType.info,
                      icon: Icons.check,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('PostgreSQL: ', style: AppTypography.label),
                    AppBadge(
                      label:
                          _backendReadyData?['database']?['status'] ??
                          'Connecting...',
                      type: AppBadgeType.success,
                      icon: Icons.storage,
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Migrations: ', style: AppTypography.label),
                    AppBadge(
                      label:
                          _backendReadyData?['migrations']?['status'] ??
                          'Connecting...',
                      type: AppBadgeType.success,
                      icon: Icons.checklist,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildButtonSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Button Variants & States', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Touch target >= 48px, visible focus, active and disabled states.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Primary Action',
            variant: AppButtonVariant.primary,
            icon: const Icon(Icons.shopping_bag_outlined, size: 20),
            onPressed: () {
              AppSnackbar.showInfo(context, 'Primary Button Tapped');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Secondary Action',
            variant: AppButtonVariant.secondary,
            onPressed: () {
              AppSnackbar.showInfo(context, 'Secondary Button Tapped');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Outline Action',
            variant: AppButtonVariant.outline,
            onPressed: () {
              AppSnackbar.showInfo(context, 'Outline Button Tapped');
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Destructive Action',
            variant: AppButtonVariant.destructive,
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () {
              AppConfirmationDialog.show(
                context,
                title: 'Cancel Order?',
                message: 'Are you sure you want to cancel this order? This action cannot be undone.',
                isDestructive: true,
                confirmText: 'Yes, Cancel',
              ).then((confirmed) {
                if (!mounted) return;
                if (confirmed == true) {
                  AppSnackbar.showWarning(
                    context,
                    'Destructive action confirmed',
                  );
                }
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _isButtonLoading ? 'Loading...' : 'Toggle Loading',
                  isLoading: _isButtonLoading,
                  onPressed: () {
                    setState(() => _isButtonLoading = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _isButtonLoading = false);
                    });
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: AppButton(label: 'Disabled', onPressed: null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Form Fields & Validation', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Visible labels, password visibility toggle, accessible focus, and field error feedback.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Full Name',
            hint: 'Enter your full name',
            controller: _nameController,
            prefixIcon: const Icon(Icons.person_outline),
            errorText: _nameError,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Email Address',
            hint: 'name@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: const Icon(Icons.email_outlined),
            errorText: _emailError,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Password',
            hint: 'Enter password',
            controller: _passwordController,
            isPassword: true,
            prefixIcon: const Icon(Icons.lock_outline),
            helperText: 'Must be at least 8 characters long',
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Validate Inputs', onPressed: _validateForm),
        ],
      ),
    );
  }

  Widget _buildBadgeAndToastSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status Badges & Feedback Toasts', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Information conveyed with both text and color (SRS / Accessibility).',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: const [
              AppBadge(
                label: 'Delivered',
                type: AppBadgeType.success,
                icon: Icons.check_circle,
              ),
              AppBadge(
                label: 'Preparing',
                type: AppBadgeType.warning,
                icon: Icons.timer,
              ),
              AppBadge(
                label: 'Cancelled',
                type: AppBadgeType.error,
                icon: Icons.cancel,
              ),
              AppBadge(
                label: 'Out for Delivery',
                type: AppBadgeType.info,
                icon: Icons.moped,
              ),
              AppBadge(label: 'Draft', type: AppBadgeType.neutral),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Text('Toast Notifications', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              AppButton(
                label: 'Success Toast',
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                onPressed: () => AppSnackbar.showSuccess(
                  context,
                  'Order placed successfully!',
                ),
              ),
              AppButton(
                label: 'Error Toast',
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                onPressed: () => AppSnackbar.showError(
                  context,
                  'Payment could not be completed.',
                ),
              ),
              AppButton(
                label: 'Warning Toast',
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                onPressed: () => AppSnackbar.showWarning(
                  context,
                  'Restaurant closes in 15 minutes.',
                ),
              ),
              AppButton(
                label: 'Info Toast',
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                onPressed: () => AppSnackbar.showInfo(
                  context,
                  'New offers available nearby.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDialogAndStatesSection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Modals & State Components', style: AppTypography.title),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Confirmation modals, error modals, loading skeletons, and empty state widgets.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Confirmation Modal',
                  variant: AppButtonVariant.outline,
                  onPressed: () {
                    AppConfirmationDialog.show(
                      context,
                      title: 'Confirm Action',
                      message:
                          'Are you sure you want to proceed with this request?',
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Error Modal',
                  variant: AppButtonVariant.outline,
                  onPressed: () {
                    AppErrorDialog.show(
                      context,
                      title: 'Connection Issue',
                      message: 'Failed to synchronize with server.',
                      requestId: 'req-showcase-diag-492',
                    );
                  },
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Text('Loading Skeletons', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          const AppSkeleton(height: 20, width: 220),
          const SizedBox(height: AppSpacing.xs),
          const AppSkeleton(height: 14),
          const SizedBox(height: AppSpacing.xs),
          const AppSkeleton(height: 14, width: 280),
          const Divider(height: AppSpacing.xl),
          Text('Empty State Preview', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          const AppEmptyState(
            icon: Icons.shopping_basket_outlined,
            title: 'Your cart is empty',
            description: 'Explore our top restaurants and add delicious meals to your cart.',
            actionLabel: 'Browse Restaurants',
          ),
        ],
      ),
    );
  }
}
