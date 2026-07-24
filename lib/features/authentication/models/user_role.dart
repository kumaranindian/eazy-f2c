enum UserRole {
  superAdmin,
  admin,
  customer,
  farmer,
  packaging,
  delivery;

  String get displayName {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.customer:
        return 'Customer';
      case UserRole.farmer:
        return 'Farmer';
      case UserRole.packaging:
        return 'Packaging';
      case UserRole.delivery:
        return 'Delivery';
    }
  }

  String get dashboardRoute {
    switch (this) {
      case UserRole.superAdmin:
        return '/admin/dashboard';
      case UserRole.admin:
        return '/admin/dashboard';
      case UserRole.customer:
        return '/customer/dashboard';
      case UserRole.farmer:
        return '/farmer/dashboard';
      case UserRole.packaging:
        return '/packaging/dashboard';
      case UserRole.delivery:
        return '/delivery/dashboard';
    }
  }

  bool get canManageUsers {
    return this == UserRole.superAdmin;
  }

  bool get isAdminLevel {
    return this == UserRole.superAdmin || this == UserRole.admin;
  }

  static UserRole fromString(String value) {
    // Handle both superAdmin and super_admin for backward compatibility
    if (value == 'superAdmin' || value == 'super_admin') {
      return UserRole.superAdmin;
    }
    
    final normalizedValue = value.toLowerCase().replaceAll('_', '');
    
    return UserRole.values.firstWhere(
      (role) => role.name.toLowerCase() == normalizedValue,
      orElse: () => throw ArgumentError('Invalid role: $value'),
    );
  }
}
