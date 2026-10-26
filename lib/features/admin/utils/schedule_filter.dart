import 'package:f2c/features/customer/models/order_model.dart';

/// Selection value meaning "orders that have no schedule name".
const String kNoScheduleFilterValue = '__no_schedule__';

/// Schedule name filtering shared by the admin orders, packaging and
/// delivery pages. A `null` selection means "all schedules".
class ScheduleFilter {
  const ScheduleFilter._();

  static String? _nameOf(OrderModel order) {
    final name = order.scheduleName?.trim();
    return (name == null || name.isEmpty) ? null : name;
  }

  /// Distinct schedule names found on [orders], sorted case-insensitively.
  static List<String> namesOf(Iterable<OrderModel> orders) {
    final names = <String>{};
    for (final order in orders) {
      final name = _nameOf(order);
      if (name != null) names.add(name);
    }
    return names.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  static bool hasUnscheduled(Iterable<OrderModel> orders) =>
      orders.any((o) => _nameOf(o) == null);

  static bool matches(OrderModel order, String? selected) {
    if (selected == null) return true;
    final name = _nameOf(order);
    if (selected == kNoScheduleFilterValue) return name == null;
    return name == selected;
  }

  static List<OrderModel> apply(List<OrderModel> orders, String? selected) {
    if (selected == null) return orders;
    return orders.where((o) => matches(o, selected)).toList();
  }
}
