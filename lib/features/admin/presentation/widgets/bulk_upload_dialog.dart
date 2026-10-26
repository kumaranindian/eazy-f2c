import 'dart:convert';
import 'dart:typed_data';

import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/presentation/widgets/bulk_review_step.dart';
import 'package:f2c/features/admin/providers/bulk_product_import_provider.dart';
import 'package:f2c/features/admin/services/bulk_product_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Multi-product upload: Upload -> Review & approve -> Import -> Result.
/// Full-screen on phones, a large dialog on tablet/desktop.
class BulkUploadDialog extends ConsumerWidget {
  const BulkUploadDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BulkUploadDialog(),
    );
  }

  static const double _fullScreenBreakpoint = 720;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bulkImportControllerProvider);
    final size = MediaQuery.sizeOf(context);
    final fullScreen = size.width < _fullScreenBreakpoint;
    final isImporting = state.step == BulkImportStep.importing;

    final content = PopScope(
      canPop: !isImporting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
              state: state,
              compact: fullScreen,
              onClose: () {
                if (!isImporting) Navigator.of(context).pop();
              }),
          const Divider(height: 1),
          Expanded(child: _body(state, fullScreen)),
        ],
      ),
    );

    if (fullScreen) {
      return Dialog.fullscreen(child: SafeArea(child: content));
    }
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < 1100 ? 16 : 32,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 1360,
          maxHeight: size.height * 0.94,
        ),
        child: SizedBox(width: double.infinity, child: content),
      ),
    );
  }

  Widget _body(BulkImportState state, bool compact) {
    switch (state.step) {
      case BulkImportStep.upload:
        return _UploadStep(state: state);
      case BulkImportStep.review:
        return const BulkReviewStep();
      case BulkImportStep.importing:
        return _ImportingStep(state: state);
      case BulkImportStep.result:
        return _ResultStep(state: state);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.compact,
    required this.onClose,
  });

  final BulkImportState state;
  final bool compact;
  final VoidCallback onClose;

  static const _labels = ['Upload', 'Review & approve', 'Import', 'Done'];

  @override
  Widget build(BuildContext context) {
    final current = state.step.index;
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, 12, 8, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bulk Upload Products',
                  style: TextStyle(
                    fontSize: compact ? 18 : 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (compact)
            Text(
              'Step ${current + 1} of ${_labels.length} · ${_labels[current]}',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  for (var i = 0; i < _labels.length; i++) ...[
                    _StepDot(
                      index: i,
                      label: _labels[i],
                      done: i < current,
                      active: i == current,
                    ),
                    if (i < _labels.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: i < current ? Colors.green : Colors.grey[300],
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: done
              ? Colors.green
              : active
                  ? Colors.blue
                  : Colors.grey[300],
          child: done
              ? const Icon(Icons.check, size: 15, color: Colors.white)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: active ? Colors.white : Colors.grey[700],
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.black87 : Colors.grey[700],
          ),
        ),
      ],
    );
  }
}

Future<void> _saveCsv(
  BuildContext context,
  String fileName,
  String content,
) async {
  try {
    await FilePicker.saveFile(
      dialogTitle: 'Save $fileName',
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _UploadStep extends ConsumerWidget {
  const _UploadStep({required this.state});

  final BulkImportState state;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(bulkImportControllerProvider.notifier);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv'],
        withData: true,
      );
      final file = picked?.files.single;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected file'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      await controller.loadFile(bytes, file.name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.upload_file, size: 56, color: Colors.green[700]),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload a product sheet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Excel (.xlsx) or CSV. You will review every row '
                      'before anything is saved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed:
                          state.isLoading ? null : () => _pick(context, ref),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.folder_open),
                      label: Text(
                        state.isLoading ? 'Reading file…' : 'Choose file',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (state.fileName != null && state.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          state.fileName!,
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
              if (state.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final e in state.errors)
                        Text(e, style: TextStyle(color: Colors.red[900])),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Expected columns',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Sl No, PRODUCT NAME, DISPLAY NAME, PRICE, PROFIT MARGIN, '
                'STOCK, CATEGORY, UNIT, FARMER NAME',
                style: TextStyle(color: Colors.grey[800]),
              ),
              const SizedBox(height: 10),
              _Note(
                icon: Icons.person_outline,
                text: 'The farmer must already exist. Rows with an unknown '
                    'farmer cannot be imported.',
              ),
              _Note(
                icon: Icons.image_not_supported_outlined,
                text: 'Products are created active without an image. Add '
                    'images later by editing the product.',
              ),
              _Note(
                icon: Icons.sell_outlined,
                text: 'Price includes the profit margin, as in Add Product. '
                    'Schedule pricing is not affected.',
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _saveCsv(
                    context,
                    'product_upload_template.csv',
                    BulkProductParser.templateCsv,
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Download template (.csv)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}

class _ImportingStep extends StatelessWidget {
  const _ImportingStep({required this.state});

  final BulkImportState state;

  @override
  Widget build(BuildContext context) {
    final total = state.progressTotal;
    final value = total == 0 ? null : state.progressDone / total;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Importing products…',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(value: value, minHeight: 8),
              const SizedBox(height: 12),
              Text('${state.progressDone} of $total'),
              const SizedBox(height: 8),
              Text(
                'Please keep this window open.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultStep extends ConsumerWidget {
  const _ResultStep({required this.state});

  final BulkImportState state;

  String _errorCsv(BulkImportResult result) {
    String q(String v) => '"${v.replaceAll('"', '""')}"';
    final buffer = StringBuffer('Row,Product,Reason\r\n');
    for (final f in result.failed) {
      buffer.write('${f.row.sheetRow},${q(f.row.name)},${q(f.message)}\r\n');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = state.result;
    if (result == null) return const SizedBox.shrink();
    final controller = ref.read(bulkImportControllerProvider.notifier);
    final hasFailures = result.failed.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Icon(
                  hasFailures ? Icons.warning_amber : Icons.check_circle,
                  size: 56,
                  color: hasFailures ? Colors.orange : Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  hasFailures
                      ? 'Import finished with errors'
                      : 'Import complete',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Stat('Created', result.created, Colors.green),
                  _Stat('Updated', result.updated, Colors.blue),
                  _Stat('Skipped', result.skipped, Colors.grey),
                  _Stat('Failed', result.failed.length, Colors.red),
                  _Stat('Categories added', result.categoriesCreated,
                      Colors.teal),
                  _Stat('Units added', result.unitsCreated, Colors.teal),
                ],
              ),
              if (hasFailures) ...[
                const SizedBox(height: 24),
                const Text(
                  'Failed rows',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final f in result.failed)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text('Row ${f.row.sheetRow} · ${f.row.name}'),
                    subtitle: Text(f.message),
                  ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (hasFailures)
                OutlinedButton.icon(
                  onPressed: () => _saveCsv(
                    context,
                    'bulk_upload_errors.csv',
                    _errorCsv(result),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Download errors'),
                ),
              if (hasFailures)
                OutlinedButton.icon(
                  onPressed: controller.reviewFailed,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Review failed rows'),
                ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
