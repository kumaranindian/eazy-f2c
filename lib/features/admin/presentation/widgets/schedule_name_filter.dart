import 'package:f2c/features/admin/utils/schedule_filter.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:flutter/material.dart';

/// Schedule name dropdown for the admin order-based pages. Options come from
/// the schedule names present on [orders], so it only offers schedules that
/// can actually match. Styled like the other filter dropdowns on those pages.
class ScheduleNameFilter extends StatelessWidget {
  const ScheduleNameFilter({
    super.key,
    required this.orders,
    required this.selected,
    required this.onChanged,
  });

  final List<OrderModel> orders;

  /// `null` for all schedules, [kNoScheduleFilterValue] for orders without a
  /// schedule, otherwise a schedule name.
  final String? selected;
  final ValueChanged<String?> onChanged;

  static const String _allLabel = 'All Schedules';
  static const String _noneLabel = 'No schedule';
  static const double _maxLabelWidth = 200;

  @override
  Widget build(BuildContext context) {
    final names = ScheduleFilter.namesOf(orders);
    final hasUnscheduled = ScheduleFilter.hasUnscheduled(orders);

    // Keep the current selection selectable even if the data no longer has
    // it (e.g. a date range change), so the dropdown never shows a value the
    // list is still filtering on without an entry for it.
    final options = <String?>[
      null,
      ...names,
      if (hasUnscheduled || selected == kNoScheduleFilterValue)
        kNoScheduleFilterValue,
      if (selected != null &&
          selected != kNoScheduleFilterValue &&
          !names.contains(selected))
        selected,
    ];

    String labelOf(String? value) {
      if (value == null) return _allLabel;
      if (value == kNoScheduleFilterValue) return _noneLabel;
      return value;
    }

    Widget label(String? value) => ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxLabelWidth),
          child: Text(
            labelOf(value),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey[50],
      ),
      child: DropdownButton<String?>(
        value: selected,
        underline: const SizedBox(),
        isDense: true,
        style: const TextStyle(fontSize: 13, color: Colors.black87),
        items: [
          for (final option in options)
            DropdownMenuItem<String?>(value: option, child: label(option)),
        ],
        selectedItemBuilder: (context) => [
          for (final option in options)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.event_note_outlined, size: 16),
                const SizedBox(width: 6),
                label(option),
              ],
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
