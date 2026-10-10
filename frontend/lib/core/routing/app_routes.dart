/// Named routes and URL paths for EatFirm.
class AppRoutes {
  AppRoutes._();

  static const String bootstrap = '/';
  static const String showcase = '/showcase';
  static const String notFound = '/404';

  // Module 02: Authentication
  static const String login = '/login';
  static const String register = '/register';
  static const String verifyOtp = '/verify-otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String profile = '/profile';
  static const String accessDenied = '/access-denied';
}
