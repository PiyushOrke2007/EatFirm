/// Centralized localized string dictionary for EatFirm.
/// Adheres to SRS Section 6:
/// "The text shown on the screens shall be kept in separate language files
/// and not written directly in the code, so that Hindi or Marathi can be added
/// later without changing the logic."
class AppStrings {
  AppStrings._();

  // App Metadata
  static const String appName = 'EatFirm';
  static const String appTagline = 'Gourmet at your doorstep';
  static const String version = '1.0.0';

  // Navigation & Shell
  static const String navFoundations = 'Foundations';
  static const String navHome = 'Home';
  static const String navOrders = 'Orders';
  static const String navProfile = 'Profile';

  // Bootstrap & Connectivity
  static const String connectingToServices =
      'Connecting to EatFirm services...';
  static const String connectionNotice = 'Connection Notice';
  static const String retry = 'Retry';
  static const String continueText = 'Continue';
  static const String tryAgain = 'Try Again';

  // Common Actions
  static const String confirm = 'Confirm';
  static const String cancel = 'Cancel';
  static const String dismiss = 'Dismiss';
  static const String submit = 'Submit';
  static const String ok = 'OK';
  static const String validateInputs = 'Validate Inputs';

  // Errors & States
  static const String pageNotFound = 'Page Not Found';
  static const String notFoundDescription =
      'The requested page or resource could not be found.';
  static const String goToHome = 'Go to Home';
  static const String somethingWentWrong = 'Something went wrong';
  static const String networkTimeout = 'Network Timeout';
  static const String serverUnavailable =
      'EatFirm server is currently unreachable.';

  // Form Field Labels & Placeholders
  static const String email = 'Email Address';
  static const String emailPlaceholder = 'name@example.com';
  static const String password = 'Password';
  static const String passwordPlaceholder = 'Enter password';
  static const String fullName = 'Full Name';
  static const String fullNamePlaceholder = 'Enter your full name';
  static const String phone = 'Phone Number';
  static const String phonePlaceholder = '9876543210';
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';

  // Validation Messages
  static const String emailRequired = 'Email address cannot be empty';
  static const String emailInvalid = 'Please enter a valid email address';
  static const String passwordTooShort =
      'Password must be at least 8 characters long';
  static const String nameRequired = 'Name is required';

  // Order & System Badges
  static const String statusDelivered = 'Delivered';
  static const String statusPreparing = 'Preparing';
  static const String statusCancelled = 'Cancelled';
  static const String statusOutForDelivery = 'Out for Delivery';
  static const String statusDraft = 'Draft';

  // Currency
  static const String currencySymbol = '₹';

  // Module 02: Authentication & RBAC
  static const String login = 'Sign In';
  static const String loginTitle = 'Welcome Back';
  static const String loginSubtitle = 'Sign in to continue to EatFirm';
  static const String loginButton = 'Sign In';
  static const String register = 'Create Account';
  static const String registerTitle = 'Join EatFirm';
  static const String registerSubtitle =
      'Select your role and start your gourmet journey';
  static const String registerButton = 'Create Account';
  static const String logout = 'Log Out';
  static const String logoutConfirmTitle = 'Confirm Logout';
  static const String logoutConfirmMessage =
      'Are you sure you want to end your current session?';
  static const String forgotPassword = 'Forgot Password?';
  static const String forgotPasswordTitle = 'Reset Password';
  static const String forgotPasswordSubtitle =
      'Enter your registered email or phone to receive a 6-digit code';
  static const String sendResetCode = 'Send Reset Code';
  static const String resetPassword = 'Set New Password';
  static const String resetPasswordSubtitle =
      'Enter the code and choose a secure new password';
  static const String verifyOtp = 'Verify Code';
  static const String verifyOtpSubtitle =
      'Enter the 6-digit verification code sent to:';
  static const String resendOtp = 'Resend Code';
  static const String otpCode = 'Verification Code';
  static const String newPassword = 'New Password';
  static const String acceptTerms =
      'I agree to the Terms of Service and Privacy Policy';
  static const String roleCustomer = 'Customer';
  static const String roleRestaurant = 'Restaurant Partner';
  static const String roleDelivery = 'Delivery Partner';
  static const String roleAdmin = 'System Admin';
  static const String roleSelectorLabel = 'I want to register as a:';
  static const String selectRole = 'Select Role';
  static const String alreadyHaveAccount = 'Already have an account? Sign In';
  static const String dontHaveAccount = "Don't have an account? Register";
  static const String profileTitle = 'My Profile';
  static const String accessDenied = 'Access Denied';
  static const String accessDeniedSubtitle =
      'You do not have permission to access this resource or page.';
  static const String editProfile = 'Edit Profile';
  static const String updateProfile = 'Update Profile';
  static const String verified = 'Verified';
  static const String unverified = 'Unverified (OTP Pending)';
  static const String identifier = 'Email or Phone Number';
  static const String identifierPlaceholder = 'user@example.com or 9876543210';
  static const String passwordHint = 'Min 8 chars, uppercase, number & symbol';
  static const String invalidCredentials = 'Invalid email/phone or password';
  static const String termsRequired =
      'You must accept the Terms of Service to continue';
  static const String codeRequired =
      'Please enter the 6-digit verification code';
  static const String sessionExpired =
      'Your session has expired. Please log in again.';
}
