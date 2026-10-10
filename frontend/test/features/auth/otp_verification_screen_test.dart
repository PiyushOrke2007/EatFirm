import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatfirm/core/localization/app_strings.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/auth/screens/otp_verification_screen.dart';
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

  testWidgets('OtpVerificationScreen renders verification elements', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          authService: authService,
          initialTarget: 'user@example.com',
        ),
      ),
    );

    expect(find.text(AppStrings.verifyOtp), findsWidgets);
    expect(find.text(AppStrings.otpCode), findsOneWidget);
    expect(find.text(AppStrings.confirm), findsOneWidget);
    expect(find.textContaining('user@example.com'), findsOneWidget);
  });

  testWidgets('OtpVerificationScreen validates 6-digit code requirement', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OtpVerificationScreen(
          authService: authService,
          initialTarget: 'user@example.com',
        ),
      ),
    );

    // Tap confirm button with empty code
    await tester.tap(find.text(AppStrings.confirm));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.codeRequired), findsOneWidget);
  });
}
