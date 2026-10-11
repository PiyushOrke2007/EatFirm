import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../models/browse_filter_model.dart';

/// Modal bottom sheet for configuring discovery filters and sorting options (SRS BROWSE-2).
class FilterBottomSheet extends StatefulWidget {
  final BrowseFilterModel initialFilter;
  final ValueChanged<BrowseFilterModel> onApply;

  const FilterBottomSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required BrowseFilterModel initialFilter,
    required ValueChanged<BrowseFilterModel> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FilterBottomSheet(
        initialFilter: initialFilter,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  late String _sortBy;
  late bool _vegOnly;
  late double? _minRating;
  late double? _maxDistanceKm;
  late int? _maxDeliveryMins;
  late String? _priceTier;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialFilter.sortBy ?? 'relevance';
    _vegOnly = widget.initialFilter.vegOnly ?? false;
    _minRating = widget.initialFilter.minRating;
    _maxDistanceKm = widget.initialFilter.maxDistanceKm;
    _maxDeliveryMins = widget.initialFilter.maxDeliveryMins;
    _priceTier = widget.initialFilter.priceTier;
  }

  void _reset() {
    setState(() {
      _sortBy = 'relevance';
      _vegOnly = false;
      _minRating = null;
      _maxDistanceKm = null;
      _maxDeliveryMins = null;
      _priceTier = null;
    });
  }

  void _apply() {
    final updated = widget.initialFilter.copyWith(
      sortBy: _sortBy,
      vegOnly: _vegOnly ? true : null,
      clearVegOnly: !_vegOnly,
      minRating: _minRating,
      maxDistanceKm: _maxDistanceKm,
      maxDeliveryMins: _maxDeliveryMins,
      priceTier: _priceTier,
      clearMinRating: _minRating == null,
      clearMaxDistance: _maxDistanceKm == null,
      clearMaxDeliveryMins: _maxDeliveryMins == null,
      clearPriceTier: _priceTier == null,
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters & Sorting', style: AppTypography.title),
              TextButton(
                onPressed: _reset,
                child: Text(
                  'Reset All',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),

          // Scrollable filter controls
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                // 1. Sort By
                _buildSectionHeader('Sort By'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSortChip('Relevance', 'relevance'),
                    _buildSortChip('Rating: High to Low', 'rating_desc'),
                    _buildSortChip('Distance: Nearest', 'distance_asc'),
                    _buildSortChip('Delivery: Fastest', 'delivery_time_asc'),
                    _buildSortChip('Cost: Low to High', 'cost_low_to_high'),
                    _buildSortChip('Cost: High to Low', 'cost_high_to_low'),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 2. Pure Veg Toggle (NFR-12)
                _buildSectionHeader('Dietary Preference'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: AppColors.success,
                  activeTrackColor: AppColors.successLight,
                  title: Row(
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
                      Text('Pure Veg Restaurants Only', style: AppTypography.body),
                    ],
                  ),
                  value: _vegOnly,
                  onChanged: (val) => setState(() => _vegOnly = val),
                ),
                const SizedBox(height: AppSpacing.md),

                // 3. Minimum Rating
                _buildSectionHeader('Rating'),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildRatingChip('Any', null),
                    _buildRatingChip('3.5+ ★', 3.5),
                    _buildRatingChip('4.0+ ★', 4.0),
                    _buildRatingChip('4.5+ ★', 4.5),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 4. Max Distance
                _buildSectionHeader('Distance (Within)'),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDistanceChip('Any', null),
                    _buildDistanceChip('Within 3 km', 3.0),
                    _buildDistanceChip('Within 5 km', 5.0),
                    _buildDistanceChip('Within 10 km', 10.0),
                    _buildDistanceChip('Within 20 km', 20.0),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 5. Max Delivery Time
                _buildSectionHeader('Delivery Time (Under)'),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildDeliveryChip('Any', null),
                    _buildDeliveryChip('< 30 mins', 30),
                    _buildDeliveryChip('< 45 mins', 45),
                    _buildDeliveryChip('< 60 mins', 60),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // 6. Price Tier
                _buildSectionHeader('Price Tier'),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildPriceChip('Any', null),
                    _buildPriceChip('₹ (Budget)', '₹'),
                    _buildPriceChip('₹₹ (Moderate)', '₹₹'),
                    _buildPriceChip('₹₹₹ (Premium)', '₹₹₹'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),

          // Bottom Action
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Apply Filters',
            onPressed: _apply,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: AppTypography.label.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _sortBy = value);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildRatingChip(String label, double? value) {
    final isSelected = _minRating == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _minRating = selected ? value : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildDistanceChip(String label, double? value) {
    final isSelected = _maxDistanceKm == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _maxDistanceKm = selected ? value : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildDeliveryChip(String label, int? value) {
    final isSelected = _maxDeliveryMins == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _maxDeliveryMins = selected ? value : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildPriceChip(String label, String? value) {
    final isSelected = _priceTier == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _priceTier = selected ? value : null);
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
