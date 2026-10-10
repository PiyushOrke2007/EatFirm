import '../../../core/network/api_client.dart';
import '../models/user_model.dart';
import 'session_manager.dart';

class AuthApiService {
  final ApiClient apiClient;
  final SessionManager sessionManager;

  AuthApiService({required this.apiClient, required this.sessionManager}) {
    // Hook session token into ApiClient Bearer authorization header
    apiClient.setAuthTokenProvider(() => sessionManager.token);
  }

  /// AUTH-01: Register user with role, credentials, and terms acceptance
  Future<Map<String, dynamic>> register({
    required String name,
    String? email,
    String? phone,
    required String password,
    required UserRole role,
    required bool termsAccepted,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        'password': password,
        'role': role.toServerString(),
        'termsAccepted': termsAccepted,
      },
    );

    return response.data;
  }

  /// AUTH-02: Sign in with identifier (email/phone) and password
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/login',
      body: {'identifier': identifier.trim(), 'password': password},
    );

    final data = response.data;
    final token = data['token'] as String;
    final userJson = data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);

    // Save session locally
    await sessionManager.saveSession(token, user);
    return user;
  }

  /// AUTH-03: Verify OTP code for registration or password reset
  Future<String> verifyOtp({
    required String target,
    required String otpCode,
    String purpose = 'REGISTRATION',
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/verify-otp',
      body: {
        'target': target.trim(),
        'otpCode': otpCode.trim(),
        'purpose': purpose,
      },
    );

    // If verified while logged in, update local verified status
    if (sessionManager.currentUser != null && purpose == 'REGISTRATION') {
      await sessionManager.updateUser(
        sessionManager.currentUser!.copyWith(isVerified: true),
      );
    }

    return (response.data['message'] as String?) ?? 'Verification successful';
  }

  /// Resend OTP verification code
  Future<String> resendOtp({
    required String target,
    String purpose = 'REGISTRATION',
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/resend-otp',
      body: {'target': target.trim(), 'purpose': purpose},
    );

    return (response.data['message'] as String?) ?? 'Verification code sent';
  }

  /// AUTH-04: Logout and session revocation
  Future<void> logout() async {
    try {
      if (sessionManager.isAuthenticated) {
        await apiClient.post('/auth/logout');
      }
    } catch (_) {
      // Even if network fails, ensure local credentials are cleared
    } finally {
      await sessionManager.clearSession();
    }
  }

  /// Password Reset Flow (SRS LOGIN-2)
  Future<String> forgotPassword({required String identifier}) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/forgot-password',
      body: {'identifier': identifier.trim()},
    );

    return (response.data['message'] as String?) ??
        'If an account exists, a reset code has been sent.';
  }

  Future<String> resetPassword({
    required String identifier,
    required String otpCode,
    required String newPassword,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/auth/reset-password',
      body: {
        'identifier': identifier.trim(),
        'otpCode': otpCode.trim(),
        'newPassword': newPassword,
      },
    );

    return (response.data['message'] as String?) ??
        'Password has been reset successfully.';
  }

  /// AUTH-06: Profile management
  Future<UserModel> getProfile() async {
    final response = await apiClient.get<Map<String, dynamic>>('/auth/me');
    final userJson = response.data['user'] as Map<String, dynamic>;
    final user = UserModel.fromJson(userJson);
    await sessionManager.updateUser(user);
    return user;
  }

  Future<UserModel> updateProfile({String? name, String? phone}) async {
    final response = await apiClient.patch<Map<String, dynamic>>(
      '/auth/profile',
      body: {
        if (name != null) 'name': name.trim(),
        if (phone != null) 'phone': phone.trim(),
      },
    );

    final userJson = response.data['user'] as Map<String, dynamic>;
    final updatedUser = UserModel.fromJson(userJson);
    await sessionManager.updateUser(updatedUser);
    return updatedUser;
  }
}
