import 'package:flutter_test/flutter_test.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

void main() {
  group('UserModel', () {
    test('should create a valid user model', () {
      final user = UserModel(
        id: 'test-id',
        name: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        mobile: '1234567890',
        role: UserRole.admin,
        isActive: true,
        isDeleted: false,
        passwordChanged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );

      expect(user.id, 'test-id');
      expect(user.name, 'Test User');
      expect(user.username, 'testuser');
      expect(user.role, UserRole.admin);
    });

    test('canLogin should return true for active, non-deleted user', () {
      final user = UserModel(
        id: 'test-id',
        name: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        mobile: '1234567890',
        role: UserRole.admin,
        isActive: true,
        isDeleted: false,
        passwordChanged: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );

      expect(user.canLogin, true);
    });

    test('canLogin should return false for inactive user', () {
      final user = UserModel(
        id: 'test-id',
        name: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        mobile: '1234567890',
        role: UserRole.admin,
        isActive: false,
        isDeleted: false,
        passwordChanged: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );

      expect(user.canLogin, false);
    });

    test('requiresPasswordChange should return true when password not changed', () {
      final user = UserModel(
        id: 'test-id',
        name: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        mobile: '1234567890',
        role: UserRole.admin,
        isActive: true,
        isDeleted: false,
        passwordChanged: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );

      expect(user.requiresPasswordChange, true);
    });

    test('should serialize to JSON correctly', () {
      final user = UserModel(
        id: 'test-id',
        name: 'Test User',
        username: 'testuser',
        email: 'test@example.com',
        mobile: '1234567890',
        role: UserRole.admin,
        isActive: true,
        isDeleted: false,
        passwordChanged: false,
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 1),
        createdBy: 'system',
        updatedBy: 'system',
      );

      final json = user.toJson();

      expect(json['id'], 'test-id');
      expect(json['name'], 'Test User');
      expect(json['username'], 'testuser');
      expect(json['role'], 'admin');
    });
  });

  group('UserRole', () {
    test('should have correct display names', () {
      expect(UserRole.admin.displayName, 'Admin');
      expect(UserRole.customer.displayName, 'Customer');
      expect(UserRole.packaging.displayName, 'Packaging');
      expect(UserRole.delivery.displayName, 'Delivery');
    });

    test('should have correct dashboard routes', () {
      expect(UserRole.admin.dashboardRoute, '/admin/dashboard');
      expect(UserRole.customer.dashboardRoute, '/customer/dashboard');
      expect(UserRole.packaging.dashboardRoute, '/packaging/dashboard');
      expect(UserRole.delivery.dashboardRoute, '/delivery/dashboard');
    });

    test('should parse from string correctly', () {
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('customer'), UserRole.customer);
      expect(UserRole.fromString('packaging'), UserRole.packaging);
      expect(UserRole.fromString('delivery'), UserRole.delivery);
    });
  });
}
