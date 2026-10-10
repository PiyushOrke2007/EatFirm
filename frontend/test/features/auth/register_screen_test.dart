import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatfirm/core/localization/app_strings.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/auth/screens/register_screen.dart';
import 'package:eatfirm/features/auth/services/auth_api_service.dart';
import 'package:eatfirm/features/auth/services/session_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionManager sessionManager;
  late ApiClient apiClient;
  late AuthApiService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sessionManager = SessionManager();
    await sessionManager.init();
    apiClient = ApiClient();
    authService = AuthApiService(
      apiClient: apiClient,
      sessionManager: sessionManager,
    );
  });

  testWidgets(
    'RegisterScreen renders allowed roles and strictly excludes SYSTEM_ADMIN',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: RegisterScreen(authService: authService)),
      );

      expect(find.text(AppStrings.registerTitle), findsOneWidget);
      expect(find.text(AppStrings.roleCustomer), findsOneWidget);
      expect(find.text(AppStrings.roleRestaurant), findsOneWidget);
      expect(find.text(AppStrings.roleDelivery), findsOneWidget);

      // SRS REG-1: Disallow public assignment of System Administrator
      expect(find.text(AppStrings.roleAdmin), findsNothing);
      expect(find.text('System Administrator'), findsNothing);

      expect(find.text(AppStrings.fullName), findsOneWidget);
      expect(find.text(AppStrings.email), findsOneWidget);
      expect(find.text(AppStrings.phone), findsOneWidget);
      expect(find.text(AppStrings.password), findsOneWidget);
      expect(find.text(AppStrings.acceptTerms), findsOneWidget);
      expect(find.text(AppStrings.registerButton), findsOneWidget);
    },
  );

  testWidgets('RegisterScreen enforces field validation and terms acceptance', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(authService: authService)),
    );

    // Scroll button into view and tap
    final buttonFinder = find.text(AppStrings.registerButton);
    await tester.ensureVisible(buttonFinder);
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    expect(find.text('Name must be at least 2 characters'), findsOneWidget);
    expect(
      find.text('Provide at least an email address or a phone number'),
      findsOneWidget,
    );
    expect(
      find.text('Password must be at least 8 characters long'),
      findsOneWidget,
    );
    expect(find.text(AppStrings.termsRequired), findsOneWidget);
  });
}
