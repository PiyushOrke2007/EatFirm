import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/session_manager.dart';
import '../../payment_invoice/providers/payment_invoice_provider.dart';
import '../models/order_model.dart';
import '../providers/cart_order_provider.dart';

/// Screen displaying complete authoritative order details, immutable snapshots,
/// lifecycle status timeline, and cancellation options (SRS ORD-05..08, NFR-14, NFR-16, Section 6).
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final CartOrderProvider provider;
  final PaymentInvoiceProvider? paymentProvider;
  final SessionManager? sessionManager;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    required this.provider,
    this.paymentProvider,
    this.sessionManager,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final TextEditingController _cancelReasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);
    widget.paymentProvider?.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadOrderDetail(widget.orderId);
      widget.paymentProvider?.fetchPayment(widget.orderId);
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    widget.paymentProvider?.removeListener(_onProviderUpdate);
    _cancelReasonController.dispose();
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
        return AppColors.error;
    }
  }

  Future<void> _showCancelDialog() async {
    _cancelReasonController.clear();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to cancel this order? Once cancelled, this action cannot be undone.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _cancelReasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for cancellation',
                hintText: 'e.g., Placed by mistake, delay, etc.',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              if (_cancelReasonController.text.trim().length < 3) {
                AppSnackbar.showError(ctx, 'Please provide a valid cancellation reason');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.provider.cancelOrder(
          widget.orderId,
          _cancelReasonController.text.trim(),
        );
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Order successfully cancelled');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to cancel order: $e');
        }
      }
    }
  }

  Future<void> _handleRecordCashCollection() async {
    final payProvider = widget.paymentProvider;
    if (payProvider == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record Cash Collection'),
        content: const Text(
          'Confirm that you have collected the cash from the customer for this order.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.veg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cash Received'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await payProvider.recordCollection(widget.orderId);
      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(context, 'Cash collection recorded successfully');
          widget.provider.loadOrderDetail(widget.orderId);
        } else {
          AppSnackbar.showError(
            context,
            payProvider.collectionError ?? 'Failed to record cash collection',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final order = provider.currentOrder;

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
        title: Text(order != null ? '#${order.publicOrderNumber}' : 'Order Details'),
      ),
      body: provider.isLoadingOrderDetail
          ? const Center(child: CircularProgressIndicator())
          : provider.orderDetailError != null && order == null
              ? _buildErrorView(provider.orderDetailError!)
              : order == null
                  ? const Center(child: Text('Order not found'))
                  : _buildOrderContent(order),
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
            Text('Could not load order details', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(error, style: AppTypography.caption, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 140,
              child: AppButton(
                label: 'Retry',
                onPressed: () => widget.provider.loadOrderDetail(widget.orderId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderContent(OrderModel order) {
    final statusColor = _getStatusColor(order.fulfillmentStatus);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Status Banner
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  order.fulfillmentStatus == OrderFulfillmentStatus.cancelled
                      ? Icons.cancel_outlined
                      : order.fulfillmentStatus == OrderFulfillmentStatus.delivered
                          ? Icons.check_circle_outline
                          : Icons.access_time_filled,
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.fulfillmentStatus.displayLabel,
                        style: AppTypography.title.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        order.fulfillmentStatus == OrderFulfillmentStatus.cancelled
                            ? 'Reason: ${order.cancellationReason ?? 'Not specified'}'
                            : 'Placed on ${_formatDateTime(order.createdAt)}',
                        style: AppTypography.caption.copyWith(color: AppColors.neutral700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 2. Restaurant & Delivery Details Card (ORD-05)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        order.restaurantName,
                        style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Text(
                  order.restaurantAddress,
                  style: AppTypography.caption.copyWith(color: AppColors.neutral500),
                ),
                const Divider(height: AppSpacing.lg),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Delivery Address Snapshot',
                      style: AppTypography.caption.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  order.deliveryAddressSnapshot,
                  style: AppTypography.body,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Contact: ${order.customerNameSnapshot} (${order.customerPhoneSnapshot})',
                  style: AppTypography.caption.copyWith(color: AppColors.neutral600),
                ),
                if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Notes: ${order.specialInstructions}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 3. Line Items Snapshot (ORD-05, NFR-12)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items Ordered (${order.items.length})',
                  style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.sm),
                ...order.items.map((item) => _buildItemRow(item)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 4. Status History Timeline (ORD-06, NFR-16)
          if (order.statusTimeline.isNotEmpty) ...[
            _buildTimelineCard(order),
            const SizedBox(height: AppSpacing.md),
          ],

          // 5. Bill Summary Card (ORDER-1, NFR-13)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bill Summary',
                  style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal', style: AppTypography.body),
                    Text('₹${order.subtotal}', style: AppTypography.body),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Delivery Fee', style: AppTypography.body),
                    Text(
                      order.deliveryFeeDouble == 0.0 ? 'FREE' : '₹${order.deliveryFee}',
                      style: AppTypography.body.copyWith(
                        color: order.deliveryFeeDouble == 0.0 ? AppColors.veg : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Taxes (GST 5%)', style: AppTypography.body),
                    Text('₹${order.taxAmount}', style: AppTypography.body),
                  ],
                ),
                const Divider(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₹${order.totalAmount}',
                      style: AppTypography.h3.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Payment: ${order.paymentMethod} (${order.paymentStatus.name.toUpperCase()})',
                  style: AppTypography.caption.copyWith(color: AppColors.neutral500),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 6. Payment & Tax Invoicing Card (SRS PAY-01..05)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment & Invoicing',
                      style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: order.paymentStatus == OrderPaymentStatus.paid
                            ? AppColors.veg.withAlpha(40)
                            : order.paymentStatus == OrderPaymentStatus.failed
                                ? AppColors.nonVeg.withAlpha(40)
                                : AppColors.warning.withAlpha(40),
                        borderRadius: AppRadius.brSm,
                      ),
                      child: Text(
                        order.paymentStatus == OrderPaymentStatus.paid
                            ? 'PAID'
                            : order.paymentStatus == OrderPaymentStatus.failed
                                ? 'FAILED'
                                : 'DUE (COD)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: order.paymentStatus == OrderPaymentStatus.paid
                              ? AppColors.veg
                              : order.paymentStatus == OrderPaymentStatus.failed
                                  ? AppColors.nonVeg
                                  : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  order.paymentStatus == OrderPaymentStatus.paid
                      ? 'Payment collected in full via Cash on Delivery.'
                      : order.paymentStatus == OrderPaymentStatus.failed
                          ? 'Order was cancelled; payment marked void.'
                          : 'Cash to be collected upon order delivery at doorstep.',
                  style: AppTypography.caption.copyWith(color: AppColors.neutral700),
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'View Tax Invoice',
                  variant: AppButtonVariant.outline,
                  icon: const Icon(Icons.receipt_long, size: 18),
                  onPressed: () {
                    context.push(AppRoutes.orderInvoicePath(order.id));
                  },
                ),
                if ((widget.sessionManager?.role == UserRole.deliveryPartner ||
                        widget.sessionManager?.role == UserRole.systemAdmin) &&
                    order.paymentStatus != OrderPaymentStatus.paid &&
                    order.paymentStatus != OrderPaymentStatus.failed) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Record Cash Collection',
                    variant: AppButtonVariant.primary,
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    isLoading: widget.paymentProvider?.isCollecting ?? false,
                    onPressed: (widget.paymentProvider?.isCollecting ?? false)
                        ? null
                        : _handleRecordCashCollection,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 6. Actions (ORD-07, ORD-08, NFR-14)
          if (order.fulfillmentStatus.isCancellable) ...[
            AppButton(
              label: 'Cancel Order',
              variant: AppButtonVariant.destructive,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              isLoading: widget.provider.isCancellingOrder,
              onPressed: widget.provider.isCancellingOrder ? null : _showCancelDialog,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Orders can be cancelled before kitchen preparation begins.',
              style: AppTypography.caption.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            AppButton(
              label: 'Order Again',
              variant: AppButtonVariant.primary,
              icon: const Icon(Icons.replay, size: 18),
              onPressed: () {
                context.push('${AppRoutes.restaurantDetails}/${order.restaurantId}');
              },
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${item.unitPrice} × ${item.quantity}',
                  style: AppTypography.caption.copyWith(color: AppColors.neutral600),
                ),
                if (item.itemInstructions != null && item.itemInstructions!.isNotEmpty)
                  Text(
                    'Note: ${item.itemInstructions}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '₹${item.lineTotal}',
            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(OrderModel order) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.primary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Status Timeline',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...order.statusTimeline.asMap().entries.map((entry) {
            final idx = entry.key;
            final event = entry.value;
            final isLast = idx == order.statusTimeline.length - 1;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            OrderFulfillmentStatus.fromString(event.toStatus),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: AppColors.border,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            OrderFulfillmentStatus.fromString(event.toStatus).displayLabel,
                            style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (event.note != null && event.note!.isNotEmpty)
                            Text(
                              event.note!,
                              style: AppTypography.caption.copyWith(color: AppColors.neutral600),
                            ),
                          if (event.createdAt != null)
                            Text(
                              _formatDateTime(event.createdAt!),
                              style: AppTypography.caption.copyWith(color: AppColors.neutral400),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

