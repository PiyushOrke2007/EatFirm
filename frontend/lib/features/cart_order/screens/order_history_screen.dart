import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/order_model.dart';
import '../providers/cart_order_provider.dart';

/// Customer order history list screen adhering to SRS ORD-07.
class OrderHistoryScreen extends StatefulWidget {
  final CartOrderProvider provider;

  const OrderHistoryScreen({super.key, required this.provider});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadOrders();
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  Color _getStatusColor(OrderFulfillmentStatus status) {
    switch (status) {
      case OrderFulfillmentStatus.placed:
        return AppColors.info;
      case OrderFulfillmentStatus.confirmed:
        return AppColors.primary;
      case OrderFulfillmentStatus.preparing:
        return AppColors.warning;
      case OrderFulfillmentStatus.outForDelivery:
        return Colors.purple;
      case OrderFulfillmentStatus.delivered:
        return AppColors.veg;
      case OrderFulfillmentStatus.cancelled:
        return AppColors.neutral500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.discovery);
            }
          },
        ),
        title: const Text('My Orders'),
      ),
      body: provider.isLoadingOrders
          ? const Center(child: CircularProgressIndicator())
          : provider.ordersError != null && provider.orders.isEmpty
              ? _buildErrorView(provider.ordersError!)
              : provider.orders.isEmpty
                  ? _buildEmptyView()
                  : RefreshIndicator(
                      onRefresh: () => widget.provider.loadOrders(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: provider.orders.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final order = provider.orders[index];
                          return _buildOrderCard(order);
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 46,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('No orders yet', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Your past orders will appear here once you place an order.',
              style: AppTypography.caption.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: AppButton(
                label: 'Order Food Now',
                onPressed: () => context.go(AppRoutes.discovery),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load orders', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(error, style: AppTypography.caption, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 140,
              child: AppButton(
                label: 'Retry',
                onPressed: () => widget.provider.loadOrders(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _getStatusColor(order.fulfillmentStatus);
    final itemsSummary = order.items
        .map((i) => '${i.itemName} × ${i.quantity}')
        .join(', ');

    return AppCard(
      onTap: () => context.push('/orders/${order.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant & Status Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  order.fulfillmentStatus.displayLabel,
                  style: AppTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#${order.publicOrderNumber}',
            style: AppTypography.caption.copyWith(color: AppColors.neutral500),
          ),
          const Divider(height: AppSpacing.md),

          // Dishes summary
          Text(
            itemsSummary,
            style: AppTypography.body.copyWith(color: AppColors.neutral700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Total & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDate(order.createdAt),
                style: AppTypography.caption.copyWith(color: AppColors.neutral500),
              ),
              Text(
                '₹${order.totalAmount}',
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
