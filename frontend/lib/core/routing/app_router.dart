import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../network/api_client.dart';
import '../../features/foundation/screens/bootstrap_screen.dart';
import '../../features/foundation/screens/foundation_showcase_screen.dart';
import '../../features/foundation/screens/navigation_shell_screen.dart';
import '../../features/foundation/screens/not_found_screen.dart';

/// App-wide declarative router using GoRouter.
class AppRouter {
  final ApiClient apiClient;

  AppRouter({required this.apiClient});

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.bootstrap,
    errorBuilder: (context, state) => const NotFoundScreen(),
    routes: [
      // 1. App Bootstrap (Checks server health, shows splash)
      GoRoute(
        path: AppRoutes.bootstrap,
        builder: (context, state) => BootstrapScreen(apiClient: apiClient),
      ),

      // 2. Application Navigation Shell
      ShellRoute(
        builder: (context, state, child) {
          return NavigationShellScreen(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.showcase,
            builder: (context, state) =>
                FoundationShowcaseScreen(apiClient: apiClient),
          ),
        ],
      ),

      // 3. Explicit 404 Route
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
}
