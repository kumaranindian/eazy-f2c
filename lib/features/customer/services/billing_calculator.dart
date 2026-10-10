import 'package:f2c/features/customer/models/order_model.dart';

/// Single source of truth for money and quantity arithmetic.
///
/// Money is computed in integer paise and quantities in integer milli-units so
/// that sums of per-session values are exact (no 99.999999 style drift).
/// Rounding happens in exactly one place: [lineAmountPaise] rounds each line
/// half-up to the nearest paisa. Subtotals and totals are exact integer sums.
///
/// Current business rule (unchanged): total = sum(lines) + deliveryCharges +
/// cleaningCharges. The app has no taxes or discounts.
class BillingCalculator {
  const BillingCalculator._();

  static int toPaise(double rupees) => (rupees * 100).round();
  static double toRupees(int paise) => paise / 100;
  static int toMilli(double quantity) => (quantity * 1000).round();
  static double fromMilli(int milli) => milli / 1000;

  /// price (₹/unit) × quantity, rounded half-up to whole paise.
  static int lineAmountPaise({
    required double unitPrice,
    required double quantity,
  }) {
    final product = toPaise(unitPrice) * toMilli(quantity);
    return product >= 0 ? (product + 500) ~/ 1000 : -((-product + 500) ~/ 1000);
  }

  static double lineAmount({
    required double unitPrice,
    required double quantity,
  }) =>
      toRupees(lineAmountPaise(unitPrice: unitPrice, quantity: quantity));

  /// Sum of lines for [items], each billed at [quantityOf] (rupees).
  static double subtotal(
    Iterable<OrderItem> items,
    double Function(OrderItem item) quantityOf,
  ) {
    var paise = 0;
    for (final item in items) {
      paise += lineAmountPaise(
        unitPrice: item.price,
        quantity: quantityOf(item),
      );
    }
    return toRupees(paise);
  }

  static double total({
    required double subtotal,
    required double deliveryCharges,
    required double cleaningCharges,
  }) =>
      toRupees(
        toPaise(subtotal) + toPaise(deliveryCharges) + toPaise(cleaningCharges),
      );
}

/// Item-level packing arithmetic derived from persisted order data.
class PackingCalculator {
  const PackingCalculator._();

  static const _finalizedStatuses = {
    OrderStatus.ready,
    OrderStatus.in_transit,
    OrderStatus.delivered,
  };

  static bool isFinalized(OrderModel order) =>
      _finalizedStatuses.contains(order.status);

  /// Cumulative packed quantity for [item].
  ///
  /// Legacy orders (packed before item-level tracking existed) have no
  /// `packedQuantity`; once finalized their `quantity` already is the packed
  /// quantity, so it is used. Legacy un-finalized orders have packed nothing.
  static double packedQuantityOf(OrderModel order, OrderItem item) {
    if (item.packedQuantity > 0) return item.packedQuantity;
    return isFinalized(order) ? item.quantity : 0.0;
  }

  /// Quantity still to pack; never negative.
  static double remainingQuantityOf(OrderModel order, OrderItem item) {
    final milli = BillingCalculator.toMilli(item.quantity) -
        BillingCalculator.toMilli(packedQuantityOf(order, item));
    return BillingCalculator.fromMilli(milli < 0 ? 0 : milli);
  }

  static bool isFullyPacked(OrderModel order) =>
      order.items.every((item) => remainingQuantityOf(order, item) == 0);

  /// 'partially_packed' | 'fully_packed' | null (nothing packed yet).
  static String? packingStatusOf(OrderModel order) {
    if (order.items.isEmpty) return null;
    if (isFullyPacked(order)) return 'fully_packed';
    final anyPacked =
        order.items.any((item) => packedQuantityOf(order, item) > 0);
    return anyPacked ? 'partially_packed' : null;
  }
}
