import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../models/order_model.dart';
import '../providers/cart_order_provider.dart';

/// Screen celebrating and confirming successful order placement (SRS ORDER-4).
class OrderConfirmationScreen extends StatefulWidget {
  final String orderId;
  final CartOrderProvider provider;

  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.provider,
  });

  @override
  State<OrderConfirmationScreen> createState() => _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  OrderModel? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    // If provider already has currentOrder with matching ID
    if (widget.provider.currentOrder?.id == widget.orderId) {
      setState(() {
        _order = widget.provider.currentOrder;
        _isLoading = false;
      });
      return;
    }

    try {
      await widget.provider.loadOrderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = widget.provider.currentOrder;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final order = _order;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go(AppRoutes.discovery);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Order Placed'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Celebratory icon badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.veg.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 64,
                    color: AppColors.veg,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Order Placed Successfully!',
                  style: AppTypography.h2,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Your order has been sent to the restaurant kitchen.',
                  style: AppTypography.body.copyWith(color: AppColors.neutral600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                if (order != null) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Order Number', style: AppTypography.caption),
                            Text(
                              order.publicOrderNumber,
                              style: AppTypography.body.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Restaurant', style: AppTypography.caption),
                            Text(
                              order.restaurantName,
                              style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount', style: AppTypography.caption),
                            Text(
                              '₹${order.totalAmount}',
                              style: AppTypography.title.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payment Method', style: AppTypography.caption),
                            Text(
                              'Cash on Delivery',
                              style: AppTypography.body.copyWith(color: AppColors.neutral700),
                            ),
                          ],
                        ),
                        if (order.isScheduled && order.scheduledFor != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Scheduled Delivery', style: AppTypography.caption),
                              Text(
                                '${order.scheduledFor!.day}/${order.scheduledFor!.month} ${order.scheduledFor!.hour}:${order.scheduledFor!.minute.toString().padLeft(2, '0')}',
                                style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],

                // Action buttons
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'View Order Details & Status',
                    icon: const Icon(Icons.receipt_long, size: 20),
                    onPressed: () => context.go('/orders/${widget.orderId}'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: 'Back to Restaurants',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.go(AppRoutes.discovery),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
