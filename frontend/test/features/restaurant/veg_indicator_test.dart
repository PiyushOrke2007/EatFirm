import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/features/restaurant/widgets/veg_indicator.dart';

void main() {
  group('VegIndicator Widget Tests (NFR-12)', () {
    testWidgets('VegIndicator renders green symbol with tooltip for veg', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VegIndicator(isVeg: true),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Vegetarian');
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('VegIndicator renders red/non-veg symbol with tooltip for non-veg', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VegIndicator(isVeg: false),
          ),
        ),
      );

      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Non-Vegetarian');
      expect(find.byType(CustomPaint), findsOneWidget);
    });
  });
}

