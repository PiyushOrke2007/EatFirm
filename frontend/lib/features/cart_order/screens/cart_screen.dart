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
import '../models/cart_model.dart';
import '../providers/cart_order_provider.dart';

/// Customer shopping cart screen adhering to SRS CART-1, CART-2, ORDER-1, NFR-12, NFR-13.
class CartScreen extends StatefulWidget {
  final CartOrderProvider provider;

  const CartScreen({super.key, required this.provider});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSavingNotes = false;

  @override
  void initState() {
    super.initState();
    widget.provider.addListener(_onProviderUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.provider.loadCart();
    });
  }

  @override
  void dispose() {
    widget.provider.removeListener(_onProviderUpdate);
    _notesController.dispose();
    super.dispose();
  }

  void _onProviderUpdate() {
    if (mounted) {
      final instructions = widget.provider.cart?.specialInstructions;
      if (instructions != null && _notesController.text.isEmpty) {
        _notesController.text = instructions;
      }
      setState(() {});
    }
  }

  Future<void> _saveNotes() async {
    setState(() => _isSavingNotes = true);
    try {
      await widget.provider.updateSpecialInstructions(_notesController.text.trim());
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Cooking instructions saved');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to save instructions: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingNotes = false);
      }
    }
  }

  Future<void> _confirmClearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Shopping Cart?'),
        content: const Text(
          'Are you sure you want to remove all items from your cart? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.provider.clearCart();
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Cart cleared');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to clear cart: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    final cart = provider.cart;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Cart'),
        actions: [
          if (cart != null && cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear Cart',
              onPressed: _confirmClearCart,
            ),
        ],
      ),
      body: provider.isLoadingCart
          ? const Center(child: CircularProgressIndicator())
          : provider.cartError != null && cart == null
              ? _buildErrorView(provider.cartError!)
              : cart == null || cart.items.isEmpty
                  ? _buildEmptyView()
                  : _buildCartContent(cart),
      bottomNavigationBar: cart != null && cart.items.isNotEmpty
          ? _buildBottomCheckoutBar(cart)
          : null,
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                size: 54,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Your cart is empty',
              style: AppTypography.h2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Explore delicious restaurants and add items to begin your order.',
              style: AppTypography.body.copyWith(color: AppColors.neutral500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 220,
              child: AppButton(
                label: 'Explore Restaurants',
                icon: const Icon(Icons.search, size: 20),
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
            const Icon(Icons.error_outline, size: 56, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Could not load cart', style: AppTypography.h3),
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
                label: 'Retry',
                onPressed: () => widget.provider.loadCart(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(CartModel cart) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Restaurant Header Card
          _buildRestaurantHeader(cart),
          const SizedBox(height: AppSpacing.md),

          // 2. Cart Items Card
          _buildItemsCard(cart),
          const SizedBox(height: AppSpacing.md),

          // 3. Chef Cooking Instructions Card (SRS CART-2)
          _buildCookingInstructionsCard(),
          const SizedBox(height: AppSpacing.md),

          // 4. Bill Details Breakdown Card (SRS ORDER-1, NFR-13)
          _buildBillDetailsCard(cart),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader(CartModel cart) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.restaurant,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cart.restaurantName,
                  style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cart.restaurantAddress,
                  style: AppTypography.caption.copyWith(color: AppColors.neutral500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsCard(CartModel cart) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items (${cart.itemCount})',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          ...cart.items.map((item) => _buildCartItemRow(item)),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(CartItemModel item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dietary Veg / Non-Veg Indicator (SRS NFR-12)
          Container(
            width: 18,
            height: 18,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isVeg ? AppColors.veg : AppColors.nonVeg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Item Name & Unit Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '₹${item.effectivePrice}',
                  style: AppTypography.caption.copyWith(color: AppColors.neutral600),
                ),
                if (item.itemInstructions != null && item.itemInstructions!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Note: ${item.itemInstructions}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.neutral500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Quantity Stepper Controls
          _buildQuantityStepper(item),
          const SizedBox(width: AppSpacing.md),

          // Line Total
          SizedBox(
            width: 65,
            child: Text(
              '₹${item.lineTotal}',
              style: AppTypography.body.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStepper(CartItemModel item) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primary, width: 1.2),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 14, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
            onPressed: () {
              widget.provider.updateItemQuantity(item.id, item.quantity - 1);
            },
            tooltip: 'Decrease quantity',
          ),
          Text(
            '${item.quantity}',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
            onPressed: () {
              widget.provider.updateItemQuantity(item.id, item.quantity + 1);
            },
            tooltip: 'Increase quantity',
          ),
        ],
      ),
    );
  }

  Widget _buildCookingInstructionsCard() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Chef Cooking Instructions',
                style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Add instructions for spices, allergies, or delivery drop-off.',
            style: AppTypography.caption.copyWith(color: AppColors.neutral500),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _notesController,
            maxLines: 2,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'e.g., Less spicy, no onions, extra napkins',
              hintStyle: AppTypography.caption,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.sm),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 130,
              height: 36,
              child: AppButton(
                label: 'Save Notes',
                isLoading: _isSavingNotes,
                onPressed: _saveNotes,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillDetailsCard(CartModel cart) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Details',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildBillRow('Item Total', '₹${cart.subtotal}'),
          const SizedBox(height: AppSpacing.xs),
          _buildBillRow(
            'Delivery Fee',
            cart.deliveryFeeDouble == 0.0 ? 'FREE' : '₹${cart.deliveryFee}',
            isFree: cart.deliveryFeeDouble == 0.0,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildBillRow('Taxes & Charges (GST 5%)', '₹${cart.taxAmount}'),
          if (cart.discountAmountDouble > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            _buildBillRow('Discounts', '-₹${cart.discountAmount}', isDiscount: true),
          ],
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'To Pay',
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

  Widget _buildBillRow(
    String label,
    String value, {
    bool isFree = false,
    bool isDiscount = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body.copyWith(color: AppColors.neutral600)),
        Text(
          value,
          style: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            color: isFree
                ? AppColors.veg
                : isDiscount
                    ? AppColors.veg
                    : AppColors.neutral800,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomCheckoutBar(CartModel cart) {
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
                    'TOTAL AMOUNT',
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
                  label: 'Proceed to Checkout',
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: () => context.push(AppRoutes.checkout),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

