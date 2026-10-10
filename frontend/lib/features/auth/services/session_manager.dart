import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';

/// Centralized session state manager for EatFirm.
/// Persists JWT token and user profile via SharedPreferences and
/// notifies listeners on state transitions (login, logout, profile update).
class SessionManager extends ChangeNotifier {
  static const String _keyToken = 'eatfirm_auth_token';
  static const String _keyUser = 'eatfirm_auth_user';

  final SharedPreferences? prefs;
  String? _token;
  UserModel? _currentUser;
  bool _isInitialized = false;

  SessionManager({this.prefs});

  bool get isInitialized => _isInitialized;
  String? get token => _token;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null && _currentUser != null;
  UserRole? get role => _currentUser?.role;

  /// Loads persisted session from SharedPreferences on app startup.
  Future<void> init() async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    _token = sharedPrefs.getString(_keyToken);
    final userJsonStr = sharedPrefs.getString(_keyUser);

    if (userJsonStr != null && userJsonStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(userJsonStr) as Map<String, dynamic>;
        _currentUser = UserModel.fromJson(decoded);
      } catch (e) {
        // Corrupt local user state, clear
        await sharedPrefs.remove(_keyUser);
        await sharedPrefs.remove(_keyToken);
        _token = null;
        _currentUser = null;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Saves active session upon successful login or registration.
  Future<void> saveSession(String token, UserModel user) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    _token = token;
    _currentUser = user;

    await sharedPrefs.setString(_keyToken, token);
    await sharedPrefs.setString(_keyUser, jsonEncode(user.toJson()));

    notifyListeners();
  }

  /// Updates current user profile details (e.g. after editing profile or OTP verification).
  Future<void> updateUser(UserModel user) async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    _currentUser = user;
    await sharedPrefs.setString(_keyUser, jsonEncode(user.toJson()));

    notifyListeners();
  }

  /// Clears active session upon logout or 401 Unauthorized expiry.
  Future<void> clearSession() async {
    final sharedPrefs = prefs ?? await SharedPreferences.getInstance();
    _token = null;
    _currentUser = null;

    await sharedPrefs.remove(_keyToken);
    await sharedPrefs.remove(_keyUser);

    notifyListeners();
  }
}
