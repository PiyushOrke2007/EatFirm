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
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../models/user_model.dart';
import '../services/auth_api_service.dart';

class ProfileScreen extends StatefulWidget {
  final AuthApiService authService;

  const ProfileScreen({super.key, required this.authService});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final cached = widget.authService.sessionManager.currentUser;
    if (cached != null) {
      setState(() {
        _user = cached;
      });
    }

    try {
      final user = await widget.authService.getProfile();
      if (mounted) {
        setState(() {
          _user = user;
        });
      }
    } catch (_) {
      // Use cached user if network fails
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: AppStrings.logoutConfirmTitle,
      message: AppStrings.logoutConfirmMessage,
      confirmText: AppStrings.logout,
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      await widget.authService.logout();
      if (!mounted) return;
      AppSnackbar.showInfo(context, 'You have been logged out.');
      context.go(AppRoutes.login);
    }
  }

  void _showEditProfileDialog() {
    if (_user == null) return;

    final nameController = TextEditingController(text: _user!.name);
    final phoneController = TextEditingController(text: _user!.phone ?? '');
    String? dialogError;
    bool isSaving = false;

    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: AppRadius.brLg),
              title: const Text(AppStrings.editProfile),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dialogError != null) ...[
                      Text(
                        dialogError!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AppTextField(
                      label: AppStrings.fullName,
                      controller: nameController,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      label: AppStrings.phone,
                      hint: '10-digit number',
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                  child: const Text(AppStrings.cancel),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();

                          if (name.isEmpty || name.length < 2) {
                            setDialogState(() {
                              dialogError =
                                  'Name must be at least 2 characters';
                            });
                            return;
                          }

                          if (phone.isNotEmpty &&
                              phone.replaceAll(RegExp(r'\D'), '').length !=
                                  10) {
                            setDialogState(() {
                              dialogError = 'Phone number must be 10 digits';
                            });
                            return;
                          }

                          setDialogState(() {
                            isSaving = true;
                            dialogError = null;
                          });

                          try {
                            final updated = await widget.authService
                                .updateProfile(
                                  name: name,
                                  phone: phone.isNotEmpty ? phone : null,
                                );
                            if (!mounted) return;
                            setState(() {
                              _user = updated;
                            });
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } on ApiException catch (e) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = e.message;
                            });
                          } catch (_) {
                            setDialogState(() {
                              isSaving = false;
                              dialogError = 'Failed to update profile';
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.submit),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _testAdminPrivileges() async {
    try {
      final res = await widget.authService.apiClient.get<Map<String, dynamic>>(
        '/auth/admin-check',
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(
        context,
        'Admin access confirmed: ${res.data['role']}',
      );
    } on ForbiddenException {
      if (!mounted) return;
      context.push(AppRoutes.accessDenied);
    } on ApiException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final user = _user;

    if (user == null && _isLoading) {
      return const Scaffold(body: Center(child: AppLoadingIndicator()));
    }

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.profileTitle)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active session found.'),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: AppStrings.login,
                onPressed: () => context.go(AppRoutes.login),
                isFullWidth: false,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.error),
            tooltip: AppStrings.logout,
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isDesktop ? 600 : double.infinity,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Avatar & Role Badge Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.name.isNotEmpty
                              ? user.name.substring(0, 1).toUpperCase()
                              : 'U',
                          style: AppTypography.display.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        user.name,
                        style: AppTypography.headline,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _buildRoleBadge(user.role),
                      const SizedBox(height: AppSpacing.xs),
                      _buildVerificationBadge(user.isVerified),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Account Details Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Account Details', style: AppTypography.title),
                          TextButton.icon(
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text(AppStrings.editProfile),
                            onPressed: _showEditProfileDialog,
                          ),
                        ],
                      ),
                      const Divider(),
                      _buildDetailRow(
                        icon: Icons.email_outlined,
                        label: AppStrings.email,
                        value: user.email ?? 'Not linked',
                      ),
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        label: AppStrings.phone,
                        value: user.phone != null
                            ? '+91 ${user.phone}'
                            : 'Not linked',
                      ),
                      _buildDetailRow(
                        icon: Icons.verified_user_outlined,
                        label: 'Status',
                        value: user.accountStatus,
                      ),
                      _buildDetailRow(
                        icon: Icons.login_outlined,
                        label: 'Last Sign In',
                        value: user.lastLoginAt != null
                            ? AppDateFormatter.formatDateTime(user.lastLoginAt!)
                            : 'First session',
                      ),
                      _buildDetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Member Since',
                        value: user.createdAt != null
                            ? AppDateFormatter.formatDateTime(user.createdAt!)
                            : 'Recently',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // RBAC Verification Surface (Module 02 Acceptance Gate)
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Security & Role Verification',
                        style: AppTypography.title,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Verify server-side RBAC enforcement. Non-admin roles will receive an immediate 403 Forbidden response.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton(
                        label: 'Test Admin Role Access (RBAC Guard)',
                        variant: AppButtonVariant.outline,
                        onPressed: _testAdminPrivileges,
                        icon: const Icon(Icons.security, size: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Logout Action Button
                AppButton(
                  label: AppStrings.logout,
                  variant: AppButtonVariant.destructive,
                  onPressed: _handleLogout,
                  icon: const Icon(Icons.logout, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    AppBadgeType type = AppBadgeType.neutral;
    switch (role) {
      case UserRole.systemAdmin:
        type = AppBadgeType.error;
        break;
      case UserRole.restaurantAdmin:
        type = AppBadgeType.warning;
        break;
      case UserRole.deliveryPartner:
        type = AppBadgeType.info;
        break;
      case UserRole.customer:
        type = AppBadgeType.success;
        break;
    }
    return AppBadge(label: role.displayName, type: type);
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return AppBadge(
      label: isVerified ? AppStrings.verified : AppStrings.unverified,
      type: isVerified ? AppBadgeType.success : AppBadgeType.warning,
      icon: isVerified ? Icons.check_circle : Icons.warning_amber_rounded,
    );
  }
}
