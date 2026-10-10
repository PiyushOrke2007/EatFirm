import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_scaffold.dart';

/// 404 Not Found screen when navigating to an unmapped path.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Page Not Found',
      body: AppEmptyState(
        icon: Icons.search_off_outlined,
        title: '404 - Not Found',
        description: 'The requested page or resource could not be found.',
        actionLabel: 'Go to Home',
        onAction: () => context.go('/showcase'),
      ),
    );
  }
}
