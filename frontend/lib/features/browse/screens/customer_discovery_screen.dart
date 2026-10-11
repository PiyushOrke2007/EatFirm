import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_loading.dart';
import '../providers/browse_provider.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_compare_sheet.dart';

/// Customer Restaurant Discovery, Search, Comparison & Feed (SRS BROWSE-1, BROWSE-2, BROWSE-4).
class CustomerDiscoveryScreen extends StatefulWidget {
  final BrowseProvider provider;

  const CustomerDiscoveryScreen({super.key, required this.provider});

  @override
  State<CustomerDiscoveryScreen> createState() => _CustomerDiscoveryScreenState();
}

class _CustomerDiscoveryScreenState extends State<CustomerDiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions = _searchFocusNode.hasFocus &&
            widget.provider.suggestions.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openFilters() {
    FilterBottomSheet.show(
      context,
      initialFilter: widget.provider.filter,
      onApply: (newFilter) {
        widget.provider.applyFilters(newFilter);
      },
    );
  }

  void _openComparison() {
    RestaurantCompareSheet.show(
      context,
      restaurants: widget.provider.comparedRestaurants,
      onSelectRestaurant: (restaurant) {
        context.push('${AppRoutes.restaurantDetails}/${restaurant.id}');
      },
      onRemoveRestaurant: (id) {
        widget.provider.removeFromCompare(id);
      },
      onClearAll: () {
        widget.provider.clearComparison();
      },
    );
  }

  int _countActiveFilters() {
    final f = widget.provider.filter;
    int count = 0;
    if (f.sortBy != null && f.sortBy != 'relevance') count++;
    if (f.vegOnly == true) count++;
    if (f.minRating != null) count++;
    if (f.maxDistanceKm != null) count++;
    if (f.maxDeliveryMins != null) count++;
    if (f.priceTier != null) count++;
    if (f.cuisine != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final activeFilters = _countActiveFilters();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Discover Restaurants'),
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: _buildSearchBar(),
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  // Quick Filter & Cuisine Chips
                  _buildQuickFilterChips(activeFilters),

                  // Restaurant listing
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => widget.provider.loadRestaurants(refresh: true),
                      child: _buildFeedBody(),
                    ),
                  ),
                ],
              ),

              // Search Suggestions Overlay (NFR-4)
              if (_showSuggestions && widget.provider.suggestions.isNotEmpty)
                Positioned(
                  top: 0,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _buildSuggestionsOverlay(),
                ),

              // Floating Comparison Tray (BROWSE-4)
              if (widget.provider.comparedRestaurants.isNotEmpty)
                Positioned(
                  bottom: AppSpacing.md,
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  child: _buildComparisonBanner(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: (val) {
        widget.provider.onSearchChanged(val);
        setState(() {
          _showSuggestions = val.trim().isNotEmpty;
        });
      },
      onSubmitted: (val) {
        setState(() => _showSuggestions = false);
        widget.provider.submitSearch(val);
      },
      decoration: InputDecoration(
        hintText: 'Search restaurants, cuisines, or dishes...',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  widget.provider.onSearchChanged('');
                  setState(() => _showSuggestions = false);
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
      ),
    );
  }

  Widget _buildSuggestionsOverlay() {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.md),
      color: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.neutral200),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: widget.provider.suggestions.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final s = widget.provider.suggestions[index];
            return ListTile(
              dense: true,
              leading: Icon(
                s.type == 'restaurant'
                    ? Icons.storefront
                    : (s.type == 'dish' ? Icons.fastfood : Icons.category),
                size: 18,
                color: AppColors.primary,
              ),
              title: Text(s.text, style: AppTypography.bodySmall),
              subtitle: s.subtext != null
                  ? Text(
                      s.subtext!,
                      style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                    )
                  : null,
              onTap: () {
                _searchController.text = s.text;
                setState(() => _showSuggestions = false);
                _searchFocusNode.unfocus();
                widget.provider.selectSuggestion(s);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuickFilterChips(int activeFilterCount) {
    final filter = widget.provider.filter;
    final isVeg = filter.vegOnly == true;
    final isRating4 = filter.minRating == 4.0;
    final isFast = filter.maxDeliveryMins == 30;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          // Filter Bottom Sheet button
          ActionChip(
            avatar: Badge(
              isLabelVisible: activeFilterCount > 0,
              label: Text(activeFilterCount.toString()),
              child: const Icon(Icons.tune, size: 16),
            ),
            label: const Text('Filters'),
            onPressed: _openFilters,
            backgroundColor: activeFilterCount > 0
                ? AppColors.primary.withValues(alpha: 0.15)
                : Colors.white,
          ),
          const SizedBox(width: 8),

          // Pure Veg toggle (NFR-12)
          FilterChip(
            selected: isVeg,
            onSelected: (selected) =>
                widget.provider.toggleVegOnly(selected ? true : null),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.success, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text('Pure Veg'),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Rating 4.0+
          FilterChip(
            selected: isRating4,
            onSelected: (selected) {
              widget.provider.applyFilters(
                filter.copyWith(
                  minRating: selected ? 4.0 : null,
                  clearMinRating: !selected,
                ),
              );
            },
            label: const Text('Rating 4.0+ ★'),
          ),
          const SizedBox(width: 8),

          // Under 30 mins
          FilterChip(
            selected: isFast,
            onSelected: (selected) {
              widget.provider.applyFilters(
                filter.copyWith(
                  maxDeliveryMins: selected ? 30 : null,
                  clearMaxDeliveryMins: !selected,
                ),
              );
            },
            label: const Text('< 30 mins'),
          ),
          const SizedBox(width: 8),

          // Popular cuisines
          _buildCuisineChip('North Indian'),
          const SizedBox(width: 8),
          _buildCuisineChip('Biryani'),
          const SizedBox(width: 8),
          _buildCuisineChip('South Indian'),
          const SizedBox(width: 8),
          _buildCuisineChip('Pizza'),
          const SizedBox(width: 8),
          _buildCuisineChip('Desserts'),
        ],
      ),
    );
  }

  Widget _buildCuisineChip(String cuisineName) {
    final isSelected = widget.provider.filter.cuisine == cuisineName;
    return FilterChip(
      selected: isSelected,
      onSelected: (_) => widget.provider.setCuisine(cuisineName),
      label: Text(cuisineName),
    );
  }

  Widget _buildFeedBody() {
    if (widget.provider.isLoading && widget.provider.restaurants.isEmpty) {
      return const Center(child: AppLoadingIndicator());
    }

    if (widget.provider.errorMessage != null &&
        widget.provider.restaurants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Failed to load restaurants',
                style: AppTypography.title,
              ),
              const SizedBox(height: 4),
              Text(
                widget.provider.errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Retry',
                onPressed: () => widget.provider.loadRestaurants(refresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.provider.restaurants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 54, color: AppColors.neutral400),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No restaurants found',
                style: AppTypography.title,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Try adjusting your filters or search keywords.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Reset Filters',
                variant: AppButtonVariant.outline,
                onPressed: () {
                  _searchController.clear();
                  widget.provider.resetFilters();
                },
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive columns: 1 column on mobile, 2 columns on tablet, 3 on desktop
        final bool isWide = constraints.maxWidth >= 720;
        final bool isExtraWide = constraints.maxWidth >= 1080;

        if (isWide) {
          final crossAxisCount = isExtraWide ? 3 : 2;
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 1.15,
            ),
            itemCount: widget.provider.restaurants.length,
            itemBuilder: (context, index) {
              final r = widget.provider.restaurants[index];
              return RestaurantCard(
                restaurant: r,
                isComparing: widget.provider.isComparing(r.id),
                onToggleCompare: () => widget.provider.toggleCompareRestaurant(r),
                onTap: () => context.push('${AppRoutes.restaurantDetails}/${r.id}'),
              );
            },
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: widget.provider.restaurants.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, index) {
            final r = widget.provider.restaurants[index];
            return RestaurantCard(
              restaurant: r,
              isComparing: widget.provider.isComparing(r.id),
              onToggleCompare: () => widget.provider.toggleCompareRestaurant(r),
              onTap: () => context.push('${AppRoutes.restaurantDetails}/${r.id}'),
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonBanner() {
    final count = widget.provider.comparedRestaurants.length;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.compare_arrows, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count restaurant${count > 1 ? 's' : ''} in comparison',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: _openComparison,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: const Text('Compare', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () => widget.provider.clearComparison(),
            ),
          ],
        ),
      ),
    );
  }
}
