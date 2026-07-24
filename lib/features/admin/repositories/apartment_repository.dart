import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/apartment_datasource.dart';
import 'package:f2c/features/admin/models/apartment_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class ApartmentRepository {
  Stream<List<ApartmentModel>> watchApartments();
  Future<List<ApartmentModel>> getApartments();
  Future<ApartmentModel> getApartmentById(String id);
  Future<String> createApartment(ApartmentModel apartment, String userId, UserRole userRole);
  Future<void> updateApartment(String id, ApartmentModel apartment, String userId, UserRole userRole);
  Future<void> deleteApartment(String id, String userId, UserRole userRole);
  Future<void> restoreApartment(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getApartmentStats();
}

class ApartmentRepositoryImpl implements ApartmentRepository {
  ApartmentRepositoryImpl({required ApartmentDataSource dataSource})
      : _dataSource = dataSource;

  final ApartmentDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage apartments',
      );
    }
  }

  @override
  Stream<List<ApartmentModel>> watchApartments() {
    return _dataSource.watchApartments();
  }

  @override
  Future<List<ApartmentModel>> getApartments() async {
    return await _dataSource.getApartments();
  }

  @override
  Future<ApartmentModel> getApartmentById(String id) async {
    return await _dataSource.getApartmentById(id);
  }

  @override
  Future<String> createApartment(
    ApartmentModel apartment,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final apartmentId = await _dataSource.createApartment(apartment);
      AppLogger.info('Apartment created successfully: $apartmentId by user: $userId');
      return apartmentId;
    } catch (e, stackTrace) {
      AppLogger.error('Create apartment error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateApartment(
    String id,
    ApartmentModel apartment,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateApartment(id, apartment);
      AppLogger.info('Apartment updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update apartment error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteApartment(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteApartment(id);
      AppLogger.info('Apartment deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete apartment error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreApartment(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final apartment = await _dataSource.getApartmentById(id);
      final restoredApartment = apartment.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateApartment(id, restoredApartment);
      AppLogger.info('Apartment restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore apartment error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getApartmentStats() async {
    return await _dataSource.getApartmentStats();
  }
}
