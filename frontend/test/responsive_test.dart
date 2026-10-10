import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/theme/responsive.dart';

void main() {
  group('Responsive Layout Tests', () {
    testWidgets('Responsive.isMobile returns true for narrow width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isMobile;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = Responsive.isMobile(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isMobile, isTrue);
    });

    testWidgets('Responsive.isDesktop returns true for desktop width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool? isDesktop;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isDesktop = Responsive.isDesktop(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(isDesktop, isTrue);
    });

    testWidgets('ResponsiveLayout selects desktop widget on wide screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: ResponsiveLayout(
            mobile: Text('Mobile View'),
            desktop: Text('Desktop View'),
          ),
        ),
      );

      expect(find.text('Desktop View'), findsOneWidget);
      expect(find.text('Mobile View'), findsNothing);
    });
  });
}
