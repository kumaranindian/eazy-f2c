import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/customer/models/schedule_cart_model.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';

/// Provider for managing multiple schedule-based carts
final scheduleCartsProvider = StateNotifierProvider<ScheduleCartsNotifier, Map<String, ScheduleCartModel>>((ref) {
  return ScheduleCartsNotifier();
});

class ScheduleCartsNotifier extends StateNotifier<Map<String, ScheduleCartModel>> {
  ScheduleCartsNotifier() : super({});

  /// Initialize or get cart for a specific schedule
  ScheduleCartModel _getOrCreateCart(OperationalScheduleModel schedule) {
    if (state.containsKey(schedule.id)) {
      return state[schedule.id]!;
    }

    // Calculate cutoff date time
    final cutoffDateTime = _calculateCutoffDateTime(schedule);

    // Create new cart for this schedule
    final newCart = ScheduleCartModel(
      scheduleId: schedule.id,
      scheduleName: schedule.scheduleName,
      deliveryDate: _calculateDeliveryDate(schedule),
      deliveryTime: '${schedule.startTime} - ${schedule.endTime}',
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

    // Find the maximum day in recurrenceDaysOfWeek (last ordering day)
    if (schedule.recurrenceDaysOfWeek.isEmpty) {
      // If no recurrence days, use today with end time
      return _parseDateTime(today, schedule.endTime);
    }

    final maxDay = schedule.recurrenceDaysOfWeek.reduce((a, b) => a > b ? a : b);
    
    // Find next occurrence of max day
    DateTime cutoffDate = today;
    for (int i = 0; i < 7; i++) {
      final checkDate = today.add(Duration(days: i));
      final weekday = checkDate.weekday; // 1=Monday, 7=Sunday
      
      if (weekday == maxDay) {
        cutoffDate = checkDate;
        break;
      }
    }

    // Combine with end time
    return _parseDateTime(cutoffDate, schedule.endTime);
  }

  /// Calculate delivery date based on schedule's delivery days
  DateTime _calculateDeliveryDate(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (schedule.deliveryDaysOfWeek.isEmpty) {
      return schedule.scheduledDate;
    }

    // Find next delivery day
    for (int i = 0; i < 14; i++) {
      final checkDate = today.add(Duration(days: i));
      final weekday = checkDate.weekday; // 1=Monday, 7=Sunday
      
      // Convert to 0-6 format (Sunday=0) to match deliveryDaysOfWeek
      final convertedWeekday = weekday == 7 ? 0 : weekday;
      
      if (schedule.deliveryDaysOfWeek.contains(convertedWeekday)) {
        return checkDate;
      }
    }

    return schedule.scheduledDate;
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
