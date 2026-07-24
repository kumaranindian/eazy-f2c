import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

part 'operational_schedule_model.freezed.dart';
part 'operational_schedule_model.g.dart';

enum ScheduleVisibilityScope {
  entireHub,
  selectedApartments,
}

enum ScheduleStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

enum ScheduleRecurrenceType {
  oneTime,
  daily,
  weekly,
  customDays,
}

@freezed
class ScheduleProductItem with _$ScheduleProductItem {
  const factory ScheduleProductItem({
    required String productId,
    required String productName,
    required String productCategory,
    required int quantity,
    @Default(0.0) double price,
    @Default(0.0) double profitMargin,
    String? farmerId,
    String? farmerName,
  }) = _ScheduleProductItem;

  factory ScheduleProductItem.fromJson(Map<String, dynamic> json) =>
      _$ScheduleProductItemFromJson(json);
}

@freezed
class OperationalScheduleModel with _$OperationalScheduleModel {
  const OperationalScheduleModel._();

  const factory OperationalScheduleModel({
    required String id,
    required String scheduleName,
    required DateTime scheduledDate,
    required String startTime,
    required String endTime,
    required String branchId,
    required String branchName,
    required String hubId,
    required String hubName,
    @Default(ScheduleVisibilityScope.entireHub) ScheduleVisibilityScope visibilityScope,
    @Default([]) List<String> selectedApartmentIds,
    @Default([]) List<String> selectedApartmentNames,
    @Default([]) List<ScheduleProductItem> products,
    @Default(ScheduleStatus.pending) ScheduleStatus status,
    required bool isActive,
    required bool isDeleted,
    required DateTime createdAt,
    required String createdBy,
    DateTime? updatedAt,
    String? updatedBy,
    String? notes,
    DateTime? completedAt,
    String? completedBy,
    // Recurrence fields (for product visibility)
    @Default(ScheduleRecurrenceType.oneTime) ScheduleRecurrenceType recurrenceType,
    DateTime? recurrenceEndDate,
    @Default([]) List<int> recurrenceDaysOfWeek, // 1=Monday, 2=Tuesday, etc.
    String? parentScheduleId, // For instances of recurring schedules
    // Delivery slot fields
    @Default(ScheduleRecurrenceType.oneTime) ScheduleRecurrenceType deliverySlotType,
    DateTime? deliveryDate, // For one-time delivery
    String? deliveryStartTime, // For daily/weekly delivery
    String? deliveryEndTime, // For daily/weekly delivery
    @Default([]) List<int> deliveryDaysOfWeek, // For weekly delivery: 1=Monday, 2=Tuesday, etc.
  }) = _OperationalScheduleModel;

  factory OperationalScheduleModel.fromJson(Map<String, dynamic> json) =>
      _$OperationalScheduleModelFromJson(json);

  factory OperationalScheduleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Convert products list to ScheduleProductItem objects
    final productsList = (data['products'] as List<dynamic>?)
            ?.map((p) {
              if (p is ScheduleProductItem) {
                return p;
              } else if (p is Map<String, dynamic>) {
                return ScheduleProductItem.fromJson(p);
              }
              return null;
            })
            .whereType<ScheduleProductItem>()
            .toList() ??
        [];

    return OperationalScheduleModel(
      id: doc.id,
      scheduleName: data['scheduleName'] as String? ?? 'Schedule ${DateFormat('dd/MM/yyyy').format(data['scheduledDate'] is Timestamp ? (data['scheduledDate'] as Timestamp).toDate() : DateTime.parse(data['scheduledDate'] as String))}',
      scheduledDate: data['scheduledDate'] is Timestamp 
          ? (data['scheduledDate'] as Timestamp).toDate()
          : DateTime.parse(data['scheduledDate'] as String),
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      branchId: data['branchId'] as String,
      branchName: data['branchName'] as String,
      hubId: data['hubId'] as String,
      hubName: data['hubName'] as String,
      visibilityScope: data['visibilityScope'] == 'selectedApartments' 
          ? ScheduleVisibilityScope.selectedApartments 
          : ScheduleVisibilityScope.entireHub,
      selectedApartmentIds: (data['selectedApartmentIds'] as List<dynamic>?)?.cast<String>() ?? [],
      selectedApartmentNames: (data['selectedApartmentNames'] as List<dynamic>?)?.cast<String>() ?? [],
      products: productsList,
      status: data['status'] == 'inProgress' 
          ? ScheduleStatus.inProgress 
          : data['status'] == 'completed' 
              ? ScheduleStatus.completed 
              : data['status'] == 'cancelled' 
                  ? ScheduleStatus.cancelled 
                  : ScheduleStatus.pending,
      isActive: data['isActive'] as bool? ?? true,
      isDeleted: data['isDeleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] as String,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'] as String?,
      notes: data['notes'] as String?,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      completedBy: data['completedBy'] as String?,
      // Recurrence fields
      recurrenceType: data['recurrenceType'] == 'daily'
          ? ScheduleRecurrenceType.daily
          : data['recurrenceType'] == 'weekly'
              ? ScheduleRecurrenceType.weekly
              : data['recurrenceType'] == 'customDays'
                  ? ScheduleRecurrenceType.customDays
                  : ScheduleRecurrenceType.oneTime,
      recurrenceEndDate: data['recurrenceEndDate'] is Timestamp
          ? (data['recurrenceEndDate'] as Timestamp).toDate()
          : data['recurrenceEndDate'] != null
              ? DateTime.parse(data['recurrenceEndDate'] as String)
              : null,
      recurrenceDaysOfWeek: (data['recurrenceDaysOfWeek'] as List<dynamic>?)?.cast<int>() ?? [],
      parentScheduleId: data['parentScheduleId'] as String?,
      // Delivery slot fields
      deliverySlotType: data['deliverySlotType'] == 'daily'
          ? ScheduleRecurrenceType.daily
          : data['deliverySlotType'] == 'weekly'
              ? ScheduleRecurrenceType.weekly
              : ScheduleRecurrenceType.oneTime,
      deliveryDate: data['deliveryDate'] is Timestamp
          ? (data['deliveryDate'] as Timestamp).toDate()
          : data['deliveryDate'] != null
              ? DateTime.parse(data['deliveryDate'] as String)
              : null,
      deliveryStartTime: data['deliveryStartTime'] as String?,
      deliveryEndTime: data['deliveryEndTime'] as String?,
      deliveryDaysOfWeek: (data['deliveryDaysOfWeek'] as List<dynamic>?)?.cast<int>() ?? [],
    );
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    json['createdAt'] = Timestamp.fromDate(createdAt);
    if (updatedAt != null) {
      json['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }
    if (completedAt != null) {
      json['completedAt'] = Timestamp.fromDate(completedAt!);
    }
    if (recurrenceEndDate != null) {
      json['recurrenceEndDate'] = Timestamp.fromDate(recurrenceEndDate!);
    }
    if (deliveryDate != null) {
      json['deliveryDate'] = Timestamp.fromDate(deliveryDate!);
    }
    // Convert products list to JSON
    if (json['products'] != null) {
      json['products'] = (json['products'] as List)
          .map((p) => p is ScheduleProductItem ? p.toJson() : p)
          .toList();
    }
    // Convert recurrenceType enum to string
    json['recurrenceType'] = recurrenceType.name;
    json['deliverySlotType'] = deliverySlotType.name;
    return json;
  }

  String get statusDisplay {
    switch (status) {
      case ScheduleStatus.pending:
        return 'Pending';
      case ScheduleStatus.inProgress:
        return 'In Progress';
      case ScheduleStatus.completed:
        return 'Completed';
      case ScheduleStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  String get statusCategoryDisplay {
    // Returns Active/Inactive category based on isActive field
    return isActive ? 'Active' : 'Inactive';
  }

  String get visibilityScopeDisplay {
    switch (visibilityScope) {
      case ScheduleVisibilityScope.entireHub:
        return 'Entire Hub';
      case ScheduleVisibilityScope.selectedApartments:
        return 'Selected Apartments';
    }
  }

  int get totalProducts => products.length;
  int get totalQuantity => products.fold(0, (sum, p) => sum + p.quantity);
}
