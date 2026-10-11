import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/menu_category_model.dart';
import '../models/menu_item_model.dart';
import '../services/restaurant_api_service.dart';
import '../widgets/menu_item_dialog.dart';
import '../widgets/veg_indicator.dart';

/// Screen for managing categories and menu items (SRS REST-3, REST-4, REST-5, REST-6, NFR-12, NFR-14).
class MenuManagementScreen extends StatefulWidget {
  final RestaurantApiService restaurantService;

  const MenuManagementScreen({
    super.key,
    required this.restaurantService,
  });

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<MenuCategoryModel> _categories = [];
  List<MenuItemModel> _menuItems = [];
  String? _selectedCategoryId; // null = All

  @override
  void initState() {
    super.initState();
    _loadMenuData();
  }

  Future<void> _loadMenuData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categories = await widget.restaurantService.getCategories();
      final items = await widget.restaurantService.getMenuItems();
      if (mounted) {
        setState(() {
          _categories = categories;
          _menuItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAddCategory() async {
    final nameController = TextEditingController();
    final sortController = TextEditingController(text: '${_categories.length + 1}');

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Menu Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name *',
                hintText: 'e.g. Starters, Main Course, Beverages',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: sortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Display Order',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              try {
                final sort = int.tryParse(sortController.text.trim()) ?? 0;
                await widget.restaurantService.createCategory(name, sortOrder: sort);
                if (ctx.mounted) Navigator.of(ctx).pop(true);
              } catch (e) {
                if (ctx.mounted) {
                  AppSnackbar.showError(ctx, 'Failed to add category: $e');
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      _loadMenuData();
      if (mounted) AppSnackbar.showSuccess(context, 'Category created!');
    }
  }

  Future<void> _handleToggleItemAvailability(MenuItemModel item, bool newStatus) async {
    try {
      final updated = await widget.restaurantService.toggleItemAvailability(item.id, newStatus);
      if (mounted) {
        setState(() {
          final index = _menuItems.indexWhere((m) => m.id == item.id);
          if (index != -1) {
            _menuItems[index] = updated;
          }
        });
        AppSnackbar.showSuccess(
          context,
          newStatus ? '${item.name} marked Available' : '${item.name} marked Unavailable',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to toggle availability: $e');
      }
    }
  }

  Future<void> _handleDeleteItem(MenuItemModel item) async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Delete Menu Item?',
      message:
          'Are you sure you want to delete "${item.name}"? This action cannot be undone (SRS NFR-14).',
      confirmText: 'Delete Item',
      isDestructive: true,
    );

    if (confirmed == true) {
      try {
        await widget.restaurantService.deleteMenuItem(item.id);
        if (mounted) {
          setState(() {
            _menuItems.removeWhere((m) => m.id == item.id);
          });
          AppSnackbar.showSuccess(context, '${item.name} deleted successfully.');
        }
      } catch (e) {
        if (mounted) {
          AppSnackbar.showError(context, 'Failed to delete item: $e');
        }
      }
    }
  }

  void _openItemDialog([MenuItemModel? itemToEdit]) {
    if (_categories.isEmpty) {
      AppSnackbar.showError(context, 'Please create at least one category first.');
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => MenuItemDialog(
        restaurantService: widget.restaurantService,
        categories: _categories,
        itemToEdit: itemToEdit,
        onSaved: () {
          _loadMenuData();
          AppSnackbar.showSuccess(
            context,
            itemToEdit != null ? 'Item updated successfully!' : 'Item added to menu!',
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator(message: 'Loading menu & categories...')),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Menu Management')),
        body: Center(
          child: AppErrorState(
            message: _errorMessage!,
            onRetry: _loadMenuData,
          ),
        ),
      );
    }

    final filteredItems = _selectedCategoryId == null
        ? _menuItems
        : _menuItems.where((m) => m.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.restaurantDashboard),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Category',
            onPressed: _handleAddCategory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadMenuData,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openItemDialog(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Dish', style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 900 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Filter Bar (SRS REST-3)
                _buildCategoryFilterBar(),
                const Divider(height: 1),

                // Items list or empty state
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: AppEmptyState(
                            icon: Icons.restaurant_menu,
                            title: _categories.isEmpty
                                ? 'No Categories Added'
                                : 'No Dishes in this Category',
                            description: _categories.isEmpty
                                ? 'Create your first menu category (e.g. Starters, Main Course, Desserts) to organize your menu.'
                                : 'Tap "Add Dish" below to add a delicious item to this category.',
                            actionLabel: _categories.isEmpty
                                ? 'Add Category'
                                : 'Add Dish',
                            onAction: _categories.isEmpty
                                ? _handleAddCategory
                                : () => _openItemDialog(),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            return _buildMenuItemCard(filteredItems[index]);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('All Dishes'),
              selected: _selectedCategoryId == null,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedCategoryId = null),
            ),
            const SizedBox(width: AppSpacing.xs),
            ..._categories.map((cat) {
              final isSelected = _selectedCategoryId == cat.id;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: ChoiceChip(
                  label: Text('${cat.name} (${cat.itemCount ?? 0})'),
                  selected: isSelected,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _selectedCategoryId = cat.id),
                ),
              );
            }),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: const Text('New Category'),
              onPressed: _handleAddCategory,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemCard(MenuItemModel item) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Veg indicator, dish name, category badge, and stock toggle
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: AppSpacing.xs),
                child: VegIndicator(isVeg: item.isVeg, size: 16),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: AppTypography.title.copyWith(
                    color: item.isAvailable
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Availability Switch & Status Tag
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.isAvailable ? 'In Stock' : 'Out of Stock',
                    style: AppTypography.caption.copyWith(
                      color: item.isAvailable
                          ? AppColors.success
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: item.isAvailable,
                      activeThumbColor: AppColors.success,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) =>
                          _handleToggleItemAvailability(item, val),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (item.categoryName != null) ...[
            const SizedBox(height: 4),
            AppBadge(
              label: item.categoryName!,
              type: AppBadgeType.neutral,
            ),
          ],

          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.description!,
              style: AppTypography.caption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 8),

          // Bottom Bar: Price, Offer badge, Time window, and Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Price block
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (item.isSpecialOffer && item.offerPrice != null) ...[
                    Text(
                      '₹${item.offerPrice}',
                      style: AppTypography.title.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${item.price}',
                      style: AppTypography.bodySmall.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const AppBadge(
                      label: 'SPECIAL OFFER',
                      type: AppBadgeType.warning,
                      icon: Icons.local_offer,
                    ),
                  ] else ...[
                    Text(
                      '₹${item.price}',
                      style: AppTypography.title.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  if (item.availableFrom != null &&
                      item.availableUntil != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 13,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.availableFrom} – ${item.availableUntil}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              // Action buttons (Edit & Delete)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: 'Edit Item',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _openItemDialog(item),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: AppColors.error,
                    ),
                    tooltip: 'Delete Item',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => _handleDeleteItem(item),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
