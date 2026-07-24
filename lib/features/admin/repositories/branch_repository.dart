import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/branch_datasource.dart';
import 'package:f2c/features/admin/models/branch_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class BranchRepository {
  Stream<List<BranchModel>> watchBranches();
  Future<List<BranchModel>> getBranches();
  Future<BranchModel> getBranchById(String id);
  Future<String> createBranch(BranchModel branch, String userId, UserRole userRole);
  Future<void> updateBranch(String id, BranchModel branch, String userId, UserRole userRole);
  Future<void> deleteBranch(String id, String userId, UserRole userRole);
  Future<void> restoreBranch(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getBranchStats();
}

class BranchRepositoryImpl implements BranchRepository {
  BranchRepositoryImpl({required BranchDataSource dataSource})
      : _dataSource = dataSource;

  final BranchDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage branches',
      );
    }
  }

  @override
  Stream<List<BranchModel>> watchBranches() {
    return _dataSource.watchBranches();
  }

  @override
  Future<List<BranchModel>> getBranches() async {
    return await _dataSource.getBranches();
  }

  @override
  Future<BranchModel> getBranchById(String id) async {
    return await _dataSource.getBranchById(id);
  }

  @override
  Future<String> createBranch(
    BranchModel branch,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final newBranch = branch.copyWith(
        createdBy: userId,
        createdAt: DateTime.now(),
        isDeleted: false,
      );

      final branchId = await _dataSource.createBranch(newBranch);
      AppLogger.info('Branch created successfully: $branchId');
      return branchId;
    } catch (e, stackTrace) {
      AppLogger.error('Create branch error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create branch',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateBranch(
    String id,
    BranchModel branch,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final updatedBranch = branch.copyWith(
        updatedBy: userId,
        updatedAt: DateTime.now(),
      );

      await _dataSource.updateBranch(id, updatedBranch);
      AppLogger.info('Branch updated successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Update branch error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update branch',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteBranch(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteBranch(id);
      AppLogger.info('Branch deleted successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Delete branch error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete branch',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreBranch(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      // Get the branch and restore it
      final branch = await _dataSource.getBranchById(id);
      final restoredBranch = branch.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateBranch(id, restoredBranch);
      AppLogger.info('Branch restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore branch error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore branch',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getBranchStats() async {
    return await _dataSource.getBranchStats();
  }
}
