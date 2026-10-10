import 'package:intl/intl.dart';

/// Date formatting utility adhering strictly to SRS Section 6:
/// "Dates shall be displayed in the DD-MM-YYYY format...
/// All dates and times shall be stored in UTC and converted to
/// Indian Standard Time only while displaying them."
class AppDateFormatter {
  AppDateFormatter._();

  static final DateFormat _ddmmyyyyFormat = DateFormat('dd-MM-yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd-MM-yyyy hh:mm a');

  /// Converts a UTC DateTime to Indian Standard Time (UTC+5:30) and formats as DD-MM-YYYY.
  static String formatDate(DateTime utcDateTime) {
    final istDateTime = toIST(utcDateTime);
    return _ddmmyyyyFormat.format(istDateTime);
  }

  /// Converts a UTC DateTime to Indian Standard Time (UTC+5:30) and formats as DD-MM-YYYY hh:mm a.
  static String formatDateTime(DateTime utcDateTime) {
    final istDateTime = toIST(utcDateTime);
    return _dateTimeFormat.format(istDateTime);
  }

  /// Converts any UTC date to Indian Standard Time (IST, UTC+05:30).
  static DateTime toIST(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(const Duration(hours: 5, minutes: 30));
  }
}
