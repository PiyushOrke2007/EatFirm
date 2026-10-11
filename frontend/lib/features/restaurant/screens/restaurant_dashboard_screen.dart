import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/restaurant_model.dart';
import '../services/restaurant_api_service.dart';

/// Restaurant Admin Dashboard Screen (SRS REST-1, REST-2, REST-5).
class RestaurantDashboardScreen extends StatefulWidget {
  final RestaurantApiService restaurantService;

  const RestaurantDashboardScreen({
    super.key,
    required this.restaurantService,
  });

  @override
  State<RestaurantDashboardScreen> createState() =>
      _RestaurantDashboardScreenState();
}

class _RestaurantDashboardScreenState extends State<RestaurantDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  RestaurantModel? _restaurant;
  bool _isTogglingStatus = false;

  @override
  void initState() {
    super.initState();
    _loadRestaurant();
  }

  Future<void> _loadRestaurant() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.restaurantService.getMyRestaurant();
      if (mounted) {
        setState(() {
          _restaurant = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleToggleOpen(bool newStatus) async {
    if (_restaurant == null || _isTogglingStatus) return;

    setState(() => _isTogglingStatus = true);
    try {
      final updated = await widget.restaurantService.toggleRestaurantOpen(newStatus);
      if (mounted) {
        setState(() => _restaurant = updated);
        AppSnackbar.showSuccess(
          context,
          newStatus ? 'Restaurant is now OPEN for orders' : 'Restaurant marked CLOSED for orders',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to update status: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isTogglingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator(message: 'Loading restaurant profile...')),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Restaurant Operations'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.profile),
          ),
        ),
        body: Center(
          child: AppErrorState(
            message: _errorMessage!,
            onRetry: _loadRestaurant,
          ),
        ),
      );
    }

    if (_restaurant == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Restaurant Operations'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go(AppRoutes.profile),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadRestaurant,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AppEmptyState(
              icon: Icons.storefront_outlined,
              title: 'No Restaurant Registered',
              description:
                  'You have not registered your restaurant yet. Submit your restaurant profile, cuisine, and food license number to get started.',
              actionLabel: 'Register Restaurant',
              onAction: () => context.go(AppRoutes.restaurantOnboard),
            ),
          ),
        ),
      );
    }

    final rest = _restaurant!;

    return Scaffold(
      appBar: AppBar(
        title: Text(rest.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.profile),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRestaurant,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 800 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Approval Status Banner (SRS REST-2)
                  _buildApprovalBanner(rest),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Operational Availability Card (SRS REST-5)
                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    rest.isOpen
                                        ? Icons.check_circle
                                        : Icons.pause_circle_filled,
                                    color: rest.isOpen
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    rest.isOpen ? 'Accepting Orders' : 'Paused / Closed',
                                    style: AppTypography.title.copyWith(
                                      color: rest.isOpen
                                          ? AppColors.success
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rest.isOpen
                                    ? 'Customers can browse and place orders right now.'
                                    : 'Storefront temporarily paused; orders blocked.',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: rest.isOpen,
                          activeThumbColor: AppColors.success,
                          onChanged: _isTogglingStatus ? null : _handleToggleOpen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Restaurant Information Summary Card
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Restaurant Information', style: AppTypography.title),
                        const Divider(),
                        _buildInfoRow('Cuisine Type', rest.cuisineType, Icons.restaurant),
                        _buildInfoRow('Phone', rest.phone, Icons.phone),
                        _buildInfoRow('Food License (FSSAI)', rest.foodLicenseNumber, Icons.verified_user),
                        _buildInfoRow('Address', rest.address, Icons.location_on),
                        if (rest.description != null && rest.description!.isNotEmpty)
                          _buildInfoRow('Description', rest.description!, Icons.info_outline),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 4. Quick Action Cards (SRS REST-3, REST-4, REST-5, REST-6)
                  const Text('Management Surfaces', style: AppTypography.title),
                  const SizedBox(height: AppSpacing.xs),

                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.menu_book,
                          title: 'Menu Management',
                          subtitle: 'Items, categories & special offers',
                          onTap: () => context.go(AppRoutes.restaurantMenu),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.schedule,
                          title: 'Operating Hours',
                          subtitle: 'Weekly schedule & timing',
                          onTap: () => context.go(AppRoutes.restaurantHours),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalBanner(RestaurantModel rest) {
    switch (rest.approvalStatus) {
      case RestaurantApprovalStatus.approved:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 24),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Verified Partner — Restaurant profile is active and approved by EatFirm administration.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case RestaurantApprovalStatus.rejected:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.error),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 24),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Registration Rejected',
                    style: AppTypography.title.copyWith(color: AppColors.error),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Reason: ${rest.rejectionReason ?? 'Please contact system support to update licensing or details.'}',
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ],
          ),
        );

      case RestaurantApprovalStatus.pendingApproval:
        return Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.warningLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.warning),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_empty, color: AppColors.warning, size: 24),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Pending Admin Verification: Your registration is under review by EatFirm System Administrator (SRS REST-2).',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.label.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.body.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(title, style: AppTypography.title),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
