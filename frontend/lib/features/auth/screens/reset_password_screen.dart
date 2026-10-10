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
import '../services/auth_api_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final AuthApiService authService;
  final String? initialIdentifier;
  final String? initialOtp;

  const ResetPasswordScreen({
    super.key,
    required this.authService,
    this.initialIdentifier,
    this.initialOtp,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final TextEditingController _identifierController;
  late final TextEditingController _otpController;
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _passwordError;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController(
      text: widget.initialIdentifier ?? '',
    );
    _otpController = TextEditingController(text: widget.initialOtp ?? '');
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() {
      _errorMessage = null;
      _otpError = null;
      _passwordError = null;
    });

    bool isValid = true;
    if (_otpController.text.trim().length != 6) {
      _otpError = AppStrings.codeRequired;
      isValid = false;
    }

    final pass = _passwordController.text;
    if (pass.length < 8) {
      _passwordError = 'Password must be at least 8 characters long';
      isValid = false;
    } else {
      final hasUpper = RegExp(r'[A-Z]').hasMatch(pass);
      final hasLower = RegExp(r'[a-z]').hasMatch(pass);
      final hasDigit = RegExp(r'[0-9]').hasMatch(pass);
      final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass);

      if (!hasUpper || !hasLower || !hasDigit || !hasSpecial) {
        _passwordError =
            'Must contain uppercase, lowercase, digit, and special symbol';
        isValid = false;
      }
    }

    setState(() {});
    return isValid;
  }

  Future<void> _handleReset() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final message = await widget.authService.resetPassword(
        identifier: _identifierController.text.trim(),
        otpCode: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );

      if (!mounted) return;
      AppSnackbar.showSuccess(context, message);

      context.go(AppRoutes.login);
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Password reset failed. Please try again.';
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
      appBar: AppBar(
        title: const Text(AppStrings.resetPassword),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 460 : double.infinity,
            ),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: AppRadius.brLg,
                      ),
                      child: const Icon(
                        Icons.password_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.resetPassword,
                    style: AppTypography.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppStrings.resetPasswordSubtitle,
                    style: AppTypography.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),

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

                  AppTextField(
                    label: AppStrings.identifier,
                    controller: _identifierController,
                    readOnly: widget.initialIdentifier != null,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: AppStrings.otpCode,
                    hint: '123456',
                    controller: _otpController,
                    errorText: _otpError,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.pin_outlined),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    label: AppStrings.newPassword,
                    hint: AppStrings.passwordHint,
                    controller: _passwordController,
                    errorText: _passwordError,
                    isPassword: true,
                    prefixIcon: const Icon(Icons.lock_outline),
                    enabled: !_isLoading,
                    onSubmitted: (_) => _handleReset(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: AppStrings.submit,
                    onPressed: _isLoading ? null : _handleReset,
                    isLoading: _isLoading,
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
