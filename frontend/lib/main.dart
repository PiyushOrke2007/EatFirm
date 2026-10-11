import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/services/auth_api_service.dart';
import 'features/auth/services/session_manager.dart';
import 'features/restaurant/services/restaurant_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionManager = SessionManager();
  await sessionManager.init();

  final apiClient = ApiClient();
  final authService = AuthApiService(
    apiClient: apiClient,
    sessionManager: sessionManager,
  );
  final restaurantService = RestaurantApiService(apiClient: apiClient);

  final appRouter = AppRouter(
    apiClient: apiClient,
    authService: authService,
    sessionManager: sessionManager,
    restaurantService: restaurantService,
  );

  runApp(EatFirmApp(appRouter: appRouter));
}

class EatFirmApp extends StatelessWidget {
  final AppRouter appRouter;

  const EatFirmApp({super.key, required this.appRouter});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter.router,
    );
  }
}
