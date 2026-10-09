/// One farmer's items, in their original relative order.
class FarmerGroup<T> {
  const FarmerGroup({
    required this.key,
    required this.farmerId,
    required this.farmerName,
    required this.items,
  });

  /// Stable grouping key (the farmer id, or a fallback for legacy lines).
  final String key;
  final String? farmerId;
  final String farmerName;
  final List<T> items;
}

const String unassignedFarmerLabel = 'Unassigned Farmer';

bool _isBlank(String? v) => v == null || v.trim().isEmpty;

/// Groups [items] by farmer.
///
/// - Grouping uses the farmer id. Legacy lines without an id fall back to
///   their farmer name; lines with neither go to one "Unassigned" group.
/// - Items keep their original relative order inside a group.
/// - Groups are ordered by farmer name (case-insensitive, then key), with the
///   unassigned group last, so the order is deterministic.
/// - Every item appears in exactly one group.
List<FarmerGroup<T>> groupByFarmer<T>(
  Iterable<T> items, {
  required String? Function(T item) farmerIdOf,
  required String? Function(T item) farmerNameOf,
}) {
  final keys = <String>[];
  final ids = <String, String?>{};
  final names = <String, String>{};
  final buckets = <String, List<T>>{};

  for (final item in items) {
    final id = farmerIdOf(item);
    final name = farmerNameOf(item);
    final hasName = !_isBlank(name) && name!.trim() != 'Unknown';
    final String key;
    if (!_isBlank(id)) {
      key = 'id:${id!.trim()}';
    } else if (hasName) {
      key = 'name:${name.trim().toLowerCase()}';
    } else {
      key = '';
    }
    if (!buckets.containsKey(key)) {
      keys.add(key);
      buckets[key] = [];
      ids[key] = _isBlank(id) ? null : id!.trim();
    }
    buckets[key]!.add(item);
    if (hasName && (names[key] ?? '').isEmpty) {
      names[key] = name.trim();
    }
  }

  final groups = [
    for (final key in keys)
      FarmerGroup<T>(
        key: key,
        farmerId: ids[key],
        farmerName: names[key] ?? unassignedFarmerLabel,
        items: buckets[key]!,
      ),
  ];

  groups.sort((a, b) {
    if (a.key.isEmpty != b.key.isEmpty) return a.key.isEmpty ? 1 : -1;
    final byName =
        a.farmerName.toLowerCase().compareTo(b.farmerName.toLowerCase());
    return byName != 0 ? byName : a.key.compareTo(b.key);
  });
  return groups;
}

/// The items of [groupByFarmer] flattened back into one list (farmer by
/// farmer). Useful where a flat, grouped sequence is needed (text output).
List<T> flattenFarmerGroups<T>(List<FarmerGroup<T>> groups) =>
    [for (final g in groups) ...g.items];
