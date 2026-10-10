import 'dart:async';

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

class OtpVerificationScreen extends StatefulWidget {
  final AuthApiService authService;
  final String? initialTarget;
  final String purpose;

  const OtpVerificationScreen({
    super.key,
    required this.authService,
    this.initialTarget,
    this.purpose = 'REGISTRATION',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final TextEditingController _targetController;
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 30;
  Timer? _cooldownTimer;

  String? _errorMessage;
  String? _otpError;

  @override
  void initState() {
    super.initState();
    _targetController = TextEditingController(text: widget.initialTarget ?? '');
    _startCooldownTimer();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _targetController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startCooldownTimer() {
    setState(() {
      _resendCooldown = 30;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() {
          _resendCooldown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _handleVerify() async {
    final target = _targetController.text.trim();
    final otpCode = _otpController.text.trim();

    setState(() {
      _otpError = null;
      _errorMessage = null;
    });

    if (otpCode.length != 6) {
      setState(() {
        _otpError = AppStrings.codeRequired;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final message = await widget.authService.verifyOtp(
        target: target,
        otpCode: otpCode,
        purpose: widget.purpose,
      );

      if (!mounted) return;

      AppSnackbar.showSuccess(context, message);

      if (widget.purpose == 'PASSWORD_RESET') {
        context.push(
          '${AppRoutes.resetPassword}?identifier=${Uri.encodeComponent(target)}&otp=${Uri.encodeComponent(otpCode)}',
        );
      } else {
        context.go(AppRoutes.login);
      }
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Verification failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResend() async {
    final target = _targetController.text.trim();
    if (target.isEmpty || _resendCooldown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final message = await widget.authService.resendOtp(
        target: target,
        purpose: widget.purpose,
      );

      if (!mounted) return;
      AppSnackbar.showInfo(context, message);
      _startCooldownTimer();
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      setState(() {
        _errorMessage = 'Failed to resend code. Please try again later.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.verifyOtp),
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
                        Icons.mark_email_read_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    AppStrings.verifyOtp,
                    style: AppTypography.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${AppStrings.verifyOtpSubtitle}\n${_targetController.text}',
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

                  // 6-digit OTP input
                  AppTextField(
                    label: AppStrings.otpCode,
                    hint: '123456',
                    controller: _otpController,
                    errorText: _otpError,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.pin_outlined),
                    enabled: !_isLoading,
                    onSubmitted: (_) => _handleVerify(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Verify Button
                  AppButton(
                    label: AppStrings.confirm,
                    onPressed: _isLoading ? null : _handleVerify,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Resend countdown
                  Center(
                    child: TextButton(
                      onPressed:
                          (_resendCooldown > 0 || _isResending || _isLoading)
                          ? null
                          : _handleResend,
                      child: Text(
                        _resendCooldown > 0
                            ? '${AppStrings.resendOtp} ($_resendCooldown s)'
                            : AppStrings.resendOtp,
                        style: AppTypography.bodySmall.copyWith(
                          color: _resendCooldown > 0
                              ? AppColors.disabledText
                              : AppColors.primary,
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
}
