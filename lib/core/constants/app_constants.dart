class AppConstants {
  AppConstants._();

  static const String appName = 'F2C';
  static const String appFullName = 'Farm2Community';
  static const String appVersion = '1.0.0';
  static const String buildNumber = '1';

  static const int sessionTimeoutMinutes = 30;
  static const int tokenRefreshMinutes = 25;

  static const int usernameMinLength = 5;
  static const int usernameMaxLength = 30;
  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 50;

  static const int nameMinLength = 2;
  static const int nameMaxLength = 100;

  static const String defaultProfileImage =
      'https://ui-avatars.com/api/?name=User&background=random';
}

class FirestoreCollections {
  FirestoreCollections._();

  static const String users = 'users';
  static const String auditLogs = 'auditLogs';
  static const String system = 'system';
  static const String branches = 'branches';
  static const String hubs = 'hubs';
  static const String apartments = 'apartments';
  static const String customers = 'customers';
  static const String farmers = 'farmers';
  static const String products = 'products';
  static const String orders = 'orders';
  static const String deliveries = 'deliveries';
}

class StorageKeys {
  StorageKeys._();

  static const String isLoggedIn = 'is_logged_in';
  static const String userId = 'user_id';
  static const String username = 'username';
  static const String userRole = 'user_role';
  static const String branchId = 'branch_id';
  static const String hubId = 'hub_id';
  static const String loginTime = 'login_time';
  static const String authToken = 'auth_token';
  static const String rememberMe = 'remember_me';
  static const String lastUsername = 'last_username';
}

class RouteNames {
  RouteNames._();

  static const String splash = '/';
  static const String firstUserSetup = '/first-user-setup';
  static const String login = '/login';
  static const String changePassword = '/change-password';
  
  static const String adminDashboard = '/admin/dashboard';
  static const String adminUsers = '/admin/users';
  static const String adminUserCreate = '/admin/users/create';
  static const String adminUserEdit = '/admin/users/edit';
  static const String adminBranches = '/admin/branches';
  static const String adminHubs = '/admin/hubs';
  static const String adminApartments = '/admin/apartments';
  static const String adminCustomers = '/admin/customers';
  static const String adminFarmers = '/admin/farmers';
  static const String adminProducts = '/admin/products';
  static const String adminOrders = '/admin/orders';
  static const String adminReports = '/admin/reports';
  static const String adminSettings = '/admin/settings';
  
  static const String customerDashboard = '/customer/dashboard';
  static const String customerOrders = '/customer/orders';
  static const String customerProfile = '/customer/profile';
  
  static const String packagingDashboard = '/packaging/dashboard';
  static const String packagingOrders = '/packaging/orders';
  
  static const String deliveryDashboard = '/delivery/dashboard';
  static const String deliveryOrders = '/delivery/orders';
}

class ValidationMessages {
  ValidationMessages._();

  static const String usernameRequired = 'Username is required';
  static const String usernameInvalid = 'Username must be 5-30 characters, no spaces';
  static const String passwordRequired = 'Password is required';
  static const String passwordWeak = 'Password must contain 8+ chars, uppercase, lowercase, number, special char';
  static const String emailRequired = 'Email is required';
  static const String emailInvalid = 'Invalid email address';
  static const String nameRequired = 'Name is required';
  static const String mobileRequired = 'Mobile number is required';
  static const String mobileInvalid = 'Invalid mobile number';
  static const String roleRequired = 'Role is required';
  static const String passwordMismatch = 'Passwords do not match';
}

class ErrorMessages {
  ErrorMessages._();

  static const String networkError = 'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'An unknown error occurred.';
  static const String invalidCredentials = 'Invalid username or password';
  static const String userNotFound = 'User not found';
  static const String userInactive = 'Your account is inactive. Contact administrator.';
  static const String userDeleted = 'Your account has been deleted.';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String unauthorized = 'Unauthorized access';
  static const String permissionDenied = 'Permission denied';
}
