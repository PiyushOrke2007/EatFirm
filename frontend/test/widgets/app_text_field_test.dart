import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/shared/widgets/app_text_field.dart';

void main() {
  group('AppTextField Widget Tests', () {
    testWidgets('Renders visible label and captures user text', (tester) async {
      String enteredText = '';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Full Name',
              hint: 'John Doe',
              onChanged: (val) => enteredText = val,
            ),
          ),
        ),
      );

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Keertan');
      expect(enteredText, equals('Keertan'));
    });

    testWidgets('Displays validation error text when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(
              label: 'Email',
              errorText: 'Invalid email address',
            ),
          ),
        ),
      );

      expect(find.text('Invalid email address'), findsOneWidget);
    });

    testWidgets('Toggles password visibility when eye icon tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTextField(label: 'Password', isPassword: true),
          ),
        ),
      );

      TextField textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // Tap toggle icon
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);
    });
  });
}
