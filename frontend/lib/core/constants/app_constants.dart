import 'package:flutter/foundation.dart';

/// Global constants for EatFirm client.
class AppConstants {
  AppConstants._();

  static const String appName = 'EatFirm';
  static const String appTagline = 'Gourmet at your doorstep';
  static const String appVersion = '1.0.0';

  // Environment override: pass via --dart-define=API_URL=http://<IP>:5000/api/v1
  static const String _envApiUrl = String.fromEnvironment('API_URL');

  // Network Defaults:
  // - On Web: uses http://localhost:5000/api/v1
  // - On Physical Mobile (Wi-Fi): uses laptop's local IP http://192.168.1.36:5000/api/v1
  static String get defaultApiBaseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:5000/api/v1';
    }
    return 'http://192.168.1.36:5000/api/v1';
  }

  static const Duration defaultTimeout = Duration(seconds: 15);

  // Localization / Currency (SRS Section 6: Indian Rupees and English)
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String defaultLocale = 'en_IN';
}
