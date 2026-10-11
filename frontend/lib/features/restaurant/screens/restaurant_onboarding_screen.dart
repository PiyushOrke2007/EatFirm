import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/operating_hours_model.dart';
import '../services/restaurant_api_service.dart';

/// Restaurant Onboarding Screen (SRS REST-1, Section 6).
class RestaurantOnboardingScreen extends StatefulWidget {
  final RestaurantApiService restaurantService;

  const RestaurantOnboardingScreen({
    super.key,
    required this.restaurantService,
  });

  @override
  State<RestaurantOnboardingScreen> createState() =>
      _RestaurantOnboardingScreenState();
}

class _RestaurantOnboardingScreenState
    extends State<RestaurantOnboardingScreen> {
  final _nameController = TextEditingController();
  final _cuisineController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _licenseController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();

  String? _nameError;
  String? _cuisineError;
  String? _phoneError;
  String? _licenseError;
  String? _addressError;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _cuisineController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _licenseController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    bool isValid = true;
    _nameError = null;
    _cuisineError = null;
    _phoneError = null;
    _licenseError = null;
    _addressError = null;

    if (_nameController.text.trim().length < 2) {
      _nameError = 'Restaurant name must be at least 2 characters';
      isValid = false;
    }

    if (_cuisineController.text.trim().isEmpty) {
      _cuisineError = 'Cuisine type is required';
      isValid = false;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim())) {
      _phoneError = 'Enter a valid 10-digit Indian phone number';
      isValid = false;
    }

    if (_licenseController.text.trim().length < 3) {
      _licenseError = 'Food license number is required (SRS Section 6)';
      isValid = false;
    }

    if (_addressController.text.trim().length < 5) {
      _addressError = 'Please enter a valid complete address';
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleSubmit() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final defaultHours = [
        'MONDAY',
        'TUESDAY',
        'WEDNESDAY',
        'THURSDAY',
        'FRIDAY',
        'SATURDAY',
        'SUNDAY',
      ].map((day) => OperatingHoursModel(
            dayOfWeek: day,
            openTime: '09:00',
            closeTime: '22:00',
            isClosed: false,
          )).toList();

      await widget.restaurantService.onboardRestaurant(
        name: _nameController.text.trim(),
        cuisineType: _cuisineController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        foodLicenseNumber: _licenseController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        imageUrl: _imageUrlController.text.trim().isNotEmpty
            ? _imageUrlController.text.trim()
            : null,
        operatingHours: defaultHours,
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          'Restaurant submitted successfully! Awaiting System Administrator approval.',
        );
        context.go(AppRoutes.restaurantDashboard);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Onboarding'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.profile),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 640 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header card
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.storefront,
                            color: AppColors.primary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Register Your Restaurant',
                                style: AppTypography.title,
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Provide operational & licensing details for admin verification (SRS REST-1).',
                                style: AppTypography.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppTextField(
                          controller: _nameController,
                          label: 'Restaurant Name',
                          hint: 'e.g. The Royal Spice, Pizza Roma',
                          prefixIcon: const Icon(Icons.business),
                          errorText: _nameError,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _cuisineController,
                          label: 'Cuisine Type',
                          hint: 'e.g. North Indian, Italian, Desserts',
                          prefixIcon: const Icon(Icons.restaurant),
                          errorText: _cuisineError,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _phoneController,
                          label: 'Contact Phone Number',
                          hint: '10-digit mobile number',
                          prefixIcon: const Icon(Icons.phone),
                          keyboardType: TextInputType.phone,
                          errorText: _phoneError,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _licenseController,
                          label: 'Food License Number (FSSAI)',
                          hint: 'e.g. FSSAI-12345678901234',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          helperText: 'Mandatory statutory food registration (SRS Section 6)',
                          errorText: _licenseError,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _addressController,
                          label: 'Complete Physical Address',
                          hint: 'Shop No., Street, Area, City, Pin Code',
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          maxLines: 2,
                          errorText: _addressError,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _descriptionController,
                          label: 'Description (Optional)',
                          hint: 'Brief story or culinary specialty of your restaurant',
                          prefixIcon: const Icon(Icons.description_outlined),
                          maxLines: 2,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        AppTextField(
                          controller: _imageUrlController,
                          label: 'Cover Image URL (Optional)',
                          hint: 'https://...',
                          prefixIcon: const Icon(Icons.image_outlined),
                          helperText: 'Accepts HTTPS image URL with local fallback',
                          enabled: !_isLoading,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'Submit for Verification',
                    onPressed: _handleSubmit,
                    isLoading: _isLoading,
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

