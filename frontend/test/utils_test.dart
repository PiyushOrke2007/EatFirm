import 'package:flutter_test/flutter_test.dart';
import 'package:eatfirm/core/utils/date_formatter.dart';
import 'package:eatfirm/core/utils/currency_formatter.dart';
import 'package:eatfirm/core/localization/app_strings.dart';

void main() {
  group('Date and Currency Formatter Tests (SRS Section 6)', () {
    test('AppDateFormatter formats UTC date into IST with DD-MM-YYYY', () {
      // 2026-10-10 12:00:00 UTC -> IST (+5:30) is 2026-10-10 17:30:00 IST
      final utcDate = DateTime.utc(2026, 10, 10, 12, 0, 0);
      final formatted = AppDateFormatter.formatDate(utcDate);

      expect(formatted, equals('10-10-2026'));
    });

    test(
      'AppDateFormatter shifts date across midnight when converting to IST',
      () {
        // 2026-10-10 20:00:00 UTC -> IST (+5:30) is 2026-10-11 01:30:00 IST
        final utcDate = DateTime.utc(2026, 10, 10, 20, 0, 0);
        final formatted = AppDateFormatter.formatDate(utcDate);

        expect(formatted, equals('11-10-2026'));
      },
    );

    test(
      'AppCurrencyFormatter formats with Indian digit grouping and Rupee sign',
      () {
        expect(AppCurrencyFormatter.formatINR(450.0), equals('₹450.00'));
        expect(AppCurrencyFormatter.formatINR(1250.75), equals('₹1,250.75'));
        expect(
          AppCurrencyFormatter.formatINR(1250000.0),
          equals('₹12,50,000.00'),
        );
      },
    );

    test('AppStrings contains centralized required UI tokens', () {
      expect(AppStrings.appName, equals('EatFirm'));
      expect(AppStrings.currencySymbol, equals('₹'));
      expect(AppStrings.email, equals('Email Address'));
    });
  });
}
