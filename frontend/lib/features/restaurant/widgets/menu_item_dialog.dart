import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/menu_category_model.dart';
import '../models/menu_item_model.dart';
import '../services/restaurant_api_service.dart';
import 'veg_indicator.dart';

/// Modal dialog for adding or editing a menu item (SRS REST-3, REST-4, REST-5, REST-6, NFR-12).
class MenuItemDialog extends StatefulWidget {
  final RestaurantApiService restaurantService;
  final List<MenuCategoryModel> categories;
  final MenuItemModel? itemToEdit;
  final VoidCallback onSaved;

  const MenuItemDialog({
    super.key,
    required this.restaurantService,
    required this.categories,
    this.itemToEdit,
    required this.onSaved,
  });

  @override
  State<MenuItemDialog> createState() => _MenuItemDialogState();
}

class _MenuItemDialogState extends State<MenuItemDialog> {
  late String _selectedCategoryId;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _availFromController;
  late final TextEditingController _availUntilController;
  late final TextEditingController _offerPriceController;

  String? _nameError;
  String? _priceError;
  String? _offerPriceError;

  bool _isVeg = true;
  bool _isAvailable = true;
  bool _hasTimeAvailability = false;
  bool _isSpecialOffer = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    _selectedCategoryId = item?.categoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : '');

    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(text: item?.price ?? '');
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');

    _isVeg = item?.isVeg ?? true;
    _isAvailable = item?.isAvailable ?? true;

    _hasTimeAvailability = item?.availableFrom != null && item?.availableUntil != null;
    _availFromController = TextEditingController(text: item?.availableFrom ?? '08:00');
    _availUntilController = TextEditingController(text: item?.availableUntil ?? '11:30');

    _isSpecialOffer = item?.isSpecialOffer ?? false;
    _offerPriceController = TextEditingController(text: item?.offerPrice ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _availFromController.dispose();
    _availUntilController.dispose();
    _offerPriceController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;
    _nameError = null;
    _priceError = null;
    _offerPriceError = null;

    if (_nameController.text.trim().isEmpty) {
      _nameError = 'Dish name is required';
      isValid = false;
    }

    final priceStr = _priceController.text.trim();
    if (priceStr.isEmpty) {
      _priceError = 'Price is required';
      isValid = false;
    } else {
      final p = double.tryParse(priceStr);
      if (p == null || p < 0) {
        _priceError = 'Enter a valid non-negative price';
        isValid = false;
      }
    }

    if (_isSpecialOffer) {
      final offerStr = _offerPriceController.text.trim();
      if (offerStr.isEmpty) {
        _offerPriceError = 'Offer price is required for special offers';
        isValid = false;
      } else {
        final offerNum = double.tryParse(offerStr);
        final baseNum = double.tryParse(priceStr);
        if (offerNum == null || offerNum < 0) {
          _offerPriceError = 'Enter a valid non-negative offer price';
          isValid = false;
        } else if (baseNum != null && offerNum >= baseNum) {
          _offerPriceError = 'Offer price must be less than regular price (₹$baseNum)';
          isValid = false;
        }
      }
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleSave() async {
    if (!_validateInputs()) return;
    if (_selectedCategoryId.isEmpty) {
      AppSnackbar.showError(context, 'Please select or create a category first.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final price = _priceController.text.trim();
      final imageUrl = _imageUrlController.text.trim();

      final availFrom = _hasTimeAvailability ? _availFromController.text.trim() : null;
      final availUntil = _hasTimeAvailability ? _availUntilController.text.trim() : null;
      final offerPrice = _isSpecialOffer ? _offerPriceController.text.trim() : null;

      if (widget.itemToEdit == null) {
        // Create
        await widget.restaurantService.createMenuItem(
          categoryId: _selectedCategoryId,
          name: name,
          description: description.isNotEmpty ? description : null,
          price: price,
          isVeg: _isVeg,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
          isAvailable: _isAvailable,
          availableFrom: availFrom,
          availableUntil: availUntil,
          isSpecialOffer: _isSpecialOffer,
          offerPrice: offerPrice,
        );
      } else {
        // Update
        await widget.restaurantService.updateMenuItem(
          widget.itemToEdit!.id,
          categoryId: _selectedCategoryId,
          name: name,
          description: description.isNotEmpty ? description : null,
          price: price,
          isVeg: _isVeg,
          imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
          isAvailable: _isAvailable,
          availableFrom: availFrom,
          availableUntil: availUntil,
          isSpecialOffer: _isSpecialOffer,
          offerPrice: offerPrice,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to save item: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.itemToEdit != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isEdit ? Icons.edit_note : Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Menu Item' : 'Add New Menu Item',
                      style: AppTypography.title,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Category selection
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategoryId.isNotEmpty
                            ? _selectedCategoryId
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: widget.categories
                            .map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedCategoryId = val);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Item name
                      AppTextField(
                        controller: _nameController,
                        label: 'Dish Name *',
                        hint: 'e.g. Paneer Butter Masala',
                        errorText: _nameError,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Price
                      AppTextField(
                        controller: _priceController,
                        label: 'Base Price (INR ₹) *',
                        hint: 'e.g. 250.00',
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        prefixIcon: const Icon(Icons.currency_rupee),
                        errorText: _priceError,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Veg / Non-Veg tag (NFR-12)
                      Row(
                        children: [
                          const Text('Dietary Tag: ',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(width: AppSpacing.xs),
                          ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VegIndicator(isVeg: true, size: 14),
                                SizedBox(width: 6),
                                Text('Veg'),
                              ],
                            ),
                            selected: _isVeg,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _isVeg = true),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ChoiceChip(
                            label: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VegIndicator(isVeg: false, size: 14),
                                SizedBox(width: 6),
                                Text('Non-Veg'),
                              ],
                            ),
                            selected: !_isVeg,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _isVeg = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Description
                      AppTextField(
                        controller: _descriptionController,
                        label: 'Description (Optional)',
                        hint: 'Ingredients, spice level, preparation style',
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Image URL
                      AppTextField(
                        controller: _imageUrlController,
                        label: 'Image URL (Optional)',
                        hint: 'https://...',
                        prefixIcon: const Icon(Icons.image_outlined),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Availability switch
                      SwitchListTile(
                        title: const Text('Available for Ordering'),
                        subtitle: const Text('Temporarily pause if out of stock (REST-4)'),
                        value: _isAvailable,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) => setState(() => _isAvailable = val),
                      ),

                      // Time-based availability (REST-5)
                      CheckboxListTile(
                        title: const Text('Time-Based Availability (REST-5)'),
                        subtitle: const Text('e.g. Breakfast item served only 08:00 - 11:30'),
                        value: _hasTimeAvailability,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _hasTimeAvailability = val ?? false),
                      ),
                      if (_hasTimeAvailability) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _availFromController,
                                decoration: const InputDecoration(
                                  labelText: 'From (HH:MM)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: TextField(
                                controller: _availUntilController,
                                decoration: const InputDecoration(
                                  labelText: 'Until (HH:MM)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // Special Offer (REST-6)
                      CheckboxListTile(
                        title: const Text('Special Offer / Deal of the Day (REST-6)'),
                        subtitle: const Text('Promote with a discounted offer price'),
                        value: _isSpecialOffer,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) =>
                            setState(() => _isSpecialOffer = val ?? false),
                      ),
                      if (_isSpecialOffer) ...[
                        AppTextField(
                          controller: _offerPriceController,
                          label: 'Offer Price (INR ₹) *',
                          hint: 'Must be less than regular price',
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          prefixIcon: const Icon(Icons.local_offer_outlined),
                          errorText: _offerPriceError,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Cancel',
                    variant: AppButtonVariant.text,
                    isFullWidth: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: isEdit ? 'Save Changes' : 'Add Item',
                    isFullWidth: false,
                    isLoading: _isLoading,
                    onPressed: _handleSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
