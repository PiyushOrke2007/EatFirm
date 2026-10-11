import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../restaurant/models/restaurant_model.dart';

/// Interactive card presenting restaurant discovery details (SRS BROWSE-1, BROWSE-2, BROWSE-4).
class RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final bool isComparing;
  final VoidCallback onToggleCompare;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.isComparing = false,
    required this.onToggleCompare,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOpen = restaurant.isOpen;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner / image
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.md),
                ),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  color: AppColors.neutral100,
                  child: restaurant.imageUrl != null &&
                          restaurant.imageUrl!.isNotEmpty
                      ? Image.network(
                          restaurant.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildImagePlaceholder(),
                        )
                      : _buildImagePlaceholder(),
                ),
              ),

              // Operational status badge
              Positioned(
                top: AppSpacing.sm,
                left: AppSpacing.sm,
                child: AppBadge(
                  label: isOpen ? 'OPEN' : 'CLOSED',
                  type: isOpen ? AppBadgeType.success : AppBadgeType.error,
                  icon: isOpen ? Icons.check_circle : Icons.pause_circle_filled,
                ),
              ),

              // Compare button pill
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: Material(
                  color: isComparing
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    onTap: onToggleCompare,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isComparing ? Icons.check : Icons.compare_arrows,
                            size: 14,
                            color: isComparing ? Colors.white : AppColors.textPrimary,
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            isComparing ? 'Comparing' : 'Compare',
                            style: AppTypography.caption.copyWith(
                              color: isComparing
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Distance pill (if available)
              if (restaurant.distanceKm != null)
                Positioned(
                  bottom: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          '${restaurant.distanceKm!.toStringAsFixed(1)} km',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and Rating row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        restaurant.name,
                        style: AppTypography.title.copyWith(
                          color: isOpen ? AppColors.textPrimary : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _buildRatingBadge(),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Cuisine & Price Tier
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${restaurant.cuisineType} • ${restaurant.priceTier}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // Delivery time and Address row
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${restaurant.estimatedDeliveryMins} mins',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    const Text('•', style: TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        restaurant.address,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBadge() {
    if (restaurant.averageRating != null && restaurant.ratingCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
            const Icon(Icons.star, size: 11, color: Colors.white),
            const SizedBox(width: 2),
            Text(
              '(${restaurant.ratingCount})',
              style: AppTypography.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    // Unrated restaurant per theme.md (no fake ratings!)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        'NEW',
        style: AppTypography.caption.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant,
            size: 36,
            color: AppColors.primary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 4),
          Text(
            restaurant.cuisineType,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
