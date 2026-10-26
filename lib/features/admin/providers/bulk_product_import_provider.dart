import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/providers/category_providers.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/admin/providers/product_providers.dart';
import 'package:f2c/features/admin/providers/unit_providers.dart';
import 'package:f2c/features/admin/services/bulk_product_import_service.dart';
import 'package:f2c/features/admin/services/bulk_product_normalizer.dart';
import 'package:f2c/features/admin/services/bulk_product_parser.dart';
import 'package:f2c/features/admin/services/bulk_product_validator.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BulkImportStep { upload, review, importing, result }

class BulkImportState {
  const BulkImportState({
    this.step = BulkImportStep.upload,
    this.fileName,
    this.rows = const [],
    this.farmers = const [],
    this.categories = const [],
    this.units = const [],
    this.existingProducts = const {},
    this.farmerMapping = const {},
    this.isLoading = false,
    this.errors = const [],
    this.approved = false,
    this.progressDone = 0,
    this.progressTotal = 0,
    this.result,
  });

  final BulkImportStep step;
  final String? fileName;
  final List<BulkProductRow> rows;
  final List<FarmerModel> farmers;
  final List<CategoryModel> categories;
  final List<UnitModel> units;
  final Map<String, String> existingProducts;
  final Map<String, String> farmerMapping;
  final bool isLoading;
  final List<String> errors;
  final bool approved;
  final int progressDone;
  final int progressTotal;
  final BulkImportResult? result;

  int get importCount => rows.where((r) => r.willImport).length;
  int get newCount => rows.where((r) => r.willImport && !r.isDuplicate).length;
  int get updateCount =>
      rows.where((r) => r.willImport && r.isDuplicate).length;
  int get errorCount => rows.where((r) => r.hasError).length;
  int get duplicateCount =>
      rows.where((r) => !r.hasError && r.isDuplicate).length;
  int get warningCount =>
      rows.where((r) => !r.hasError && !r.isDuplicate && r.hasWarning).length;
  int get okCount => rows.where((r) => r.status == BulkRowStatus.ok).length;
  int get correctionCount => rows.where((r) => r.corrections.isNotEmpty).length;

  Set<String> get newCategoryNames => {
        for (final r in rows.where((r) => r.willImport && r.newCategory))
          r.categoryName!,
      };

  Set<String> get newUnitNames => {
        for (final r in rows.where((r) => r.willImport && r.newUnit)) r.unit,
      };

  /// Sheet farmer names (as written) that matched no existing farmer.
  List<String> get unmatchedFarmerNames {
    final byKey = <String, String>{};
    for (final r in rows) {
      final unmatched = r.issues.any(
        (i) =>
            i.severity == RowIssueSeverity.error &&
            i.field == 'Farmer' &&
            r.farmerName.trim().isNotEmpty,
      );
      if (unmatched) {
        byKey.putIfAbsent(
          BulkProductNormalizer.key(r.farmerName),
          () => r.farmerName,
        );
      }
    }
    return byKey.values.toList();
  }

  BulkImportState copyWith({
    BulkImportStep? step,
    String? fileName,
    List<BulkProductRow>? rows,
    List<FarmerModel>? farmers,
    List<CategoryModel>? categories,
    List<UnitModel>? units,
    Map<String, String>? existingProducts,
    Map<String, String>? farmerMapping,
    bool? isLoading,
    List<String>? errors,
    bool? approved,
    int? progressDone,
    int? progressTotal,
    BulkImportResult? result,
    bool clearResult = false,
  }) {
    return BulkImportState(
      step: step ?? this.step,
      fileName: fileName ?? this.fileName,
      rows: rows ?? this.rows,
      farmers: farmers ?? this.farmers,
      categories: categories ?? this.categories,
      units: units ?? this.units,
      existingProducts: existingProducts ?? this.existingProducts,
      farmerMapping: farmerMapping ?? this.farmerMapping,
      isLoading: isLoading ?? this.isLoading,
      errors: errors ?? this.errors,
      approved: approved ?? this.approved,
      progressDone: progressDone ?? this.progressDone,
      progressTotal: progressTotal ?? this.progressTotal,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class BulkImportController extends StateNotifier<BulkImportState> {
  BulkImportController(this._ref) : super(const BulkImportState());

  final Ref _ref;

  BulkProductImportService get _service => BulkProductImportService(
        firestore: FirebaseFirestore.instance,
        categoryRepository: _ref.read(categoryRepositoryProvider),
        unitRepository: _ref.read(unitRepositoryProvider),
      );

  BulkValidationContext _context(BulkImportState s) => BulkValidationContext(
        farmers: s.farmers,
        categories: s.categories,
        units: s.units,
        existingProducts: s.existingProducts,
        farmerMapping: s.farmerMapping,
      );

  Future<void> loadFile(Uint8List bytes, String fileName) async {
    state = state.copyWith(
      isLoading: true,
      errors: const [],
      fileName: fileName,
    );
    final parsed = BulkProductParser.parse(bytes: bytes, fileName: fileName);
    if (parsed.hasErrors) {
      state = state.copyWith(isLoading: false, errors: parsed.errors);
      return;
    }
    try {
      await _loadReferenceData();
      final validated = BulkProductValidator.validate(
        parsed.rows,
        _context(state),
      );
      state = state.copyWith(
        rows: validated,
        step: BulkImportStep.review,
        isLoading: false,
        approved: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errors: ['Could not load farmers, categories and units: $e'],
      );
    }
  }

  Future<void> _loadReferenceData() async {
    final farmers = await _ref.read(farmerRepositoryProvider).getFarmers();
    final categories =
        await _ref.read(categoryRepositoryProvider).getCategories();
    final units = await _ref.read(unitRepositoryProvider).getUnits();
    final existing = await _service.loadExistingProducts();
    state = state.copyWith(
      farmers: farmers,
      categories: categories,
      units: units,
      existingProducts: existing,
    );
  }

  void _revalidate(List<BulkProductRow> rows, {Map<String, String>? mapping}) {
    final next = state.copyWith(farmerMapping: mapping);
    state = next.copyWith(
      rows: BulkProductValidator.validate(rows, _context(next)),
      approved: false,
    );
  }

  void updateRow(int sheetRow, BulkProductRow Function(BulkProductRow) edit) {
    _revalidate([
      for (final r in state.rows) r.sheetRow == sheetRow ? edit(r) : r,
    ]);
  }

  void setIncluded(Iterable<int> sheetRows, bool included) {
    final targets = sheetRows.toSet();
    _revalidate([
      for (final r in state.rows)
        targets.contains(r.sheetRow) ? r.copyWith(included: included) : r,
    ]);
  }

  void setDuplicateAction(int sheetRow, DuplicateAction action) {
    updateRow(sheetRow, (r) => r.copyWith(duplicateAction: action));
  }

  void setAllDuplicateActions(DuplicateAction action) {
    _revalidate([
      for (final r in state.rows)
        r.isDuplicate ? r.copyWith(duplicateAction: action) : r,
    ]);
  }

  void mapFarmer(String sheetFarmerName, String farmerId) {
    final mapping = Map<String, String>.from(state.farmerMapping)
      ..[BulkProductNormalizer.key(sheetFarmerName)] = farmerId;
    _revalidate(state.rows, mapping: mapping);
  }

  void setApproved(bool value) {
    state = state.copyWith(approved: value);
  }

  void backToUpload() {
    state = const BulkImportState();
  }

  Future<void> runImport() async {
    final user = _ref.read(currentUserProvider).value;
    if (user == null || !state.approved) return;

    final rows = state.rows;

    state = state.copyWith(
      step: BulkImportStep.importing,
      progressDone: 0,
      progressTotal: rows.where((r) => r.willImport).length,
      clearResult: true,
    );

    try {
      final result = await _service.import(
        rows: rows,
        userId: user.id,
        userRole: user.role,
        onProgress: (done, total) {
          if (!mounted) return;
          state = state.copyWith(progressDone: done, progressTotal: total);
        },
      );
      if (!mounted) return;
      state = state.copyWith(step: BulkImportStep.result, result: result);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        step: BulkImportStep.review,
        errors: ['Import failed: $e'],
      );
    } finally {
      if (mounted) {
        _ref.invalidate(productStatsProvider);
        _ref.invalidate(displayNamesProvider);
      }
    }
  }

  /// Goes back to review with only the rows that failed, after refreshing
  /// reference data so categories/units created by the first run are seen.
  Future<void> reviewFailed() async {
    final failed = state.result?.failed.map((f) => f.row.sheetRow).toSet();
    if (failed == null || failed.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      await _loadReferenceData();
      final rows = state.rows.where((r) => failed.contains(r.sheetRow));
      state = state.copyWith(
        rows: BulkProductValidator.validate(rows.toList(), _context(state)),
        step: BulkImportStep.review,
        isLoading: false,
        approved: false,
        clearResult: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errors: ['Could not refresh data: $e'],
      );
    }
  }
}

final bulkImportControllerProvider =
    StateNotifierProvider.autoDispose<BulkImportController, BulkImportState>(
        (ref) {
  return BulkImportController(ref);
});
