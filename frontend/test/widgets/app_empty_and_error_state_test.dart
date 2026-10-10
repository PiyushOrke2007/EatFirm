import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/shared/widgets/app_empty_state.dart';
import 'package:eatfirm/shared/widgets/app_error_state.dart';

void main() {
  group('Empty and Error State Widget Tests', () {
    testWidgets('AppEmptyState displays information and triggers callback', (
      tester,
    ) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyState(
              title: 'Empty Bag',
              description: 'You have no items in your order bag.',
              actionLabel: 'Find Food',
              onAction: () => actionTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Empty Bag'), findsOneWidget);
      expect(find.text('You have no items in your order bag.'), findsOneWidget);
      expect(find.text('Find Food'), findsOneWidget);

      await tester.tap(find.text('Find Food'));
      expect(actionTriggered, isTrue);
    });

    testWidgets(
      'AppErrorState displays message, correlation ID, and triggers retry',
      (tester) async {
        bool retryTriggered = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AppErrorState(
                title: 'Network Timeout',
                message: 'Server failed to reply in time.',
                requestId: 'req-corr-999',
                retryLabel: 'Try Again',
                onRetry: () => retryTriggered = true,
              ),
            ),
          ),
        );

        expect(find.text('Network Timeout'), findsOneWidget);
        expect(find.text('Server failed to reply in time.'), findsOneWidget);
        expect(find.text('Error Reference: req-corr-999'), findsOneWidget);

        await tester.tap(find.text('Try Again'));
        expect(retryTriggered, isTrue);
      },
    );
  });
}
