/// Currency formatter adhering to SRS Section 6:
/// "numbers shall use the Indian digit grouping and only in Indian Rupees."
class AppCurrencyFormatter {
  AppCurrencyFormatter._();

  /// Formats an amount into standard Indian Rupee notation (e.g. ₹1,23,456.50).
  static String formatINR(double amount) {
    final isNegative = amount < 0;
    final fixedStr = amount.abs().toStringAsFixed(2);
    final parts = fixedStr.split('.');
    final rupees = parts[0];
    final paise = parts[1];

    String formattedRupees = '';
    if (rupees.length <= 3) {
      formattedRupees = rupees;
    } else {
      final lastThree = rupees.substring(rupees.length - 3);
      final remaining = rupees.substring(0, rupees.length - 3);
      final groups = <String>[];
      for (int i = remaining.length; i > 0; i -= 2) {
        final start = (i - 2) < 0 ? 0 : i - 2;
        groups.insert(0, remaining.substring(start, i));
      }
      formattedRupees = '${groups.join(',')},$lastThree';
    }

    return '${isNegative ? '-' : ''}₹$formattedRupees.$paise';
  }
}
