import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button.dart';

/// Initial bootstrap screen that verifies backend connectivity and health
/// before directing users into the appropriate application route.
class BootstrapScreen extends StatefulWidget {
  final ApiClient? apiClient;

  const BootstrapScreen({super.key, this.apiClient});

  @override
  State<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<BootstrapScreen> {
  late final ApiClient _apiClient;
  bool _isLoading = true;
  String? _errorMessage;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient();
    _checkSystemHealth();
  }

  Future<void> _checkSystemHealth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _requestId = null;
    });

    try {
      // Connect to real backend health probe
      final response = await _apiClient.get('/health');
      if (response.success && mounted) {
        // Smooth transition to design system showcase / home
        context.go('/showcase');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
        _requestId = e.requestId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not connect to EatFirm server at ${_apiClient.baseUrl}.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo Container
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.restaurant_menu,
                      size: 52,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // App Title
                Text(
                  AppConstants.appName.toUpperCase(),
                  style: AppTypography.display.copyWith(
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // Tagline
                Text(
                  AppConstants.appTagline,
                  style: AppTypography.body.copyWith(
                    color: Colors.white.withAlpha(220),
                  ),
                ),

                const SizedBox(height: AppSpacing.xxl),

                // State handling: Loading vs Error with Retry
                if (_isLoading) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Connecting to EatFirm services...',
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 36,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Connection Notice', style: AppTypography.title),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (_requestId != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Request ID: $_requestId',
                            style: AppTypography.caption,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Retry',
                                onPressed: _checkSystemHealth,
                                height: 40,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppButton(
                                label: 'Continue',
                                variant: AppButtonVariant.outline,
                                height: 40,
                                onPressed: () {
                                  context.go('/showcase');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
