import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/farmer_datasource.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/repositories/user_repository.dart';

abstract class FarmerRepository {
  Stream<List<FarmerModel>> watchFarmers();
  Future<List<FarmerModel>> getFarmers();
  Future<FarmerModel> getFarmerById(String id);
  Future<String> createFarmer(FarmerModel farmer, String userId, UserRole userRole);
  Future<String> createFarmerWithUser(
    FarmerModel farmer,
    String username,
    String password,
    String userId,
    UserRole userRole,
  );
  Future<void> updateFarmer(String id, FarmerModel farmer, String userId, UserRole userRole);
  Future<void> deleteFarmer(String id, String userId, UserRole userRole);
  Future<void> restoreFarmer(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getFarmerStats();
}

class FarmerRepositoryImpl implements FarmerRepository {
  FarmerRepositoryImpl({
    required FarmerDataSource dataSource,
    required UserRepository userRepository,
  })  : _dataSource = dataSource,
        _userRepository = userRepository;

  final FarmerDataSource _dataSource;
  final UserRepository _userRepository;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage farmers',
      );
    }
  }

  @override
  Stream<List<FarmerModel>> watchFarmers() {
    return _dataSource.watchFarmers();
  }

  @override
  Future<List<FarmerModel>> getFarmers() async {
    return await _dataSource.getFarmers();
  }

  @override
  Future<FarmerModel> getFarmerById(String id) async {
    return await _dataSource.getFarmerById(id);
  }

  @override
  Future<String> createFarmer(
    FarmerModel farmer,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final farmerId = await _dataSource.createFarmer(farmer);
      AppLogger.info('Farmer created successfully: $farmerId by user: $userId');
      return farmerId;
    } catch (e, stackTrace) {
      AppLogger.error('Create farmer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createFarmerWithUser(
    FarmerModel farmer,
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
        name: farmer.name,
        username: username,
        email: farmer.email,
        mobile: farmer.phone,
        role: UserRole.farmer,
        isActive: farmer.isActive,
        isDeleted: false,
        passwordChanged: false,
        lastLogin: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        updatedBy: userId,
      );

      final createdUser = await _userRepository.createUser(user, password, userId);

      // Then create the farmer record with the user ID
      final farmerWithUserId = farmer.copyWith(
        id: createdUser.id, // Use the user ID as farmer ID
      );

      final farmerId = await _dataSource.createFarmer(farmerWithUserId);
      
      AppLogger.info('Farmer and user created successfully: $farmerId by user: $userId');
      return farmerId;
    } catch (e, stackTrace) {
      AppLogger.error('Create farmer with user error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create farmer with user',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateFarmer(
    String id,
    FarmerModel farmer,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateFarmer(id, farmer);
      AppLogger.info('Farmer updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update farmer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteFarmer(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteFarmer(id);
      AppLogger.info('Farmer deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete farmer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreFarmer(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final farmer = await _dataSource.getFarmerById(id);
      final restoredFarmer = farmer.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateFarmer(id, restoredFarmer);
      AppLogger.info('Farmer restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore farmer error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getFarmerStats() async {
    return await _dataSource.getFarmerStats();
  }
}
