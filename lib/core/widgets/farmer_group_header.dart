import 'package:f2c/core/shared/utils/farmer_grouping.dart';
import 'package:flutter/material.dart';

/// Section heading shown above one farmer's items.
class FarmerGroupHeader extends StatelessWidget {
  const FarmerGroupHeader({required this.farmerName, super.key});

  final String farmerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Icon(Icons.agriculture, size: 16, color: Colors.green[700]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              farmerName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Builds `[header, item, item, header, item, ...]` for [items] grouped by
/// farmer. [itemBuilder] receives the running 0-based position across all
/// groups (handy for serial numbers).
List<Widget> buildFarmerGroupedWidgets<T>(
  Iterable<T> items, {
  required String? Function(T item) farmerIdOf,
  required String? Function(T item) farmerNameOf,
  required Widget Function(T item, int position) itemBuilder,
}) {
  final widgets = <Widget>[];
  var position = 0;
  for (final group in groupByFarmer<T>(
    items,
    farmerIdOf: farmerIdOf,
    farmerNameOf: farmerNameOf,
  )) {
    widgets.add(FarmerGroupHeader(farmerName: group.farmerName));
    for (final item in group.items) {
      widgets.add(itemBuilder(item, position++));
    }
  }
  return widgets;
}
