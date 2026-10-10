import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatfirm/core/localization/app_strings.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/auth/screens/login_screen.dart';
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

  testWidgets('LoginScreen renders fields, labels and buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );

    expect(find.text(AppStrings.loginTitle), findsOneWidget);
    expect(find.text(AppStrings.identifier), findsOneWidget);
    expect(find.text(AppStrings.password), findsOneWidget);
    expect(find.text(AppStrings.loginButton), findsOneWidget);
    expect(find.text(AppStrings.forgotPassword), findsOneWidget);
    expect(find.text(AppStrings.dontHaveAccount), findsOneWidget);
  });

  testWidgets('LoginScreen shows validation errors when submitted empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(authService: authService)),
    );

    // Tap submit button with empty inputs
    await tester.tap(find.text(AppStrings.loginButton));
    await tester.pumpAndSettle();

    expect(
      find.text('Email address or phone number is required'),
      findsOneWidget,
    );
    expect(find.text('Password is required'), findsOneWidget);
  });
}
