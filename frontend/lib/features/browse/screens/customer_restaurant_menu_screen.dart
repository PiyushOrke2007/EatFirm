import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../restaurant/models/menu_item_model.dart';
import '../../restaurant/models/restaurant_model.dart';
import '../models/customer_menu_model.dart';
import '../services/browse_api_service.dart';

/// Public Restaurant Profile & Categorized Customer Menu (SRS BROWSE-3, NFR-12).
class CustomerRestaurantMenuScreen extends StatefulWidget {
  final String restaurantId;
  final BrowseApiService browseService;

  const CustomerRestaurantMenuScreen({
    super.key,
    required this.restaurantId,
    required this.browseService,
  });

  @override
  State<CustomerRestaurantMenuScreen> createState() =>
      _CustomerRestaurantMenuScreenState();
}

class _CustomerRestaurantMenuScreenState
    extends State<CustomerRestaurantMenuScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  CustomerMenuResponse? _menuData;

  // In-menu filtering & search
  bool _vegOnly = false;
  String _dishSearch = '';
  final TextEditingController _dishSearchController = TextEditingController();

  // Simple in-memory cart map for Module 04/05 handoff {itemId: count}
  final Map<String, int> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void dispose() {
    _dishSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await widget.browseService.getCustomerRestaurantMenu(
        widget.restaurantId,
        isVeg: _vegOnly ? true : null,
        search: _dishSearch.trim().isNotEmpty ? _dishSearch.trim() : null,
      );
      if (mounted) {
        setState(() {
          _menuData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onVegOnlyChanged(bool value) {
    setState(() {
      _vegOnly = value;
    });
    _loadMenu();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _dishSearch = value;
    });
    _loadMenu();
  }

  void _addToCart(MenuItemModel item) {
    setState(() {
      _cart[item.id] = (_cart[item.id] ?? 0) + 1;
    });
  }

  void _removeFromCart(MenuItemModel item) {
    setState(() {
      final current = _cart[item.id] ?? 0;
      if (current <= 1) {
        _cart.remove(item.id);
      } else {
        _cart[item.id] = current - 1;
      }
    });
  }

  int get _totalCartItems => _cart.values.fold(0, (sum, count) => sum + count);

  double get _cartTotalAmount {
    if (_menuData == null) return 0.0;
    double total = 0.0;
    for (final entry in _cart.entries) {
      final item = _menuData!.menuItems.firstWhere(
        (i) => i.id == entry.key,
        orElse: () => _menuData!.categories
            .expand((c) => c.items)
            .firstWhere((i) => i.id == entry.key),
      );
      total += item.effectivePrice * entry.value;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _menuData?.restaurant.name ?? 'Restaurant Menu',
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildBody(),
          ),
          if (_totalCartItems > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildCartBottomBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _menuData == null) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null && _menuData == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.sm),
              Text('Unable to load menu', style: AppTypography.title),
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(label: 'Retry', onPressed: _loadMenu),
            ],
          ),
        ),
      );
    }

    final restaurant = _menuData!.restaurant;
    final categories = _menuData!.categories;

    return RefreshIndicator(
      onRefresh: _loadMenu,
      child: CustomScrollView(
        slivers: [
          // Restaurant Profile Card Header (SRS BROWSE-3)
          SliverToBoxAdapter(
            child: _buildRestaurantHeader(restaurant),
          ),

          // Search and Veg-Only Controls
          SliverToBoxAdapter(
            child: _buildMenuControls(),
          ),

          // Menu Categories and Dishes
          if (categories.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu,
                          size: 48, color: AppColors.neutral400),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _vegOnly
                            ? 'No vegetarian dishes match your search'
                            : 'No menu items available at this time',
                        style: AppTypography.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, catIndex) {
                  final cat = categories[catIndex];
                  return _buildCategorySection(cat);
                },
                childCount: categories.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80), // spacing for bottom cart bar
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantHeader(RestaurantModel restaurant) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurant.name,
                      style: AppTypography.headline.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${restaurant.cuisineType} • ${restaurant.priceTier}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: restaurant.isOpen ? 'OPEN' : 'CLOSED',
                type: restaurant.isOpen
                    ? AppBadgeType.success
                    : AppBadgeType.error,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Rating, delivery time, distance
          Row(
            children: [
              if (restaurant.averageRating != null &&
                  restaurant.ratingCount > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        restaurant.averageRating!.toStringAsFixed(1),
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.star, size: 10, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${restaurant.ratingCount} ratings)',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Text('•',
                    style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(Icons.timer_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${restaurant.estimatedDeliveryMins} mins',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Address
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  restaurant.address,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Mandatory FSSAI license display (SRS BROWSE-3)
          Row(
            children: [
              const Icon(Icons.verified_outlined,
                  size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                'FSSAI Lic. No: ${restaurant.foodLicenseNumber}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          // In-restaurant dish search
          TextField(
            controller: _dishSearchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search dishes in this restaurant...',
              prefixIcon:
                  const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: _dishSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _dishSearchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              filled: true,
              fillColor: AppColors.neutral50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                borderSide: const BorderSide(color: AppColors.neutral200),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Veg Only Switch (SRS BROWSE-3, NFR-12)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.success, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pure Veg Only',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _vegOnly,
                activeThumbColor: AppColors.success,
                activeTrackColor: AppColors.successLight,
                onChanged: _onVegOnlyChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(MenuCategoryWithItems category) {
    if (category.items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            '${category.name} (${category.items.length})',
            style: AppTypography.title.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: category.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, itemIndex) {
            final item = category.items[itemIndex];
            return _buildDishCard(item);
          },
        ),
      ],
    );
  }

  Widget _buildDishCard(MenuItemModel item) {
    final int quantity = _cart[item.id] ?? 0;
    final bool isAvailable = item.isAvailable;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dietary veg/non-veg indicator
          Container(
            margin: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              border: Border.all(
                color: item.isVeg ? AppColors.success : AppColors.error,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: item.isVeg ? AppColors.success : AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Dish details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dish Name (wrap smoothly without truncating single letters)
                Text(
                  item.name,
                  style: AppTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Pricing (Base and Special Offer if active)
                Row(
                  children: [
                    if (item.isSpecialOffer && item.offerPrice != null) ...[
                      Text(
                        '₹${item.parsedOfferPrice.toStringAsFixed(2)}',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '₹${item.parsedPrice.toStringAsFixed(2)}',
                        style: AppTypography.caption.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ] else ...[
                      Text(
                        '₹${item.parsedPrice.toStringAsFixed(2)}',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),

                // Description
                if (item.description != null && item.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Time-based availability notice (if outside hours)
                if (item.availableFrom != null && item.availableUntil != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Available: ${item.availableFrom} - ${item.availableUntil}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.neutral500,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          // Image and Add Button Column
          Column(
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.network(
                    item.imageUrl!,
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 6),

              // Add to Cart Button / Counter
              if (!isAvailable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neutral200,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    'Unavailable',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                )
              else if (quantity == 0)
                OutlinedButton(
                  onPressed: () => _addToCart(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              else
                Material(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  elevation: 1,
                  child: SizedBox(
                    height: 36,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove, size: 16, color: Colors.white),
                          onPressed: () => _removeFromCart(item),
                          splashRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          tooltip: 'Decrease quantity',
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            quantity.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, size: 16, color: Colors.white),
                          onPressed: () => _addToCart(item),
                          splashRadius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                          tooltip: 'Increase quantity',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartBottomBar() {
    return Material(
      color: AppColors.primary,
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              offset: const Offset(0, -2),
              blurRadius: 8,
            ),
          ],
        ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_totalCartItems ITEM${_totalCartItems > 1 ? 'S' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '₹${_cartTotalAmount.toStringAsFixed(2)}',
                  style: AppTypography.title.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                AppSnackbar.showInfo(
                  context,
                  'Cart handoff: $_totalCartItems items ready for Module 05 Checkout',
                );
              },
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('View Cart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
