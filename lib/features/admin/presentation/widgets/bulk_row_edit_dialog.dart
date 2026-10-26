import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/providers/bulk_product_import_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edits one row of the review table. Works in a narrow (phone) or wide
/// layout; changes are re-validated against the live farmer/category/unit
/// lists when saved.
class BulkRowEditDialog extends ConsumerStatefulWidget {
  const BulkRowEditDialog({super.key, required this.row});

  final BulkProductRow row;

  static Future<void> show(BuildContext context, BulkProductRow row) {
    return showDialog<void>(
      context: context,
      builder: (_) => BulkRowEditDialog(row: row),
    );
  }

  @override
  ConsumerState<BulkRowEditDialog> createState() => _BulkRowEditDialogState();
}

class _BulkRowEditDialogState extends ConsumerState<BulkRowEditDialog> {
  late final _name = TextEditingController(text: widget.row.name);
  late final _displayName = TextEditingController(text: widget.row.displayName);
  late final _price = TextEditingController(text: widget.row.priceText);
  late final _margin = TextEditingController(text: widget.row.marginText);
  late final _stock = TextEditingController(text: widget.row.stockText);
  late final _category = TextEditingController(text: widget.row.category);
  late final _unit = TextEditingController(text: widget.row.unit);
  late final _farmer = TextEditingController(text: widget.row.farmerName);

  @override
  void dispose() {
    for (final c in [
      _name,
      _displayName,
      _price,
      _margin,
      _stock,
      _category,
      _unit,
      _farmer,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    ref.read(bulkImportControllerProvider.notifier).updateRow(
          widget.row.sheetRow,
          (r) => r.copyWith(
            name: _name.text.trim(),
            displayName: _displayName.text.trim(),
            priceText: _price.text.trim(),
            marginText: _margin.text.trim(),
            stockText: _stock.text.trim(),
            category: _category.text.trim(),
            unit: _unit.text.trim(),
            farmerName: _farmer.text.trim(),
          ),
        );
    Navigator.of(context).pop();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    List<String> options = const [],
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: options.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Pick existing',
                icon: const Icon(Icons.arrow_drop_down),
                onSelected: (v) => controller.text = v,
                itemBuilder: (_) => [
                  for (final o in options)
                    PopupMenuItem(value: o, child: Text(o)),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkImportControllerProvider);
    final categories = state.categories
        .where((c) => !c.isDeleted)
        .map((c) => c.name)
        .toList()
      ..sort();
    final units = state.units
        .where((u) => !u.isDeleted)
        .map((u) => u.symbol)
        .toSet()
        .toList()
      ..sort();
    final farmers = state.farmers
        .where((f) => !f.isDeleted)
        .map((f) => f.name)
        .toList()
      ..sort();

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 480;
            Widget pair(Widget a, Widget b) => twoColumns
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: a),
                      const SizedBox(width: 12),
                      Expanded(child: b),
                    ],
                  )
                : Column(children: [a, const SizedBox(height: 12), b]);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Edit row ${widget.row.sheetRow}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _field(_name, 'Product name (farmer)'),
                        const SizedBox(height: 12),
                        _field(_displayName, 'Display name (customer)'),
                        const SizedBox(height: 12),
                        pair(
                          _field(_price, 'Price (incl. margin)',
                              keyboard: const TextInputType.numberWithOptions(
                                  decimal: true)),
                          _field(_margin, 'Profit margin',
                              keyboard: const TextInputType.numberWithOptions(
                                  decimal: true)),
                        ),
                        const SizedBox(height: 12),
                        pair(
                          _field(_stock, 'Stock',
                              keyboard: TextInputType.number),
                          _field(_unit, 'Unit', options: units),
                        ),
                        const SizedBox(height: 12),
                        _field(_category, 'Category', options: categories),
                        const SizedBox(height: 12),
                        _field(_farmer, 'Farmer (must exist)',
                            options: farmers),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
