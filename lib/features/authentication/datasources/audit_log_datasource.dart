import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/config/app_config.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/models/audit_log_model.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

abstract class AuditLogDataSource {
  Future<void> logAction({
    required AuditAction action,
    required String performedBy,
    String? performedFor,
    Map<String, dynamic>? metadata,
    String? description,
  });
  Future<List<AuditLogModel>> getAuditLogs({
    String? userId,
    AuditAction? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  });
}

class AuditLogDataSourceImpl implements AuditLogDataSource {
  AuditLogDataSourceImpl({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  @override
  Future<void> logAction({
    required AuditAction action,
    required String performedBy,
    String? performedFor,
    Map<String, dynamic>? metadata,
    String? description,
  }) async {
    try {
      final deviceName = await _getDeviceName();

      final auditLog = AuditLogModel(
        id: _uuid.v4(),
        action: action,
        performedBy: performedBy,
        performedFor: performedFor,
        timestamp: DateTime.now(),
        device: deviceName,
        ipAddress: null,
        environment: AppConfig.instance.environment.value,
        metadata: metadata,
        description: description,
      );

      await _firestore.collection('auditLogs').add(auditLog.toJson());

      AppLogger.info('Audit log created: ${action.name}');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create audit log', e, stackTrace);
    }
  }

  @override
  Future<List<AuditLogModel>> getAuditLogs({
    String? userId,
    AuditAction? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore.collection('auditLogs');

      if (userId != null) {
        query = query.where('performedBy', isEqualTo: userId);
      }

      if (action != null) {
        query = query.where('action', isEqualTo: action.name);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: endDate);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return AuditLogModel.fromJson({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Get audit logs error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get audit logs',
        originalError: e,
      );
    }
  }

  Future<String> _getDeviceName() async {
    try {
      if (kIsWeb) {
        return 'Web Browser';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }
}
