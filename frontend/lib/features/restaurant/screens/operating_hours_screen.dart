import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/responsive.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_loading.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../models/operating_hours_model.dart';
import '../services/restaurant_api_service.dart';

/// Weekly Operating Hours Configuration Screen (SRS REST-1, REST-5).
class OperatingHoursScreen extends StatefulWidget {
  final RestaurantApiService restaurantService;

  const OperatingHoursScreen({
    super.key,
    required this.restaurantService,
  });

  @override
  State<OperatingHoursScreen> createState() => _OperatingHoursScreenState();
}

class _OperatingHoursScreenState extends State<OperatingHoursScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _days = [
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  ];

  final Map<String, TextEditingController> _openControllers = {};
  final Map<String, TextEditingController> _closeControllers = {};
  final Map<String, bool> _closedFlags = {};

  @override
  void initState() {
    super.initState();
    for (final day in _days) {
      _openControllers[day] = TextEditingController(text: '09:00');
      _closeControllers[day] = TextEditingController(text: '22:00');
      _closedFlags[day] = false;
    }
    _loadHours();
  }

  @override
  void dispose() {
    for (final c in _openControllers.values) {
      c.dispose();
    }
    for (final c in _closeControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHours() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.restaurantService.getMyRestaurant();
      if (res != null && res.operatingHours.isNotEmpty) {
        for (final h in res.operatingHours) {
          if (_days.contains(h.dayOfWeek)) {
            _openControllers[h.dayOfWeek]?.text = h.openTime;
            _closeControllers[h.dayOfWeek]?.text = h.closeTime;
            _closedFlags[h.dayOfWeek] = h.isClosed;
          }
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _saveSchedule() async {
    // Validate HH:MM format
    final timeRegex = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    for (final day in _days) {
      final open = _openControllers[day]?.text.trim() ?? '';
      final close = _closeControllers[day]?.text.trim() ?? '';
      if (!timeRegex.hasMatch(open)) {
        AppSnackbar.showError(context, 'Invalid opening time for $day (use HH:MM e.g. 09:00)');
        return;
      }
      if (!timeRegex.hasMatch(close)) {
        AppSnackbar.showError(context, 'Invalid closing time for $day (use HH:MM e.g. 22:00)');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final hoursList = _days.map((day) {
        return OperatingHoursModel(
          dayOfWeek: day,
          openTime: _openControllers[day]!.text.trim(),
          closeTime: _closeControllers[day]!.text.trim(),
          isClosed: _closedFlags[day] ?? false,
        );
      }).toList();

      await widget.restaurantService.updateOperatingHours(hoursList);
      if (mounted) {
        AppSnackbar.showSuccess(context, 'Operating hours updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(context, 'Failed to save hours: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator(message: 'Loading operating schedule...')),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Operating Hours Schedule')),
        body: Center(
          child: AppErrorState(
            message: _errorMessage!,
            onRetry: _loadHours,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Operating Hours Schedule'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.restaurantDashboard),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8.0,
            ),
            child: _isSaving
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  )
                : FilledButton.icon(
                    onPressed: _saveSchedule,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Save'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 700 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'Specify 24-hour HH:MM timings for each day. Mark days as closed if non-operational.',
                            style: AppTypography.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  ..._days.map((day) => _buildDayRow(day)),

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDayRow(String day) {
    final isClosed = _closedFlags[day] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: AppTypography.title.copyWith(
                    color: isClosed ? AppColors.textSecondary : AppColors.textPrimary,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Closed',
                      style: AppTypography.caption.copyWith(
                        color: isClosed ? AppColors.error : AppColors.textSecondary,
                        fontWeight: isClosed ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Switch(
                      value: isClosed,
                      activeThumbColor: AppColors.error,
                      onChanged: (val) {
                        setState(() => _closedFlags[day] = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            if (!isClosed) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _openControllers[day],
                      decoration: const InputDecoration(
                        labelText: 'Open (HH:MM)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.wb_sunny_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _closeControllers[day],
                      decoration: const InputDecoration(
                        labelText: 'Close (HH:MM)',
                        border: OutlineInputBorder(),
                        isDense: true,
                        prefixIcon: Icon(Icons.nightlight_round_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
