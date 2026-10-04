import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/customer/models/schedule_cart_model.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';

/// Provider for managing multiple schedule-based carts
final scheduleCartsProvider = StateNotifierProvider<ScheduleCartsNotifier,
    Map<String, ScheduleCartModel>>((ref) {
  return ScheduleCartsNotifier();
});

class ScheduleCartsNotifier
    extends StateNotifier<Map<String, ScheduleCartModel>> {
  ScheduleCartsNotifier() : super({});

  /// Initialize or get cart for a specific schedule
  ScheduleCartModel _getOrCreateCart(OperationalScheduleModel schedule) {
    if (state.containsKey(schedule.id)) {
      return state[schedule.id]!;
    }

    // Calculate cutoff date time
    final cutoffDateTime = _calculateCutoffDateTime(schedule);

    // Delivery time slot: prefer the schedule's dedicated delivery
    // window; fall back to the ordering window when not set.
    final deliveryTime =
        (schedule.deliveryStartTime != null && schedule.deliveryEndTime != null)
            ? '${schedule.deliveryStartTime} - ${schedule.deliveryEndTime}'
            : '${schedule.startTime} - ${schedule.endTime}';

    // Create new cart for this schedule
    final newCart = ScheduleCartModel(
      scheduleId: schedule.id,
      scheduleName: schedule.scheduleName,
      deliveryDate: _calculateDeliveryDate(schedule),
      deliveryTime: deliveryTime,
      cutoffDateTime: cutoffDateTime,
      hubName: schedule.hubName,
      items: {},
    );

    state = {
      ...state,
      schedule.id: newCart,
    };

    return newCart;
  }

  /// Calculate cutoff date time based on schedule's recurrence days
  DateTime _calculateCutoffDateTime(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (schedule.recurrenceDaysOfWeek.isEmpty) {
      // If no recurrence days, use today with end time
      return _parseDateTime(today, schedule.endTime);
    }

    // The last ordering day is the FURTHEST upcoming occurrence of any
    // recurrence day — not the numerically largest day number. Using max()
    // breaks windows that cross the week boundary (e.g. [7,1] = Sun+Mon,
    // where Monday comes after Sunday but 1 < 7).
    // Dart weekday: 1=Monday ... 7=Sunday. Dart's % is always non-negative,
    // so (1 - 7) % 7 = 1 correctly wraps Monday to the next day.
    DateTime cutoffDate = today;
    for (final day in schedule.recurrenceDaysOfWeek) {
      final daysAhead = (day - today.weekday) % 7;
      final occurrence = today.add(Duration(days: daysAhead));
      if (occurrence.isAfter(cutoffDate)) {
        cutoffDate = occurrence;
      }
    }

    // Combine with end time
    return _parseDateTime(cutoffDate, schedule.endTime);
  }

  /// Calculate delivery date based on schedule's delivery slot config
  DateTime _calculateDeliveryDate(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // One-time delivery: use the explicit delivery date
    if (schedule.deliverySlotType == ScheduleRecurrenceType.oneTime) {
      return schedule.deliveryDate ?? schedule.scheduledDate;
    }

    // Weekly/custom delivery days: deliveryDaysOfWeek uses the same
    // 1=Monday ... 7=Sunday convention as DateTime.weekday (the admin
    // wizard stores 7 for Sunday). Do NOT convert to 0-6 — doing so
    // makes Sunday deliveries never match and fall back to the wrong
    // scheduledDate.
    if (schedule.deliveryDaysOfWeek.isNotEmpty) {
      for (int i = 0; i < 14; i++) {
        final checkDate = today.add(Duration(days: i));
        if (schedule.deliveryDaysOfWeek.contains(checkDate.weekday)) {
          return checkDate;
        }
      }
    }

    return schedule.deliveryDate ?? schedule.scheduledDate;
  }

  /// Parse time string and combine with date
  DateTime _parseDateTime(DateTime date, String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return DateTime(date.year, date.month, date.day, hour, minute);
      }
    } catch (e) {
      // If parsing fails, default to end of day
    }
    return DateTime(date.year, date.month, date.day, 23, 59);
  }

  /// Add item to a specific schedule's cart
  void addItem(OperationalScheduleModel schedule, CartItemModel item) {
    final cart = _getOrCreateCart(schedule);

    // Check if cart can be modified
    if (!cart.canModify) {
      throw Exception('Cannot modify cart after cutoff time');
    }

    final updatedItems = Map<String, CartItemModel>.from(cart.items);
    updatedItems[item.productId] = item.copyWith(
      scheduleId: schedule.id,
      scheduleName: schedule.scheduleName,
    );

    state = {
      ...state,
      schedule.id: cart.copyWith(items: updatedItems),
    };
  }

  /// Update quantity for an item in a specific schedule's cart
  void updateQuantity(String scheduleId, String productId, double quantity) {
    final cart = state[scheduleId];
    if (cart == null) return;

    // Check if cart can be modified
    if (!cart.canModify) {
      throw Exception('Cannot modify cart after cutoff time');
    }

    if (quantity <= 0) {
      removeItem(scheduleId, productId);
      return;
    }

    final item = cart.items[productId];
    if (item != null) {
      // For discrete units, ensure quantity is a whole number
      if (item.isDiscreteUnit) {
        quantity = quantity.roundToDouble();
      }

      final updatedItems = Map<String, CartItemModel>.from(cart.items);
      updatedItems[productId] = item.copyWith(quantity: quantity);

      state = {
        ...state,
        scheduleId: cart.copyWith(items: updatedItems),
      };
    }
  }

  /// Increment quantity for an item
  void incrementQuantity(String scheduleId, String productId) {
    final cart = state[scheduleId];
    if (cart == null) return;

    final item = cart.items[productId];
    if (item != null) {
      final newQuantity = item.quantity + item.quantityIncrement;
      updateQuantity(scheduleId, productId, newQuantity);
    }
  }

  /// Decrement quantity for an item
  void decrementQuantity(String scheduleId, String productId) {
    final cart = state[scheduleId];
    if (cart == null) return;

    final item = cart.items[productId];
    if (item != null) {
      final newQuantity = item.quantity - item.quantityIncrement;
      updateQuantity(scheduleId, productId, newQuantity);
    }
  }

  /// Remove item from a specific schedule's cart
  void removeItem(String scheduleId, String productId) {
    final cart = state[scheduleId];
    if (cart == null) return;

    // Check if cart can be modified
    if (!cart.canModify) {
      throw Exception('Cannot modify cart after cutoff time');
    }

    final updatedItems = Map<String, CartItemModel>.from(cart.items);
    updatedItems.remove(productId);

    if (updatedItems.isEmpty) {
      // Remove entire cart if no items left
      final newState = Map<String, ScheduleCartModel>.from(state);
      newState.remove(scheduleId);
      state = newState;
    } else {
      state = {
        ...state,
        scheduleId: cart.copyWith(items: updatedItems),
      };
    }
  }

  /// Clear a specific schedule's cart
  void clearScheduleCart(String scheduleId) {
    final cart = state[scheduleId];
    if (cart == null) return;

    // Check if cart can be modified
    if (!cart.canModify) {
      throw Exception('Cannot modify cart after cutoff time');
    }

    final newState = Map<String, ScheduleCartModel>.from(state);
    newState.remove(scheduleId);
    state = newState;
  }

  /// Clear all carts
  void clearAll() {
    state = {};
  }

  /// Get total amount across all carts
  double get totalAmount {
    return state.values.fold(0.0, (sum, cart) => sum + cart.totalAmount);
  }

  /// Get total item count across all carts
  int get totalItemCount {
    return state.values.fold(0, (sum, cart) => sum + cart.itemCount);
  }

  /// Get list of all carts
  List<ScheduleCartModel> get allCarts {
    return state.values.toList()
      ..sort((a, b) => a.cutoffDateTime.compareTo(b.cutoffDateTime));
  }

  /// Check if a product is in any cart
  bool isProductInCart(String productId) {
    return state.values.any((cart) => cart.items.containsKey(productId));
  }

  /// Get quantity of a product in a specific schedule's cart
  double getProductQuantity(String scheduleId, String productId) {
    final cart = state[scheduleId];
    return cart?.items[productId]?.quantity ?? 0.0;
  }

  /// Lock a cart (e.g., after order is placed)
  void lockCart(String scheduleId) {
    final cart = state[scheduleId];
    if (cart == null) return;

    state = {
      ...state,
      scheduleId: cart.copyWith(isLocked: true),
    };
  }
}

/// Provider for total cart count (badge)
final cartCountProvider = Provider<int>((ref) {
  final carts = ref.watch(scheduleCartsProvider);
  return carts.values.fold(0, (sum, cart) => sum + cart.itemCount);
});

/// Provider for total cart amount
final cartTotalProvider = Provider<double>((ref) {
  final carts = ref.watch(scheduleCartsProvider);
  return carts.values.fold(0.0, (sum, cart) => sum + cart.totalAmount);
});
