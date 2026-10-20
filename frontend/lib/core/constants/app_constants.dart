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
  // - On Web: uses current host or http://localhost:5000/api/v1
  // - On Physical Mobile / Any device on Wi-Fi: http://10.10.188.181:5000/api/v1
  static String get defaultApiBaseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
        return 'http://$host:5000/api/v1';
      }
      return 'http://localhost:5000/api/v1';
    }
    return 'http://10.10.188.181:5000/api/v1';
  }

  static const Duration defaultTimeout = Duration(seconds: 15);

  // Localization / Currency (SRS Section 6: Indian Rupees and English)
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String defaultLocale = 'en_IN';
}
