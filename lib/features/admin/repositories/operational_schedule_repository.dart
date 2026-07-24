import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/operational_schedule_datasource.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class OperationalScheduleRepository {
  Stream<List<OperationalScheduleModel>> watchSchedules();
  Future<List<OperationalScheduleModel>> getSchedules();
  Future<List<OperationalScheduleModel>> getSchedulesByDate(DateTime date);
  Future<OperationalScheduleModel> getScheduleById(String id);
  Future<String> createSchedule(OperationalScheduleModel schedule, String userId, UserRole userRole);
  Future<void> updateSchedule(String id, OperationalScheduleModel schedule, String userId, UserRole userRole);
  Future<void> deleteSchedule(String id, String userId, UserRole userRole);
  Future<void> updateScheduleStatus(String id, String status, String userId, UserRole userRole);
  Future<Map<String, int>> getScheduleStats();
}

class OperationalScheduleRepositoryImpl implements OperationalScheduleRepository {
  OperationalScheduleRepositoryImpl({
    required OperationalScheduleDataSource dataSource,
  }) : _dataSource = dataSource;

  final OperationalScheduleDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage schedules',
      );
    }
  }

  @override
  Stream<List<OperationalScheduleModel>> watchSchedules() {
    return _dataSource.watchSchedules();
  }

  @override
  Future<List<OperationalScheduleModel>> getSchedules() async {
    return await _dataSource.getSchedules();
  }

  @override
  Future<List<OperationalScheduleModel>> getSchedulesByDate(DateTime date) async {
    return await _dataSource.getSchedulesByDate(date);
  }

  @override
  Future<OperationalScheduleModel> getScheduleById(String id) async {
    return await _dataSource.getScheduleById(id);
  }

  @override
  Future<String> createSchedule(
    OperationalScheduleModel schedule,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      // Validate recurrence settings
      if (schedule.recurrenceType != ScheduleRecurrenceType.oneTime) {
        if (schedule.recurrenceEndDate == null) {
          throw const AppException.validation(
            message: 'End date is required for recurring schedules',
          );
        }
        
        if (schedule.recurrenceEndDate!.isBefore(schedule.scheduledDate)) {
          throw const AppException.validation(
            message: 'End date must be after start date',
          );
        }

        if (schedule.recurrenceType == ScheduleRecurrenceType.weekly || 
            schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
          if (schedule.recurrenceDaysOfWeek.isEmpty) {
            throw const AppException.validation(
              message: 'Please select at least one day of the week',
            );
          }
        }
      }

      // Create single schedule document (no parent-child pattern)
      final scheduleId = await _dataSource.createSchedule(schedule.copyWith(parentScheduleId: null));
      
      if (schedule.recurrenceType == ScheduleRecurrenceType.oneTime) {
        AppLogger.info('One-time schedule created successfully: $scheduleId by user: $userId');
      } else if (schedule.recurrenceType == ScheduleRecurrenceType.daily) {
        AppLogger.info('Daily recurring schedule created: $scheduleId (${schedule.scheduledDate} to ${schedule.recurrenceEndDate}) by user: $userId');
      } else if (schedule.recurrenceType == ScheduleRecurrenceType.weekly) {
        AppLogger.info('Weekly recurring schedule created: $scheduleId (days: ${schedule.recurrenceDaysOfWeek}) by user: $userId');
      } else if (schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
        AppLogger.info('Custom days recurring schedule created: $scheduleId (days: ${schedule.recurrenceDaysOfWeek}) by user: $userId');
      }
      
      return scheduleId;
    } catch (e, stackTrace) {
      AppLogger.error('Create schedule error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateSchedule(
    String id,
    OperationalScheduleModel schedule,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateSchedule(id, schedule);
      AppLogger.info('Schedule updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update schedule error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteSchedule(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteSchedule(id);
      AppLogger.info('Schedule deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete schedule error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateScheduleStatus(
    String id,
    String status,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateScheduleStatus(id, status, userId);
      AppLogger.info('Schedule status updated successfully: $id to $status by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update schedule status error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update schedule status',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getScheduleStats() async {
    return await _dataSource.getScheduleStats();
  }
}
