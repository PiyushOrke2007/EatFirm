import 'package:go_router/go_router.dart';

import 'app_routes.dart';
import '../network/api_client.dart';
import '../../features/foundation/screens/bootstrap_screen.dart';
import '../../features/foundation/screens/foundation_showcase_screen.dart';
import '../../features/foundation/screens/navigation_shell_screen.dart';
import '../../features/foundation/screens/not_found_screen.dart';
import '../../features/auth/models/user_model.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/access_denied_screen.dart';
import '../../features/auth/services/auth_api_service.dart';
import '../../features/auth/services/session_manager.dart';
import '../../features/restaurant/screens/admin_approval_screen.dart';
import '../../features/restaurant/screens/menu_management_screen.dart';
import '../../features/restaurant/screens/operating_hours_screen.dart';
import '../../features/restaurant/screens/restaurant_dashboard_screen.dart';
import '../../features/restaurant/screens/restaurant_onboarding_screen.dart';
import '../../features/restaurant/services/restaurant_api_service.dart';
import '../../features/browse/providers/browse_provider.dart';
import '../../features/browse/screens/customer_discovery_screen.dart';
import '../../features/browse/screens/customer_restaurant_menu_screen.dart';
import '../../features/browse/services/browse_api_service.dart';
import '../../features/cart_order/providers/cart_order_provider.dart';
import '../../features/cart_order/screens/cart_screen.dart';
import '../../features/cart_order/screens/checkout_screen.dart';
import '../../features/cart_order/screens/order_confirmation_screen.dart';
import '../../features/cart_order/screens/order_detail_screen.dart';
import '../../features/cart_order/screens/order_history_screen.dart';
import '../../features/cart_order/services/cart_order_api_service.dart';

/// App-wide declarative router using GoRouter.
class AppRouter {
  final ApiClient apiClient;
  final AuthApiService authService;
  final SessionManager sessionManager;
  final RestaurantApiService restaurantService;
  final BrowseApiService browseService;
  late final BrowseProvider browseProvider;
  final CartOrderApiService cartOrderService;
  late final CartOrderProvider cartOrderProvider;

  AppRouter({
    required this.apiClient,
    required this.authService,
    required this.sessionManager,
    required this.restaurantService,
    BrowseApiService? browseService,
    CartOrderApiService? cartOrderService,
  })  : browseService = browseService ?? BrowseApiService(apiClient: apiClient),
        cartOrderService =
            cartOrderService ?? CartOrderApiService(apiClient: apiClient) {
    browseProvider = BrowseProvider(browseService: this.browseService);
    cartOrderProvider = CartOrderProvider(apiService: this.cartOrderService);
  }

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.bootstrap,
    refreshListenable: sessionManager,
    errorBuilder: (context, state) => const NotFoundScreen(),
    redirect: (context, state) {
      final isAuth = sessionManager.isAuthenticated;
      final role = sessionManager.role;
      final path = state.uri.path;

      // Protected routes: Redirect unauthenticated user to login
      if ((path == AppRoutes.profile ||
              path == AppRoutes.cart ||
              path == AppRoutes.checkout ||
              path.startsWith('/orders')) &&
          !isAuth) {
        return AppRoutes.login;
      }

      // Guest routes: If already signed in, redirect to profile
      if ((path == AppRoutes.login || path == AppRoutes.register) && isAuth) {
        return AppRoutes.profile;
      }

      // Restaurant Admin routes: Require authentication & RESTAURANT_ADMIN (or SYSTEM_ADMIN)
      if (path.startsWith('/restaurant/') && !path.startsWith(AppRoutes.restaurantDetails)) {
        if (!isAuth) return AppRoutes.login;
        if (role != UserRole.restaurantAdmin && role != UserRole.systemAdmin) {
          return AppRoutes.accessDenied;
        }
      }

      // System Admin routes: Require authentication & SYSTEM_ADMIN
      if (path.startsWith('/admin')) {
        if (!isAuth) return AppRoutes.login;
        if (role != UserRole.systemAdmin) {
          return AppRoutes.accessDenied;
        }
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
            path: AppRoutes.discovery,
            builder: (context, state) =>
                CustomerDiscoveryScreen(provider: browseProvider),
          ),
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

      // 4. Restaurant Management Routes (Module 03)
      GoRoute(
        path: AppRoutes.restaurantDashboard,
        builder: (context, state) =>
            RestaurantDashboardScreen(restaurantService: restaurantService),
      ),
      GoRoute(
        path: AppRoutes.restaurantOnboard,
        builder: (context, state) =>
            RestaurantOnboardingScreen(restaurantService: restaurantService),
      ),
      GoRoute(
        path: AppRoutes.restaurantMenu,
        builder: (context, state) =>
            MenuManagementScreen(restaurantService: restaurantService),
      ),
      GoRoute(
        path: AppRoutes.restaurantHours,
        builder: (context, state) =>
            OperatingHoursScreen(restaurantService: restaurantService),
      ),

      // 5. System Administrator Approvals (Module 03)
      GoRoute(
        path: AppRoutes.adminApprovals,
        builder: (context, state) =>
            AdminApprovalScreen(restaurantService: restaurantService),
      ),

      // 6. Customer Restaurant Details & Menu (Module 04, BROWSE-3)
      GoRoute(
        path: '${AppRoutes.restaurantDetails}/:id',
        builder: (context, state) {
          final restaurantId = state.pathParameters['id'] ?? '';
          return CustomerRestaurantMenuScreen(
            restaurantId: restaurantId,
            browseService: browseService,
            cartProvider: cartOrderProvider,
          );
        },
      ),

      // 7. Cart, Checkout & Orders Routes (Module 05)
      GoRoute(
        path: AppRoutes.cart,
        builder: (context, state) => CartScreen(provider: cartOrderProvider),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        builder: (context, state) => CheckoutScreen(
          provider: cartOrderProvider,
          sessionManager: sessionManager,
        ),
      ),
      GoRoute(
        path: AppRoutes.orders,
        builder: (context, state) =>
            OrderHistoryScreen(provider: cartOrderProvider),
      ),
      GoRoute(
        path: AppRoutes.orderDetail,
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderDetailScreen(
            orderId: orderId,
            provider: cartOrderProvider,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.orderConfirmation,
        builder: (context, state) {
          final orderId = state.pathParameters['id'] ?? '';
          return OrderConfirmationScreen(
            orderId: orderId,
            provider: cartOrderProvider,
          );
        },
      ),

      // 8. Explicit 404 Route
      GoRoute(
        path: AppRoutes.notFound,
        builder: (context, state) => const NotFoundScreen(),
      ),
    ],
  );
}
