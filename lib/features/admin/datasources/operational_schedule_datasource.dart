import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';

abstract class OperationalScheduleDataSource {
  Stream<List<OperationalScheduleModel>> watchSchedules();
  Future<List<OperationalScheduleModel>> getSchedules();
  Future<List<OperationalScheduleModel>> getSchedulesByDate(DateTime date);
  Future<OperationalScheduleModel> getScheduleById(String id);
  Future<String> createSchedule(OperationalScheduleModel schedule);
  Future<void> updateSchedule(String id, OperationalScheduleModel schedule);
  Future<void> deleteSchedule(String id);
  Future<void> updateScheduleStatus(String id, String status, String? completedBy);
  Future<Map<String, int>> getScheduleStats();
}

class OperationalScheduleDataSourceImpl implements OperationalScheduleDataSource {
  OperationalScheduleDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _schedulesCollection =>
      _firestore.collection('operational_schedules');

  @override
  Stream<List<OperationalScheduleModel>> watchSchedules() {
    try {
      return _schedulesCollection
          .where('isDeleted', isEqualTo: false)
          .orderBy('scheduledDate', descending: true)
          .limit(100)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => OperationalScheduleModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching schedules', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch schedules',
        originalError: e,
      );
    }
  }

  @override
  Future<List<OperationalScheduleModel>> getSchedules() async {
    try {
      final snapshot = await _schedulesCollection
          .orderBy('scheduledDate', descending: true)
          .orderBy('scheduledTime', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => OperationalScheduleModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting schedules', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get schedules',
        originalError: e,
      );
    }
  }

  @override
  Future<List<OperationalScheduleModel>> getSchedulesByDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snapshot = await _schedulesCollection
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
          .orderBy('scheduledTime')
          .get();

      return snapshot.docs
          .map((doc) => OperationalScheduleModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting schedules by date', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get schedules by date',
        originalError: e,
      );
    }
  }

  @override
  Future<OperationalScheduleModel> getScheduleById(String id) async {
    try {
      final doc = await _schedulesCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Schedule not found',
          resource: 'Schedule',
        );
      }

      return OperationalScheduleModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting schedule by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createSchedule(OperationalScheduleModel schedule) async {
    try {
      final docRef = await _schedulesCollection.add(schedule.toFirestore());
      AppLogger.info('Schedule created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating schedule', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateSchedule(String id, OperationalScheduleModel schedule) async {
    try {
      await _schedulesCollection.doc(id).update(schedule.toFirestore());
      AppLogger.info('Schedule updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating schedule', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteSchedule(String id) async {
    try {
      await _schedulesCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Schedule deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting schedule', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete schedule',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateScheduleStatus(String id, String status, String? completedBy) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'completed' && completedBy != null) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
        updateData['completedBy'] = completedBy;
      }

      await _schedulesCollection.doc(id).update(updateData);
      AppLogger.info('Schedule status updated: $id to $status');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating schedule status', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update schedule status',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getScheduleStats() async {
    try {
      final snapshot = await _schedulesCollection
          .where('isDeleted', isEqualTo: false)
          .get();

      final schedules = snapshot.docs
          .map((doc) => OperationalScheduleModel.fromFirestore(doc))
          .toList();

      // Active schedules: based on isActive field
      final activeSchedules = schedules.where((s) => s.isActive).toList();

      // Inactive schedules: based on isActive field
      final inactiveSchedules = schedules.where((s) => !s.isActive).toList();

      // Get today's schedules based on recurrence logic
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todaySchedules = schedules.where((s) {
        final scheduleDate = DateTime(s.scheduledDate.year, s.scheduledDate.month, s.scheduledDate.day);
        
        // One-time schedules
        if (s.recurrenceType == ScheduleRecurrenceType.oneTime) {
          return scheduleDate.isAtSameMomentAs(startOfDay);
        }
        
        // Daily schedules
        if (s.recurrenceType == ScheduleRecurrenceType.daily) {
          final endDate = s.recurrenceEndDate != null
              ? DateTime(s.recurrenceEndDate!.year, s.recurrenceEndDate!.month, s.recurrenceEndDate!.day)
              : null;
          return !startOfDay.isBefore(scheduleDate) && 
                 (endDate == null || !startOfDay.isAfter(endDate));
        }
        
        // Weekly schedules
        if (s.recurrenceType == ScheduleRecurrenceType.weekly) {
          final endDate = s.recurrenceEndDate != null
              ? DateTime(s.recurrenceEndDate!.year, s.recurrenceEndDate!.month, s.recurrenceEndDate!.day)
              : null;
          return !startOfDay.isBefore(scheduleDate) && 
                 (endDate == null || !startOfDay.isAfter(endDate)) &&
                 s.recurrenceDaysOfWeek.contains(startOfDay.weekday);
        }
        
        // Custom days schedules
        if (s.recurrenceType == ScheduleRecurrenceType.customDays) {
          final endDate = s.recurrenceEndDate != null
              ? DateTime(s.recurrenceEndDate!.year, s.recurrenceEndDate!.month, s.recurrenceEndDate!.day)
              : null;
          return !startOfDay.isBefore(scheduleDate) && 
                 (endDate == null || !startOfDay.isAfter(endDate)) &&
                 s.recurrenceDaysOfWeek.contains(startOfDay.weekday);
        }
        
        return false;
      }).toList();

      // Today's active and inactive counts
      final todayActiveSchedules = todaySchedules.where((s) => s.isActive).toList();
      final todayInactiveSchedules = todaySchedules.where((s) => !s.isActive).toList();

      return {
        'totalSchedules': schedules.length,
        'activeSchedules': activeSchedules.length,
        'inactiveSchedules': inactiveSchedules.length,
        'todaySchedules': todaySchedules.length,
        'todayActiveSchedules': todayActiveSchedules.length,
        'todayInactiveSchedules': todayInactiveSchedules.length,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting schedule stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get schedule stats',
        originalError: e,
      );
    }
  }
}
