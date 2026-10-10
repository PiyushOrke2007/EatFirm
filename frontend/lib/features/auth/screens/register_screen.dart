import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class RegisterScreen extends StatefulWidget {
  final AuthApiService authService;

  const RegisterScreen({super.key, required this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;
  bool _termsAccepted = false;
  bool _isLoading = false;

  String? _errorMessage;
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;
  String? _termsError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
      _termsError = null;
      _errorMessage = null;
    });

    bool isValid = true;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || name.length < 2) {
      _nameError = 'Name must be at least 2 characters';
      isValid = false;
    }

    if (email.isEmpty && phone.isEmpty) {
      _emailError = 'Provide at least an email address or a phone number';
      isValid = false;
    }

    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
      if (!emailRegex.hasMatch(email)) {
        _emailError = 'Please enter a valid email address';
        isValid = false;
      }
    }

    if (phone.isNotEmpty) {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 10) {
        _phoneError = 'Phone number must be exactly 10 digits';
        isValid = false;
      }
    }

    if (password.length < 8) {
      _passwordError = 'Password must be at least 8 characters long';
      isValid = false;
    } else {
      final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
      final hasLower = RegExp(r'[a-z]').hasMatch(password);
      final hasDigit = RegExp(r'[0-9]').hasMatch(password);
      final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password);

      if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
        _passwordError =
            'Must include uppercase, lowercase, digit, and special symbol';
        isValid = false;
      }
    }

    if (!_termsAccepted) {
      _termsError = AppStrings.termsRequired;
      isValid = false;
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleRegister() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        password: _passwordController.text,
        role: _selectedRole,
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;

      final otpTarget =
          result['otpSentTo'] as String? ?? _emailController.text.trim();

      AppSnackbar.showSuccess(
        context,
        'Registration successful! Verification code sent.',
      );

      context.push(
        '${AppRoutes.verifyOtp}?target=${Uri.encodeComponent(otpTarget)}',
      );
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.appName), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 500 : double.infinity,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title Header
                  Text(
                    AppStrings.registerTitle,
                    style: AppTypography.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.registerSubtitle,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Error Banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: AppRadius.brMd,
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
                              style: AppTypography.caption.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Role Selection Chips (SRS REG-1: Only Customer, Restaurant, Delivery allowed)
                  Text(
                    AppStrings.roleSelectorLabel,
                    style: AppTypography.label,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _buildRoleChip(
                        UserRole.customer,
                        AppStrings.roleCustomer,
                        Icons.person,
                      ),
                      _buildRoleChip(
                        UserRole.restaurantAdmin,
                        AppStrings.roleRestaurant,
                        Icons.restaurant,
                      ),
                      _buildRoleChip(
                        UserRole.deliveryPartner,
                        AppStrings.roleDelivery,
                        Icons.two_wheeler,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Form Inputs
                  AppTextField(
                    label: AppStrings.fullName,
                    hint: AppStrings.fullNamePlaceholder,
                    controller: _nameController,
                    errorText: _nameError,
                    prefixIcon: const Icon(Icons.badge_outlined),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: AppStrings.email,
                    hint: AppStrings.emailPlaceholder,
                    controller: _emailController,
                    errorText: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: const Icon(Icons.email_outlined),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: AppStrings.phone,
                    hint: AppStrings.phonePlaceholder,
                    controller: _phoneController,
                    errorText: _phoneError,
                    keyboardType: TextInputType.phone,
                    prefixIcon: const Icon(Icons.phone_outlined),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: AppStrings.password,
                    hint: AppStrings.passwordHint,
                    controller: _passwordController,
                    errorText: _passwordError,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Terms of Service Acceptance
                  Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppColors.primary;
                          }
                          return null;
                        }),
                      ),
                    ),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _termsAccepted,
                      onChanged: _isLoading
                          ? null
                          : (val) {
                              setState(() {
                                _termsAccepted = val ?? false;
                                if (_termsAccepted) _termsError = null;
                              });
                            },
                      title: Text(
                        AppStrings.acceptTerms,
                        style: AppTypography.caption.copyWith(
                          color: _termsError != null
                              ? AppColors.error
                              : AppColors.textPrimary,
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  if (_termsError != null)
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 36,
                        bottom: AppSpacing.xs,
                      ),
                      child: Text(
                        _termsError!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),

                  // Submit Button
                  AppButton(
                    label: AppStrings.registerButton,
                    onPressed: _isLoading ? null : _handleRegister,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Link to Login
                  Center(
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.push(AppRoutes.login),
                      child: Text(
                        AppStrings.alreadyHaveAccount,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(UserRole role, String label, IconData icon) {
    final isSelected = _selectedRole == role;
    return ChoiceChip(
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 18,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: AppTypography.label.copyWith(
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      onSelected: _isLoading
          ? null
          : (selected) {
              if (selected) {
                setState(() {
                  _selectedRole = role;
                });
              }
            },
    );
  }
}
