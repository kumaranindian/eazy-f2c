import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';

part 'schedule_cart_model.freezed.dart';
part 'schedule_cart_model.g.dart';

/// Represents a cart for a specific schedule with cutoff time tracking
@freezed
class ScheduleCartModel with _$ScheduleCartModel {
  const ScheduleCartModel._();

  const factory ScheduleCartModel({
    required String scheduleId,
    required String scheduleName,
    required DateTime deliveryDate,
    required String deliveryTime,
    required DateTime cutoffDateTime,
    required String hubName,
    required Map<String, CartItemModel> items,
    @Default(false) bool isLocked, // Locked after cutoff time
  }) = _ScheduleCartModel;

  factory ScheduleCartModel.fromJson(Map<String, dynamic> json) =>
      _$ScheduleCartModelFromJson(json);

  /// Calculate total amount for this schedule's cart
  double get totalAmount {
    return items.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Get total item count
  int get itemCount => items.length;

  /// Get total quantity across all items
  double get totalQuantity {
    return items.values.fold(0.0, (sum, item) => sum + item.quantity);
  }

  /// Check if cart is past cutoff time
  bool get isPastCutoff {
    return DateTime.now().isAfter(cutoffDateTime);
  }

  /// Check if cart can be modified
  bool get canModify {
    return !isLocked && !isPastCutoff;
  }

  /// Get time remaining until cutoff
  Duration get timeUntilCutoff {
    final now = DateTime.now();
    if (now.isAfter(cutoffDateTime)) {
      return Duration.zero;
    }
    return cutoffDateTime.difference(now);
  }

  /// Format time remaining as human-readable string
  String get formattedTimeRemaining {
    final duration = timeUntilCutoff;
    if (duration == Duration.zero) {
      return 'Cutoff passed';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 24) {
      final days = hours ~/ 24;
      return '$days day${days > 1 ? 's' : ''} remaining';
    } else if (hours > 0) {
      return '$hours hr${hours > 1 ? 's' : ''} $minutes min remaining';
    } else {
      return '$minutes min remaining';
    }
  }
}
