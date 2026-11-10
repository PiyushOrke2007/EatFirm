import 'package:flutter/foundation.dart';

import '../network/lan_discovery.dart';

/// Global constants for EatFirm client.
class AppConstants {
  AppConstants._();

  static const String appName = 'EatFirm';
  static const String appTagline = 'Gourmet at your doorstep';
  static const String appVersion = '1.0.0';

  // Override without changing source code:
  // --dart-define=API_URL=http://<HOST>:5000/api/v1
  static const String _envApiUrl = String.fromEnvironment('API_URL');
  static const int apiPort = 5000;
  static const int discoveryPort = 5001;

  static Future<String> resolveApiBaseUrl() async {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }

    if (!kIsWeb) {
      final discoveredUrl = await discoverApiBaseUrl(
        discoveryPort: discoveryPort,
        apiPort: apiPort,
      );
      if (discoveredUrl != null) {
        return discoveredUrl;
      }
    }

    return defaultApiBaseUrl;
  }

  static String get defaultApiBaseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }

    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.isNotEmpty) {
        return 'http://$host:$apiPort/api/v1';
      }
    }

    // Physical devices or emulators on local network:
    // Defaults to current laptop Wi-Fi IP (192.168.1.34)
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.34:$apiPort/api/v1';
    }

    return 'http://192.168.1.34:$apiPort/api/v1';
  }

  static const Duration defaultTimeout = Duration(seconds: 15);

  // Localization / Currency (SRS Section 6: Indian Rupees and English)
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const String defaultLocale = 'en_IN';
}
