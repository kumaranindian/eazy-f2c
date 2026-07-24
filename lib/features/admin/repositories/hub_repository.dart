import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/hub_datasource.dart';
import 'package:f2c/features/admin/models/hub_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class HubRepository {
  Stream<List<HubModel>> watchHubs();
  Future<List<HubModel>> getHubs();
  Future<HubModel> getHubById(String id);
  Future<String> createHub(HubModel hub, String userId, UserRole userRole);
  Future<void> updateHub(String id, HubModel hub, String userId, UserRole userRole);
  Future<void> deleteHub(String id, String userId, UserRole userRole);
  Future<void> restoreHub(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getHubStats();
}

class HubRepositoryImpl implements HubRepository {
  HubRepositoryImpl({required HubDataSource dataSource})
      : _dataSource = dataSource;

  final HubDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage hubs',
      );
    }
  }

  @override
  Stream<List<HubModel>> watchHubs() {
    return _dataSource.watchHubs();
  }

  @override
  Future<List<HubModel>> getHubs() async {
    return await _dataSource.getHubs();
  }

  @override
  Future<HubModel> getHubById(String id) async {
    return await _dataSource.getHubById(id);
  }

  @override
  Future<String> createHub(
    HubModel hub,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final hubId = await _dataSource.createHub(hub);
      AppLogger.info('Hub created successfully: $hubId by user: $userId');
      return hubId;
    } catch (e, stackTrace) {
      AppLogger.error('Create hub error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create hub',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateHub(
    String id,
    HubModel hub,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateHub(id, hub);
      AppLogger.info('Hub updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update hub error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update hub',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteHub(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteHub(id);
      AppLogger.info('Hub deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete hub error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete hub',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreHub(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final hub = await _dataSource.getHubById(id);
      final restoredHub = hub.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateHub(id, restoredHub);
      AppLogger.info('Hub restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore hub error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore hub',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getHubStats() async {
    return await _dataSource.getHubStats();
  }
}
