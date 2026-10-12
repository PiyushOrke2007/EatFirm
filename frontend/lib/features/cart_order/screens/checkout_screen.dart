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
import '../../auth/services/session_manager.dart';
import '../models/cart_model.dart';
import '../providers/cart_order_provider.dart';

/// Checkout and Order Placement screen adhering to SRS ORDER-1..4, NFR-13.
class CheckoutScreen extends StatefulWidget {
  final CartOrderProvider provider;
  final SessionManager sessionManager;

  const CheckoutScreen({
    super.key,
    required this.provider,
    required this.sessionManager,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  bool _isScheduled = false;
  DateTime? _scheduledDateTime;
  String _paymentMethod = 'CASH_ON_DELIVERY';
  String? _idempotencyKey;

  @override
  void initState() {
    super.initState();
    final user = widget.sessionManager.currentUser;
    if (user != null) {
      _nameController.text = user.name;
      if (user.phone != null && user.phone!.isNotEmpty) {
        _phoneController.text = user.phone!;
      }
    }
    final instructions = widget.provider.cart?.specialInstructions;
    if (instructions != null && instructions.isNotEmpty) {
      _instructionsController.text = instructions;
    }
    _idempotencyKey = widget.provider.generateIdempotencyKey();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickScheduleTime() async {
    final now = DateTime.now();
    final initialDate = now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(now.add(const Duration(minutes: 30)))) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          'Scheduled time must be at least 30 minutes in the future',
        );
      }
      return;
    }

    setState(() {
      _scheduledDateTime = combined;
    });
  }

  Future<void> _handlePlaceOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isScheduled && _scheduledDateTime == null) {
      AppSnackbar.showError(context, 'Please select a delivery date and time');
      return;
    }

    final key = _idempotencyKey ?? widget.provider.generateIdempotencyKey();

    try {
      final order = await widget.provider.placeOrder(
        deliveryAddress: _addressController.text.trim(),
        customerPhone: _phoneController.text.trim(),
        customerName: _nameController.text.trim(),
        specialInstructions: _instructionsController.text.trim(),
        isScheduled: _isScheduled,
        scheduledFor: _scheduledDateTime,
        idempotencyKey: key,
      );

      if (mounted) {
        // Navigate to Order Confirmation
        context.go('/orders/confirmation/${order.id}');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Order placement failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.provider.cart;

    if (cart == null || cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart_outlined, size: 60, color: AppColors.neutral400),
              const SizedBox(height: AppSpacing.md),
              Text('Your cart is empty', style: AppTypography.h3),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Go to Menu',
                onPressed: () => context.go(AppRoutes.discovery),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Checkout'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Delivery Address Card
              _buildAddressCard(),
              const SizedBox(height: AppSpacing.md),

              // 2. Contact Details Card
              _buildContactCard(),
              const SizedBox(height: AppSpacing.md),

              // 3. Delivery Timing Card (ORDER-3)
              _buildDeliveryTimingCard(),
              const SizedBox(height: AppSpacing.md),

              // 4. Payment Method Card (ORDER-4)
              _buildPaymentMethodCard(),
              const SizedBox(height: AppSpacing.md),

              // 5. Order Summary Card (ORDER-1, NFR-13)
              _buildOrderSummaryCard(cart),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomPlaceOrderBar(cart),
    );
  }

  Widget _buildAddressCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Delivery Address',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _addressController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter complete delivery address (Flat, Building, Street, Area)',
              hintStyle: AppTypography.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.sm),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 5) {
                return 'Please enter a valid address (minimum 5 characters)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Contact Information',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Recipient Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12),
            ),
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Please enter recipient name';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '10-digit mobile number',
              prefixText: '+91 ',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 12),
            ),
            validator: (value) {
              if (value == null || !RegExp(r'^\d{10}$').hasMatch(value.trim())) {
                return 'Please enter a valid 10-digit mobile number';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryTimingCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time_filled, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Delivery Timing',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RadioListTile<bool>(
            value: false,
            groupValue: _isScheduled,
            onChanged: (val) => setState(() => _isScheduled = val!),
            title: const Text('Immediate Delivery'),
            subtitle: const Text('Delivered in approximately 30-45 minutes'),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<bool>(
            value: true,
            groupValue: _isScheduled,
            onChanged: (val) => setState(() => _isScheduled = val!),
            title: const Text('Schedule for Later'),
            subtitle: Text(
              _scheduledDateTime != null
                  ? 'Scheduled: ${_formatDateTime(_scheduledDateTime!)}'
                  : 'Select a preferred delivery window',
            ),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          if (_isScheduled) ...[
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              onPressed: _pickScheduleTime,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(_scheduledDateTime == null ? 'Select Date & Time' : 'Change Date & Time'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPaymentMethodCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, color: AppColors.primary, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Payment Method',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          RadioListTile<String>(
            value: 'CASH_ON_DELIVERY',
            groupValue: _paymentMethod,
            onChanged: (val) => setState(() => _paymentMethod = val!),
            title: const Text('Cash on Delivery (COD)'),
            subtitle: const Text('Pay via cash or UPI to the delivery executive upon arrival'),
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(CartModel cart) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Breakdown',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item.name} × ${item.quantity}',
                    style: AppTypography.body,
                  ),
                  Text('₹${item.lineTotal}', style: AppTypography.body),
                ],
              ),
            ),
          ),
          const Divider(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal', style: AppTypography.caption),
              Text('₹${cart.subtotal}', style: AppTypography.caption),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Delivery Fee', style: AppTypography.caption),
              Text(
                cart.deliveryFeeDouble == 0.0 ? 'FREE' : '₹${cart.deliveryFee}',
                style: AppTypography.caption.copyWith(
                  color: cart.deliveryFeeDouble == 0.0 ? AppColors.veg : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Taxes (GST 5%)', style: AppTypography.caption),
              Text('₹${cart.taxAmount}', style: AppTypography.caption),
            ],
          ),
          const Divider(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Payable',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '₹${cart.totalAmount}',
                style: AppTypography.h3.copyWith(
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

  Widget _buildBottomPlaceOrderBar(CartModel cart) {
    final isPlacing = widget.provider.isPlacingOrder;

    return Material(
      color: Colors.white,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYABLE (COD)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral500,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${cart.totalAmount}',
                    style: AppTypography.h3.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton(
                  label: 'Confirm Order',
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  isLoading: isPlacing,
                  onPressed: isPlacing ? null : _handlePlaceOrder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

