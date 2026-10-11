import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/restaurant_model.dart';
import '../services/restaurant_api_service.dart';

/// Screen for System Administrator to review, approve, or reject new restaurant registrations (SRS REST-2).
class AdminApprovalScreen extends StatefulWidget {
  final RestaurantApiService restaurantService;

  const AdminApprovalScreen({
    super.key,
    required this.restaurantService,
  });

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<RestaurantModel> _pendingRestaurants = [];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await widget.restaurantService.listPendingRestaurants();
      if (mounted) {
        setState(() {
          _pendingRestaurants = list;
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

  Future<void> _handleApprove(RestaurantModel restaurant) async {
    try {
      await widget.restaurantService.approveRestaurant(restaurant.id);
      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          '${restaurant.name} has been APPROVED successfully (SRS REST-2).',
        );
        _loadPending();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Approval failed: $e');
      }
    }
  }

  Future<void> _handleReject(RestaurantModel restaurant) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Registration: ${restaurant.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a specific reason for rejection (e.g. invalid license, unreachable address):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                hintText: 'Enter reason for restaurant owner...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (reasonController.text.trim().length >= 3) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Confirm Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        await widget.restaurantService.rejectRestaurant(
          restaurant.id,
          reasonController.text.trim(),
        );
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            '${restaurant.name} has been REJECTED.',
          );
          _loadPending();
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Rejection failed: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator(message: 'Loading pending approvals...')),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Restaurant Approvals')),
        body: Center(
          child: AppErrorState(
            message: _errorMessage!,
            onRetry: _loadPending,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Approvals (System Admin)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.profile),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPending,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 800 : double.infinity,
            ),
            child: _pendingRestaurants.isEmpty
                ? const AppEmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No Pending Approvals',
                    description:
                        'All restaurant registration submissions have been reviewed and processed.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _pendingRestaurants.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return _buildRestaurantCard(_pendingRestaurants[index]);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(RestaurantModel r) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(r.name, style: AppTypography.title),
              ),
              const AppBadge(
                label: 'Awaiting Approval',
                type: AppBadgeType.warning,
                icon: Icons.hourglass_top,
              ),
            ],
          ),
          const Divider(),
          _buildDetailRow('Cuisine Type', r.cuisineType, Icons.restaurant),
          _buildDetailRow('Contact Phone', r.phone, Icons.phone),
          _buildDetailRow('Food License (FSSAI)', r.foodLicenseNumber, Icons.verified_user),
          _buildDetailRow('Address', r.address, Icons.location_on),
          if (r.description != null && r.description!.isNotEmpty)
            _buildDetailRow('Description', r.description!, Icons.info_outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                label: 'Reject',
                variant: AppButtonVariant.destructive,
                isFullWidth: false,
                icon: const Icon(Icons.cancel, size: 18, color: Colors.white),
                onPressed: () => _handleReject(r),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: 'Approve',
                variant: AppButtonVariant.primary,
                isFullWidth: false,
                icon: const Icon(Icons.check_circle, size: 18, color: Colors.white),
                onPressed: () => _handleApprove(r),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
