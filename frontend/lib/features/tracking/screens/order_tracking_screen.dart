import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../auth/models/user_model.dart';
import '../../auth/services/session_manager.dart';
import '../../cart_order/models/order_model.dart';
import '../models/order_tracking_model.dart';
import '../providers/tracking_provider.dart';

/// Screen displaying authoritative order progress, chronological status timeline,
/// real delivery partner GPS telemetry, and 15-second polling updates (SRS TRACK-1..5).
class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final TrackingProvider provider;
  final SessionManager? sessionManager;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.provider,
    this.sessionManager,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.startTracking(widget.orderId);
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

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final tracking = provider.tracking;

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
        title: Text(
          tracking != null
              ? 'Tracking #${tracking.publicOrderNumber}'
              : 'Order Tracking',
        ),
        actions: [
          if (provider.isRefreshing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Status',
              onPressed: () => provider.refreshTracking(),
            ),
        ],
      ),
      body: provider.isLoading && tracking == null
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null && tracking == null
              ? _buildErrorView(provider.errorMessage!)
              : tracking == null
                  ? const Center(child: Text('Order tracking information unavailable'))
                  : _buildTrackingContent(tracking),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.signal_cellular_connected_no_internet_4_bar,
                size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Tracking Unavailable', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              error,
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 160,
              child: AppButton(
                label: 'Retry Connection',
                onPressed: () => widget.provider.startTracking(widget.orderId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingContent(OrderTrackingModel tracking) {
    final provider = widget.provider;

    return RefreshIndicator(
      onRefresh: () => provider.refreshTracking(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Resilient Offline/Delayed Notice (TRK-05)
            if (provider.isOffline) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: AppRadius.brMd,
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: AppColors.warning, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Updates delayed due to network connectivity. Displaying last verified state.',
                        style: AppTypography.caption.copyWith(color: AppColors.neutral800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => provider.refreshTracking(),
                      child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Main Status Header Card
            _buildStatusHeaderCard(tracking),
            const SizedBox(height: AppSpacing.md),

            // 3. Chronological Status Timeline (TRK-01)
            _buildTimelineCard(tracking),
            const SizedBox(height: AppSpacing.md),

            // 4. Real Location Telemetry Card (TRK-04)
            _buildLocationTelemetryCard(tracking),
            const SizedBox(height: AppSpacing.md),

            // 5. Delivery Partner Card
            _buildDeliveryPartnerCard(tracking),
            const SizedBox(height: AppSpacing.md),

            // 6. Role-Restricted Status Transition Controls (TRK-02)
            _buildOperationalControls(tracking),

            // 7. Navigation Actions (Invoice & Details)
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'View Order Details',
                    variant: AppButtonVariant.outline,
                    icon: const Icon(Icons.list_alt, size: 18),
                    onPressed: () => context.push('/orders/${tracking.orderId}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(
                    label: 'Tax Invoice',
                    variant: AppButtonVariant.outline,
                    icon: const Icon(Icons.receipt, size: 18),
                    onPressed: () => context.push(AppRoutes.orderInvoicePath(tracking.orderId)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeaderCard(OrderTrackingModel tracking) {
    Color badgeColor;
    IconData statusIcon;
    String statusTitle;
    String statusDescription;

    switch (tracking.fulfillmentStatus) {
      case OrderFulfillmentStatus.placed:
        badgeColor = AppColors.info;
        statusIcon = Icons.hourglass_top;
        statusTitle = 'Order Received';
        statusDescription = 'Your order has been placed and forwarded to ${tracking.restaurantName}.';
        break;
      case OrderFulfillmentStatus.confirmed:
        badgeColor = AppColors.primary;
        statusIcon = Icons.thumb_up_alt_outlined;
        statusTitle = 'Order Confirmed';
        statusDescription = '${tracking.restaurantName} confirmed your order and is queuing preparation.';
        break;
      case OrderFulfillmentStatus.preparing:
        badgeColor = AppColors.warning;
        statusIcon = Icons.soup_kitchen;
        statusTitle = 'Preparing in Kitchen';
        statusDescription = 'The chef is currently preparing your meal fresh.';
        break;
      case OrderFulfillmentStatus.outForDelivery:
        badgeColor = Colors.purple;
        statusIcon = Icons.delivery_dining;
        statusTitle = 'Out for Delivery';
        statusDescription = 'Your food has been picked up and is on its way to your location.';
        break;
      case OrderFulfillmentStatus.delivered:
        badgeColor = AppColors.veg;
        statusIcon = Icons.check_circle;
        statusTitle = 'Order Delivered';
        statusDescription = 'Enjoy your food! Your order was completed successfully.';
        break;
      case OrderFulfillmentStatus.cancelled:
        badgeColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusTitle = 'Order Cancelled';
        statusDescription = 'This order has been cancelled.';
        break;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(statusIcon, color: badgeColor, size: 30),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(statusTitle, style: AppTypography.h3),
                    const SizedBox(height: 2),
                    Text(
                      'Order #${tracking.publicOrderNumber}',
                      style: AppTypography.caption.copyWith(color: AppColors.neutral600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  tracking.fulfillmentStatus.toApiString,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(statusDescription, style: AppTypography.body),
          const Divider(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Auto-refreshes every 15s',
                style: AppTypography.caption.copyWith(color: AppColors.neutral500),
              ),
              Text(
                'Updated: ${AppDateFormatter.formatDateTime(tracking.lastFetchedAt)}',
                style: AppTypography.caption.copyWith(color: AppColors.neutral500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard(OrderTrackingModel tracking) {
    final stages = [
      {'status': OrderFulfillmentStatus.placed, 'label': 'Order Placed'},
      {'status': OrderFulfillmentStatus.confirmed, 'label': 'Order Confirmed'},
      {'status': OrderFulfillmentStatus.preparing, 'label': 'Preparing Food'},
      {'status': OrderFulfillmentStatus.outForDelivery, 'label': 'Out for Delivery'},
      {'status': OrderFulfillmentStatus.delivered, 'label': 'Delivered'},
    ];

    final isCancelled = tracking.fulfillmentStatus == OrderFulfillmentStatus.cancelled;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Progress Timeline', style: AppTypography.title),
              const Icon(Icons.timeline, color: AppColors.primary, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isCancelled) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: AppRadius.brMd,
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: AppColors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Order was cancelled before fulfillment completed.',
                      style: AppTypography.body.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stages.length,
              separatorBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(left: 17),
                width: 2,
                height: 24,
                color: _isStepReached(tracking, stages[index]['status'] as OrderFulfillmentStatus)
                    ? AppColors.veg
                    : AppColors.neutral300,
              ),
              itemBuilder: (context, index) {
                final stage = stages[index];
                final stageStatus = stage['status'] as OrderFulfillmentStatus;
                final isReached = _isStepReached(tracking, stageStatus);
                final isCurrent = tracking.fulfillmentStatus == stageStatus;

                // Match with event in chronological statusTimeline if present
                final event = tracking.statusTimeline.cast<OrderStatusEventModel?>().firstWhere(
                      (e) => e?.toStatus == stageStatus.toApiString,
                      orElse: () => null,
                    );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isReached
                            ? (isCurrent ? AppColors.primary : AppColors.veg)
                            : AppColors.neutral200,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isReached
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: AppColors.neutral600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage['label'] as String,
                            style: AppTypography.body.copyWith(
                              fontWeight: isCurrent || isReached ? FontWeight.bold : FontWeight.normal,
                              color: isReached ? AppColors.textPrimary : AppColors.neutral500,
                            ),
                          ),
                          if (event != null && event.createdAt != null) ...[
                            Text(
                              AppDateFormatter.formatDateTime(event.createdAt!),
                              style: AppTypography.caption.copyWith(color: AppColors.neutral500),
                            ),
                            if (event.note != null && event.note!.isNotEmpty) ...[
                              Text(
                                event.note!,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.neutral600,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  bool _isStepReached(OrderTrackingModel tracking, OrderFulfillmentStatus step) {
    const order = [
      OrderFulfillmentStatus.placed,
      OrderFulfillmentStatus.confirmed,
      OrderFulfillmentStatus.preparing,
      OrderFulfillmentStatus.outForDelivery,
      OrderFulfillmentStatus.delivered,
    ];
    final currentIdx = order.indexOf(tracking.fulfillmentStatus);
    final stepIdx = order.indexOf(step);
    if (currentIdx == -1 || stepIdx == -1) return false;
    return currentIdx >= stepIdx;
  }

  Widget _buildLocationTelemetryCard(OrderTrackingModel tracking) {
    final location = tracking.latestLocation;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Partner Telemetry', style: AppTypography.title),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: location != null
                      ? AppColors.veg.withValues(alpha: 0.15)
                      : AppColors.neutral200,
                  borderRadius: AppRadius.brSm,
                ),
                child: Text(
                  location != null ? 'REAL GPS ACTIVE' : 'TELEMETRY PENDING',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: location != null ? AppColors.veg : AppColors.neutral600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (location != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: AppRadius.brMd,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: AppColors.primary, size: 22),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                          style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTelemetryItem(
                        'Heading',
                        location.headingDegrees != null ? '${location.headingDegrees!.toStringAsFixed(0)}°' : 'N/A',
                      ),
                      _buildTelemetryItem(
                        'Speed',
                        location.speedMetersPerSec != null ? '${location.speedMetersPerSec!.toStringAsFixed(1)} m/s' : 'N/A',
                      ),
                      _buildTelemetryItem(
                        'Accuracy',
                        location.accuracyMeters != null ? '±${location.accuracyMeters!.toStringAsFixed(0)}m' : 'Standard',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Recorded at: ${AppDateFormatter.formatDateTime(location.recordedAt)}',
                    style: AppTypography.caption.copyWith(color: AppColors.neutral500),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: AppRadius.brMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_off, color: AppColors.neutral500, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Live telemetry is broadcast once the delivery partner picks up the order and activates GPS.',
                      style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption.copyWith(color: AppColors.neutral500)),
        Text(value, style: AppTypography.bodySmall.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDeliveryPartnerCard(OrderTrackingModel tracking) {
    final partner = tracking.assignedDeliveryPartner;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Delivery Partner', style: AppTypography.title),
          const SizedBox(height: AppSpacing.sm),
          if (partner != null) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(partner.name, style: AppTypography.body.copyWith(fontWeight: FontWeight.bold)),
                      Text(partner.phone, style: AppTypography.caption.copyWith(color: AppColors.neutral600)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.primary),
                  tooltip: 'Contact Partner',
                  onPressed: () {
                    AppSnackbar.showInfo(context, 'Contacting ${partner.name}: ${partner.phone}');
                  },
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.two_wheeler, color: AppColors.neutral400, size: 24),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'A delivery partner will be assigned once kitchen preparation completes.',
                    style: AppTypography.bodySmall.copyWith(color: AppColors.neutral600),
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: AppSpacing.lg),
          Text('Delivery Address', style: AppTypography.caption.copyWith(color: AppColors.neutral500)),
          const SizedBox(height: 2),
          Text(tracking.deliveryAddress, style: AppTypography.bodySmall),
        ],
      ),
    );
  }

  Widget _buildOperationalControls(OrderTrackingModel tracking) {
    final role = widget.sessionManager?.role;
    if (role != UserRole.deliveryPartner && role != UserRole.restaurantAdmin && role != UserRole.systemAdmin) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: AppColors.secondary, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Text('Operational Actions ($role)', style: AppTypography.title),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (role == UserRole.deliveryPartner || role == UserRole.systemAdmin) ...[
            if (tracking.fulfillmentStatus == OrderFulfillmentStatus.preparing) ...[
              AppButton(
                label: 'Pick Up Order (Mark Out for Delivery)',
                icon: const Icon(Icons.delivery_dining, size: 18),
                onPressed: () => _handleStatusUpdate('OUT_FOR_DELIVERY', 'Picked up by partner'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (tracking.fulfillmentStatus == OrderFulfillmentStatus.outForDelivery) ...[
              AppButton(
                label: 'Complete Handover (Mark Delivered)',
                icon: const Icon(Icons.check_circle_outline, size: 18),
                onPressed: () => _handleStatusUpdate('DELIVERED', 'Handed over to customer'),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Broadcast Current GPS Telemetry',
                variant: AppButtonVariant.outline,
                icon: const Icon(Icons.my_location, size: 18),
                onPressed: _handleBroadcastLocation,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
          if (role == UserRole.restaurantAdmin || role == UserRole.systemAdmin) ...[
            if (tracking.fulfillmentStatus == OrderFulfillmentStatus.placed) ...[
              AppButton(
                label: 'Accept & Confirm Order',
                icon: const Icon(Icons.check, size: 18),
                onPressed: () => _handleStatusUpdate('CONFIRMED', 'Kitchen accepted order'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (tracking.fulfillmentStatus == OrderFulfillmentStatus.confirmed) ...[
              AppButton(
                label: 'Start Preparing Food',
                icon: const Icon(Icons.soup_kitchen, size: 18),
                onPressed: () => _handleStatusUpdate('PREPARING', 'Food in preparation'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _handleStatusUpdate(String newStatus, String defaultNote) async {
    final success = await widget.provider.updateStatus(newStatus, note: defaultNote);
    if (mounted) {
      if (success) {
        AppSnackbar.showSuccess(context, 'Status updated to $newStatus');
      } else {
        AppSnackbar.showError(
          context,
          widget.provider.errorMessage ?? 'Failed to update status',
        );
      }
    }
  }

  Future<void> _handleBroadcastLocation() async {
    // Transmit realistic telemetry sample
    final success = await widget.provider.recordTelemetryLocation(
      latitude: 12.9716,
      longitude: 77.5946,
      headingDegrees: 180.0,
      speedMetersPerSec: 10.2,
      accuracyMeters: 4.5,
    );
    if (mounted) {
      if (success) {
        AppSnackbar.showSuccess(context, 'Live GPS telemetry transmitted');
      } else {
        AppSnackbar.showError(
          context,
          widget.provider.errorMessage ?? 'Failed to transmit GPS location',
        );
      }
    }
  }
}
