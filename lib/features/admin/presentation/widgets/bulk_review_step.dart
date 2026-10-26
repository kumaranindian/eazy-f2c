import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/presentation/widgets/bulk_row_edit_dialog.dart';
import 'package:f2c/features/admin/providers/bulk_product_import_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Review & approve step. Nothing is written until the admin ticks the
/// approval box and confirms.
class BulkReviewStep extends ConsumerStatefulWidget {
  const BulkReviewStep({super.key});

  @override
  ConsumerState<BulkReviewStep> createState() => _BulkReviewStepState();
}

class _BulkReviewStepState extends ConsumerState<BulkReviewStep> {
  final _searchController = TextEditingController();
  BulkRowStatus? _statusFilter;
  String? _categoryFilter;
  String _query = '';

  /// Width at which the table layout replaces the card layout.
  static const double _tableBreakpoint = 980;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<BulkProductRow> _filtered(List<BulkProductRow> rows) {
    final q = _query.trim().toLowerCase();
    return rows.where((r) {
      if (_statusFilter != null && r.status != _statusFilter) return false;
      if (_categoryFilter != null && r.category != _categoryFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.displayName.toLowerCase().contains(q) ||
          r.farmerName.toLowerCase().contains(q) ||
          r.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _confirmAndImport(BulkImportState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import products?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${state.newCount} new products will be created.'),
            if (state.updateCount > 0)
              Text('${state.updateCount} existing products will be updated.'),
            if (state.newCategoryNames.isNotEmpty)
              Text('${state.newCategoryNames.length} new categories will be '
                  'created.'),
            if (state.newUnitNames.isNotEmpty)
              Text('${state.newUnitNames.length} new units will be created.'),
            const SizedBox(height: 8),
            const Text(
              'Products are created active, without images.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(bulkImportControllerProvider.notifier).runImport();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bulkImportControllerProvider);
    final controller = ref.read(bulkImportControllerProvider.notifier);
    final filtered = _filtered(state.rows);
    final categories = state.rows.map((r) => r.category).toSet().toList()
      ..sort();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _tableBreakpoint;
        final pad = constraints.maxWidth < 600 ? 12.0 : 20.0;

        return Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Summary(
                            state: state,
                            selected: _statusFilter,
                            onSelect: (s) => setState(() => _statusFilter = s),
                          ),
                          if (state.errors.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                state.errors.join('\n'),
                                style: TextStyle(color: Colors.red[800]),
                              ),
                            ),
                          if (state.unmatchedFarmerNames.isNotEmpty)
                            _FarmerMapping(state: state),
                          const SizedBox(height: 12),
                          _Toolbar(
                            searchController: _searchController,
                            onQuery: (v) => setState(() => _query = v),
                            categories: categories,
                            category: _categoryFilter,
                            onCategory: (v) =>
                                setState(() => _categoryFilter = v),
                            shown: filtered,
                            hasDuplicates: state.duplicateCount > 0,
                          ),
                          const SizedBox(height: 8),
                          if (wide) const _TableHeader(),
                        ],
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('No rows match the current filter'),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                      sliver: SliverList.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final row = filtered[index];
                          return wide
                              ? _TableRow(
                                  key: ValueKey(row.sheetRow),
                                  row: row,
                                )
                              : _RowCard(
                                  key: ValueKey(row.sheetRow),
                                  row: row,
                                  wideCard: constraints.maxWidth >= 600,
                                );
                        },
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            _ApprovalBar(
              state: state,
              width: constraints.maxWidth,
              onBack: controller.backToUpload,
              onApprove: controller.setApproved,
              onImport: () => _confirmAndImport(state),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- Summary

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final BulkImportState state;
  final BulkRowStatus? selected;
  final ValueChanged<BulkRowStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int count, BulkRowStatus? status, Color color) {
      final isSelected = selected == status;
      return ChoiceChip(
        selected: isSelected,
        onSelected: (_) => onSelect(isSelected ? null : status),
        label: Text('$label $count'),
        selectedColor: color.withOpacity(0.2),
        side: BorderSide(color: color.withOpacity(0.5)),
        visualDensity: VisualDensity.compact,
      );
    }

    final lines = <String>[
      '${state.importCount} of ${state.rows.length} rows will be imported '
          '(${state.newCount} new, ${state.updateCount} updated).',
      if (state.correctionCount > 0)
        '${state.correctionCount} rows had spelling auto-corrected.',
      if (state.newCategoryNames.isNotEmpty)
        'New categories: ${state.newCategoryNames.join(', ')}.',
      if (state.newUnitNames.isNotEmpty)
        'New units: ${state.newUnitNames.join(', ')}.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            chip('All', state.rows.length, null, Colors.blueGrey),
            chip('OK', state.okCount, BulkRowStatus.ok, Colors.green),
            chip('Warnings', state.warningCount, BulkRowStatus.warning,
                Colors.orange),
            chip('Existing', state.duplicateCount, BulkRowStatus.duplicate,
                Colors.blue),
            chip('Errors', state.errorCount, BulkRowStatus.error, Colors.red),
          ],
        ),
        const SizedBox(height: 8),
        for (final l in lines)
          Text(l, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Products are created active with no image (a "no image" '
                  'icon is shown). Rows with errors are skipped. Nothing is '
                  'saved until you approve below.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Farmer mapping

class _FarmerMapping extends ConsumerWidget {
  const _FarmerMapping({required this.state});

  final BulkImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmers = state.farmers.where((f) => !f.isDeleted).toList()
      ..sort((a, b) => a.effectiveName.compareTo(b.effectiveName));
    final controller = ref.read(bulkImportControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Farmers not found',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Only existing farmers can be used. If the sheet spells a '
            'farmer differently, pick the matching farmer.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final name in state.unmatchedFarmerNames)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LayoutBuilder(
                builder: (context, c) {
                  final dropdown = DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Use existing farmer',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: [
                      for (final f in farmers)
                        DropdownMenuItem(
                          value: f.id,
                          child: Text(
                            f.effectiveName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) controller.mapFarmer(name, id);
                    },
                  );
                  final label = Text(
                    '"$name"',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  );
                  if (c.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [label, const SizedBox(height: 6), dropdown],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: label),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: dropdown),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Toolbar

class _Toolbar extends ConsumerWidget {
  const _Toolbar({
    required this.searchController,
    required this.onQuery,
    required this.categories,
    required this.category,
    required this.onCategory,
    required this.shown,
    required this.hasDuplicates,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onQuery;
  final List<String> categories;
  final String? category;
  final ValueChanged<String?> onCategory;
  final List<BulkProductRow> shown;
  final bool hasDuplicates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkImportControllerProvider.notifier);
    final rows = shown.map((r) => r.sheetRow).toList();

    final search = TextField(
      controller: searchController,
      onChanged: onQuery,
      decoration: const InputDecoration(
        hintText: 'Search product, category or farmer',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
    final categoryDropdown = DropdownButtonFormField<String?>(
      isExpanded: true,
      value: categories.contains(category) ? category : null,
      decoration: const InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        for (final c in categories)
          DropdownMenuItem<String?>(
            value: c,
            child: Text(c, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onCategory,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < 560) {
              return Column(
                children: [
                  search,
                  const SizedBox(height: 8),
                  categoryDropdown,
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: search),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: categoryDropdown),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('${shown.length} shown',
                style: TextStyle(color: Colors.grey[700], fontSize: 13)),
            TextButton(
              onPressed: shown.isEmpty
                  ? null
                  : () => controller.setIncluded(rows, true),
              child: const Text('Include shown'),
            ),
            TextButton(
              onPressed: shown.isEmpty
                  ? null
                  : () => controller.setIncluded(rows, false),
              child: const Text('Exclude shown'),
            ),
            if (hasDuplicates) ...[
              TextButton(
                onPressed: () =>
                    controller.setAllDuplicateActions(DuplicateAction.skip),
                child: const Text('Skip all existing'),
              ),
              TextButton(
                onPressed: () =>
                    controller.setAllDuplicateActions(DuplicateAction.update),
                child: const Text('Update all existing'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Row pieces

Color _statusColor(BulkRowStatus s) => switch (s) {
      BulkRowStatus.ok => Colors.green,
      BulkRowStatus.warning => Colors.orange,
      BulkRowStatus.duplicate => Colors.blue,
      BulkRowStatus.error => Colors.red,
    };

String _statusLabel(BulkRowStatus s) => switch (s) {
      BulkRowStatus.ok => 'OK',
      BulkRowStatus.warning => 'Warning',
      BulkRowStatus.duplicate => 'Exists',
      BulkRowStatus.error => 'Error',
    };

String _money(double? v) => v == null ? '-' : v.toStringAsFixed(2);

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.row);

  final BulkProductRow row;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(row.status);
    final label = row.isDuplicate && !row.hasError
        ? (row.duplicateAction == DuplicateAction.update
            ? 'Will update'
            : 'Will skip')
        : _statusLabel(row.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color.withOpacity(1),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Corrections and issues listed under a row's product name.
class _RowNotes extends StatelessWidget {
  const _RowNotes(this.row);

  final BulkProductRow row;

  @override
  Widget build(BuildContext context) {
    if (row.corrections.isEmpty && row.issues.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in row.corrections)
            Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 12),
                children: [
                  TextSpan(
                    text: '${c.field} fixed: ',
                    style: TextStyle(color: Colors.teal[800]),
                  ),
                  TextSpan(
                    text: c.from,
                    style: const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    ),
                  ),
                  const TextSpan(text: '  →  '),
                  TextSpan(
                    text: c.to,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.teal[800],
                    ),
                  ),
                ],
              ),
            ),
          for (final i in row.issues)
            Text(
              i.message,
              style: TextStyle(
                fontSize: 12,
                color: switch (i.severity) {
                  RowIssueSeverity.error => Colors.red[700],
                  RowIssueSeverity.warning => Colors.orange[800],
                  RowIssueSeverity.info => Colors.grey[700],
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DuplicateSelector extends ConsumerWidget {
  const _DuplicateSelector(this.row);

  final BulkProductRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!row.isDuplicate || row.hasError) return const SizedBox.shrink();
    return SegmentedButton<DuplicateAction>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: DuplicateAction.skip, label: Text('Skip')),
        ButtonSegment(value: DuplicateAction.update, label: Text('Update')),
      ],
      selected: {row.duplicateAction},
      onSelectionChanged: (s) => ref
          .read(bulkImportControllerProvider.notifier)
          .setDuplicateAction(row.sheetRow, s.first),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: const Row(
        children: [
          SizedBox(width: 44),
          SizedBox(width: 44, child: Text('Row', style: style)),
          Expanded(flex: 5, child: Text('Product', style: style)),
          SizedBox(width: 84, child: Text('Price', style: style)),
          SizedBox(width: 72, child: Text('Margin', style: style)),
          SizedBox(width: 56, child: Text('Stock', style: style)),
          Expanded(flex: 3, child: Text('Category / Unit', style: style)),
          Expanded(flex: 3, child: Text('Farmer', style: style)),
          SizedBox(width: 150, child: Text('Status', style: style)),
          SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TableRow extends ConsumerWidget {
  const _TableRow({super.key, required this.row});

  final BulkProductRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkImportControllerProvider.notifier);
    final dim = !row.included;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          color: row.hasError ? Colors.red.withOpacity(0.03) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Checkbox(
                value: row.included,
                onChanged: (v) =>
                    controller.setIncluded([row.sheetRow], v ?? false),
              ),
            ),
            SizedBox(
              width: 44,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text('${row.sheetRow}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (row.displayName != row.name)
                      Text(row.displayName,
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 12)),
                    _RowNotes(row),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 84,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child:
                    Text(row.price != null ? _money(row.price) : row.priceText),
              ),
            ),
            SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(row.profitMargin != null
                    ? _money(row.profitMargin)
                    : row.marginText),
              ),
            ),
            SizedBox(
              width: 56,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(row.stock?.toString() ?? row.stockText),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: Text('${row.category} · ${row.unit}'),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: Text(row.farmerName),
              ),
            ),
            SizedBox(
              width: 150,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(row),
                    if (row.isDuplicate && !row.hasError) ...[
                      const SizedBox(height: 6),
                      _DuplicateSelector(row),
                    ],
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: IconButton(
                tooltip: 'Edit row',
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => BulkRowEditDialog.show(context, row),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowCard extends ConsumerWidget {
  const _RowCard({super.key, required this.row, required this.wideCard});

  final BulkProductRow row;
  final bool wideCard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(bulkImportControllerProvider.notifier);

    Widget kv(String k, String v) => SizedBox(
          width: wideCard ? 150 : 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(k, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              Text(v, overflow: TextOverflow.ellipsis),
            ],
          ),
        );

    return Opacity(
      opacity: row.included ? 1 : 0.5,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: row.hasError ? Colors.red[200]! : Colors.grey[300]!,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: row.included,
                    onChanged: (v) =>
                        controller.setIncluded([row.sheetRow], v ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (row.displayName != row.name)
                            Text(row.displayName,
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 12)),
                          Text('Row ${row.sheetRow}',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _StatusChip(row),
                  ),
                  IconButton(
                    tooltip: 'Edit row',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => BulkRowEditDialog.show(context, row),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        kv(
                            'Price',
                            row.price != null
                                ? _money(row.price)
                                : row.priceText),
                        kv(
                            'Margin',
                            row.profitMargin != null
                                ? _money(row.profitMargin)
                                : row.marginText),
                        kv('Stock', row.stock?.toString() ?? row.stockText),
                        kv('Unit', row.unit),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(row.category,
                        style: TextStyle(color: Colors.grey[800])),
                    Text(row.farmerName,
                        style:
                            TextStyle(color: Colors.grey[700], fontSize: 12)),
                    _RowNotes(row),
                    if (row.isDuplicate && !row.hasError) ...[
                      const SizedBox(height: 8),
                      _DuplicateSelector(row),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Approval bar

class _ApprovalBar extends StatelessWidget {
  const _ApprovalBar({
    required this.state,
    required this.width,
    required this.onBack,
    required this.onApprove,
    required this.onImport,
  });

  final BulkImportState state;
  final double width;
  final VoidCallback onBack;
  final ValueChanged<bool> onApprove;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final count = state.importCount;
    final approval = CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      value: state.approved,
      onChanged: count == 0 ? null : (v) => onApprove(v ?? false),
      title: Text(
        count == 0
            ? 'No rows to import'
            : 'I have reviewed these $count products and approve the import',
        style: const TextStyle(fontSize: 14),
      ),
    );
    final back = OutlinedButton.icon(
      onPressed: onBack,
      icon: const Icon(Icons.arrow_back),
      label: const Text('Choose another file'),
    );
    final importButton = ElevatedButton.icon(
      onPressed: state.approved && count > 0 ? onImport : null,
      icon: const Icon(Icons.cloud_upload),
      label: Text('Import $count products'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
    );

    // Phone: everything stacked. Tablet: approval on top, buttons on one
    // line below. Desktop: a single row.
    final phone = width < 600;
    final desktop = width >= 900;
    final Widget child;
    if (desktop) {
      child = Row(
        children: [
          back,
          const SizedBox(width: 16),
          Expanded(child: approval),
          const SizedBox(width: 16),
          importButton,
        ],
      );
    } else if (phone) {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          approval,
          importButton,
          const SizedBox(height: 8),
          back,
        ],
      );
    } else {
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          approval,
          Row(
            children: [
              back,
              const Spacer(),
              importButton,
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(phone ? 12 : 20, 8, phone ? 12 : 20, 12),
      child: child,
    );
  }
}
