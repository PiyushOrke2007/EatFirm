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

  // Module 03: Restaurant Management & Onboarding
  static const String restaurantDashboard = '/restaurant/dashboard';
  static const String restaurantOnboard = '/restaurant/onboard';
  static const String restaurantMenu = '/restaurant/menu';
  static const String restaurantHours = '/restaurant/hours';
  static const String adminApprovals = '/admin/approvals';

  // Module 04: Customer Discovery, Search, Compare & Menu Details
  static const String discovery = '/discovery';
  static const String restaurantDetails = '/restaurant-details';

  // Module 05: Cart, Checkout, Order Placement, History & Cancellation
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String orderDetail = '/orders/:id';
  static const String orderConfirmation = '/orders/confirmation/:id';

  // Module 06: COD Payments, Collection & Tax Invoicing
  static const String orderInvoice = '/orders/:id/invoice';
  static String orderInvoicePath(String orderId) => '/orders/$orderId/invoice';
}
