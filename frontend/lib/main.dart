import 'package:flutter/material.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final appRouter = AppRouter(apiClient: apiClient);

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
