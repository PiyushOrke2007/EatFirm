import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../network/api_client.dart';
import '../../features/foundation/screens/bootstrap_screen.dart';
import '../../features/foundation/screens/foundation_showcase_screen.dart';
import '../../features/foundation/screens/navigation_shell_screen.dart';
import '../../features/foundation/screens/not_found_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/access_denied_screen.dart';
import '../../features/auth/services/auth_api_service.dart';
import '../../features/auth/services/session_manager.dart';

/// App-wide declarative router using GoRouter.
class AppRouter {
  final ApiClient apiClient;
  final AuthApiService authService;
  final SessionManager sessionManager;

  AppRouter({
    required this.apiClient,
    required this.authService,
    required this.sessionManager,
  });

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.bootstrap,
    refreshListenable: sessionManager,
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final isAuth = sessionManager.isAuthenticated;
      final path = state.uri.path;

      // Protected route: Redirect unauthenticated user to login
      if (path == AppRoutes.profile && !isAuth) {
        return AppRoutes.login;
      }

      // Guest routes: If already signed in, redirect to profile
      if ((path == AppRoutes.login || path == AppRoutes.register) && isAuth) {
        return AppRoutes.profile;
      }

      return null;
    },
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
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) =>
                ProfileScreen(authService: authService),
          ),
        ],
      ),

      // 3. Authentication Routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => LoginScreen(authService: authService),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterScreen(authService: authService),
      ),
      GoRoute(
        path: AppRoutes.verifyOtp,
        builder: (context, state) {
          final target = state.uri.queryParameters['target'];
          final purpose =
              state.uri.queryParameters['purpose'] ?? 'REGISTRATION';
          return OtpVerificationScreen(
            authService: authService,
            initialTarget: target,
            purpose: purpose,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) =>
            ForgotPasswordScreen(authService: authService),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) {
          final identifier = state.uri.queryParameters['identifier'];
          final otp = state.uri.queryParameters['otp'];
          return ResetPasswordScreen(
            authService: authService,
            initialIdentifier: identifier,
            initialOtp: otp,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.accessDenied,
        builder: (context, state) => const AccessDeniedScreen(),
      ),

      // 4. Explicit 404 Route
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
}
