import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/customer_datasource.dart';
import 'package:f2c/features/admin/models/customer_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/repositories/user_repository.dart';

abstract class CustomerRepository {
  Stream<List<CustomerModel>> watchCustomers();
  Future<List<CustomerModel>> getCustomers();
  Future<CustomerModel> getCustomerById(String id);
  Future<String> createCustomer(CustomerModel customer, String userId, UserRole userRole);
  Future<String> createCustomerWithUser(
    CustomerModel customer,
    String username,
    String password,
    String userId,
    UserRole userRole,
  );
  Future<void> updateCustomer(String id, CustomerModel customer, String userId, UserRole userRole);
  Future<void> deleteCustomer(String id, String userId, UserRole userRole);
  Future<void> restoreCustomer(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getCustomerStats();
}

class CustomerRepositoryImpl implements CustomerRepository {
  CustomerRepositoryImpl({
    required CustomerDataSource dataSource,
    required UserRepository userRepository,
  })  : _dataSource = dataSource,
        _userRepository = userRepository;

  final CustomerDataSource _dataSource;
  final UserRepository _userRepository;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage customers',
      );
    }
  }

  @override
  Stream<List<CustomerModel>> watchCustomers() {
    return _dataSource.watchCustomers();
  }

  @override
  Future<List<CustomerModel>> getCustomers() async {
    return await _dataSource.getCustomers();
  }

  @override
  Future<CustomerModel> getCustomerById(String id) async {
    return await _dataSource.getCustomerById(id);
  }

  @override
  Future<String> createCustomer(
    CustomerModel customer,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final customerId = await _dataSource.createCustomer(customer);
      AppLogger.info('Customer created successfully: $customerId by user: $userId');
      return customerId;
    } catch (e, stackTrace) {
      AppLogger.error('Create customer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create customer',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createCustomerWithUser(
    CustomerModel customer,
    String username,
    String password,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      // First create the user record for login
      final user = UserModel(
        id: '',
        name: customer.name,
        username: username,
        email: customer.email,
        mobile: customer.phone,
        role: UserRole.customer,
        branchId: customer.branchId,
        hubId: customer.hubId,
        isActive: customer.isActive,
        isDeleted: false,
        passwordChanged: false,
        lastLogin: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final createdUser = await _userRepository.createUser(user, password, userId);

      // Then create the customer record with the user ID
      final customerWithUserId = customer.copyWith(
        id: createdUser.id, // Use the user ID as customer ID
      );

      final customerId = await _dataSource.createCustomer(customerWithUserId);
      
      AppLogger.info('Customer and user created successfully: $customerId by user: $userId');
      return customerId;
    } catch (e, stackTrace) {
      AppLogger.error('Create customer with user error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create customer with user',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateCustomer(
    String id,
    CustomerModel customer,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateCustomer(id, customer);
      AppLogger.info('Customer updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update customer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update customer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteCustomer(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteCustomer(id);
      AppLogger.info('Customer deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete customer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete customer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreCustomer(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final customer = await _dataSource.getCustomerById(id);
      final restoredCustomer = customer.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateCustomer(id, restoredCustomer);
      AppLogger.info('Customer restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore customer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore customer',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getCustomerStats() async {
    return await _dataSource.getCustomerStats();
  }
}
