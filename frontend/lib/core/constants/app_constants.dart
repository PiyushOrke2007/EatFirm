/// Global constants for EatFirm client.
class AppConstants {
  AppConstants._();

  static const String appName = 'EatFirm';
  static const String appTagline = 'Gourmet at your doorstep';
  static const String appVersion = '1.0.0';

  // Network Defaults
  static const String defaultApiBaseUrl = 'http://localhost:5000/api/v1';
  static const Duration defaultTimeout = Duration(seconds: 15);

  // Localization / Currency (SRS Section 6: Indian Rupees and English)
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String defaultLocale = 'en_IN';
}

