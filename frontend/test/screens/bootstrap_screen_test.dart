import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:eatfirm/core/network/api_client.dart';
import 'package:eatfirm/features/foundation/screens/bootstrap_screen.dart';

void main() {
  group('BootstrapScreen Tests', () {
    testWidgets(
      'Displays connection notice and retry button when health check fails',
      (tester) async {
        final mockClient = MockClient((request) async {
          return http.Response('Service Unavailable', 503);
        });

        final apiClient = ApiClient(httpClient: mockClient);

        await tester.pumpWidget(
          MaterialApp(home: BootstrapScreen(apiClient: apiClient)),
        );

        // Initial pump
        await tester.pump();
        // Allow async future to settle
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Connection Notice'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      },
    );
  });
}
