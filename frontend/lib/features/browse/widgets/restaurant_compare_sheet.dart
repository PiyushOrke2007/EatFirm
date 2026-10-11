import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../restaurant/models/restaurant_model.dart';

/// Side-by-side comparison sheet comparing 2-3 restaurants (SRS BROWSE-4, BRW-04).
class RestaurantCompareSheet extends StatelessWidget {
  final List<RestaurantModel> restaurants;
  final ValueChanged<RestaurantModel> onSelectRestaurant;
  final ValueChanged<String> onRemoveRestaurant;
  final VoidCallback onClearAll;

  const RestaurantCompareSheet({
    super.key,
    required this.restaurants,
    required this.onSelectRestaurant,
    required this.onRemoveRestaurant,
    required this.onClearAll,
  });

  static Future<void> show(
    BuildContext context, {
    required List<RestaurantModel> restaurants,
    required ValueChanged<RestaurantModel> onSelectRestaurant,
    required ValueChanged<String> onRemoveRestaurant,
    required VoidCallback onClearAll,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RestaurantCompareSheet(
        restaurants: restaurants,
        onSelectRestaurant: onSelectRestaurant,
        onRemoveRestaurant: onRemoveRestaurant,
        onClearAll: onClearAll,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        ),
        child: const Text('No restaurants selected for comparison.'),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.lg,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Compare Restaurants', style: AppTypography.title),
                    Text(
                      'Comparing ${restaurants.length} of 3 restaurants',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    onClearAll();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Clear All',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // Side-by-side comparison table
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: restaurants
                      .map((r) => _buildRestaurantColumn(context, r))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantColumn(BuildContext context, RestaurantModel r) {
    const double colWidth = 190.0;

    return Container(
      width: colWidth,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => onRemoveRestaurant(r.id),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),

          // Restaurant Name
          Text(
            r.name,
            style: AppTypography.title.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),

          // Cuisine & Status
          Text(
            r.cuisineType,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: r.isOpen ? AppColors.successLight : AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              r.isOpen ? 'OPEN' : 'CLOSED',
              style: AppTypography.caption.copyWith(
                color: r.isOpen ? AppColors.success : AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const Divider(height: 20),

          // Metric: Rating
          _buildMetricRow(
            'Rating',
            r.averageRating != null && r.ratingCount > 0
                ? '★ ${r.averageRating!.toStringAsFixed(1)} (${r.ratingCount})'
                : 'New / Unrated',
            isHighlight: r.averageRating != null && r.averageRating! >= 4.0,
          ),

          // Metric: Est Delivery Time
          _buildMetricRow(
            'Delivery Time',
            '${r.estimatedDeliveryMins} mins',
          ),

          // Metric: Distance
          _buildMetricRow(
            'Distance',
            r.distanceKm != null
                ? '${r.distanceKm!.toStringAsFixed(1)} km'
                : 'N/A',
          ),

          // Metric: Price Tier
          _buildMetricRow(
            'Price Tier',
            r.priceTier,
          ),

          // Metric: FSSAI License
          _buildMetricRow(
            'FSSAI Lic.',
            r.foodLicenseNumber,
          ),

          // Metric: Address
          _buildMetricRow(
            'Address',
            r.address,
          ),
          const SizedBox(height: AppSpacing.md),

          // View Menu Button
          AppButton(
            label: 'View Menu',
            height: 36.0,
            onPressed: () {
              Navigator.of(context).pop();
              onSelectRestaurant(r);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: AppTypography.bodySmall.copyWith(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
              color: isHighlight ? AppColors.success : AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
