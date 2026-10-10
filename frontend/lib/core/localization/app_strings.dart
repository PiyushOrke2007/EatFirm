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
}
