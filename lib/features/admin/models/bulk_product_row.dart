enum RowIssueSeverity { error, warning, info }

enum BulkRowStatus { ok, warning, duplicate, error }

enum DuplicateAction { skip, update }

class RowIssue {
  const RowIssue(this.severity, this.message, {this.field});

  final RowIssueSeverity severity;
  final String message;
  final String? field;
}

/// A spelling fix applied automatically while reading the sheet.
class RowCorrection {
  const RowCorrection({
    required this.field,
    required this.from,
    required this.to,
  });

  final String field;
  final String from;
  final String to;
}

/// One product line of an uploaded sheet, as shown on the review screen.
///
/// The editable values are kept as text so the admin can fix them in the
/// review step; [BulkProductValidator] derives the typed values and issues.
class BulkProductRow {
  const BulkProductRow({
    required this.sheetRow,
    required this.slNo,
    required this.name,
    required this.displayName,
    required this.priceText,
    required this.marginText,
    required this.stockText,
    required this.category,
    required this.unit,
    required this.farmerName,
    this.included = true,
    this.duplicateAction = DuplicateAction.skip,
    this.corrections = const [],
    this.issues = const [],
    this.price,
    this.profitMargin,
    this.stock,
    this.farmerId,
    this.categoryName,
    this.unitSymbol,
    this.newCategory = false,
    this.newUnit = false,
    this.existingProductId,
    this.productKey = '',
  });

  /// 1-based row number in the uploaded file (header is row 1).
  final int sheetRow;
  final String slNo;
  final String name;
  final String displayName;
  final String priceText;
  final String marginText;
  final String stockText;
  final String category;
  final String unit;
  final String farmerName;

  final bool included;
  final DuplicateAction duplicateAction;
  final List<RowCorrection> corrections;

  // Derived by the validator.
  final List<RowIssue> issues;
  final double? price;
  final double? profitMargin;
  final int? stock;
  final String? farmerId;
  final String? categoryName;
  final String? unitSymbol;
  final bool newCategory;
  final bool newUnit;
  final String? existingProductId;
  final String productKey;

  bool get hasError => issues.any((i) => i.severity == RowIssueSeverity.error);

  bool get hasWarning =>
      issues.any((i) => i.severity == RowIssueSeverity.warning);

  bool get isDuplicate => existingProductId != null;

  BulkRowStatus get status {
    if (hasError) return BulkRowStatus.error;
    if (isDuplicate) return BulkRowStatus.duplicate;
    if (hasWarning) return BulkRowStatus.warning;
    return BulkRowStatus.ok;
  }

  /// Whether this row will be written when the import is approved.
  bool get willImport =>
      included &&
      !hasError &&
      !(isDuplicate && duplicateAction == DuplicateAction.skip);

  /// Copy with edited user-facing values. Derived values are kept until the
  /// next [withValidation].
  BulkProductRow copyWith({
    String? name,
    String? displayName,
    String? priceText,
    String? marginText,
    String? stockText,
    String? category,
    String? unit,
    String? farmerName,
    bool? included,
    DuplicateAction? duplicateAction,
  }) {
    return _copy(
      name: name,
      displayName: displayName,
      priceText: priceText,
      marginText: marginText,
      stockText: stockText,
      category: category,
      unit: unit,
      farmerName: farmerName,
      included: included,
      duplicateAction: duplicateAction,
    );
  }

  /// Replaces every derived value (nullable ones are overwritten as given).
  BulkProductRow withValidation({
    required List<RowIssue> issues,
    required double? price,
    required double? profitMargin,
    required int? stock,
    required String? farmerId,
    required String? categoryName,
    required String? unitSymbol,
    required bool newCategory,
    required bool newUnit,
    required String? existingProductId,
    required String productKey,
  }) {
    return BulkProductRow(
      sheetRow: sheetRow,
      slNo: slNo,
      name: name,
      displayName: displayName,
      priceText: priceText,
      marginText: marginText,
      stockText: stockText,
      category: category,
      unit: unit,
      farmerName: farmerName,
      included: included,
      duplicateAction: duplicateAction,
      corrections: corrections,
      issues: issues,
      price: price,
      profitMargin: profitMargin,
      stock: stock,
      farmerId: farmerId,
      categoryName: categoryName,
      unitSymbol: unitSymbol,
      newCategory: newCategory,
      newUnit: newUnit,
      existingProductId: existingProductId,
      productKey: productKey,
    );
  }

  BulkProductRow _copy({
    String? name,
    String? displayName,
    String? priceText,
    String? marginText,
    String? stockText,
    String? category,
    String? unit,
    String? farmerName,
    bool? included,
    DuplicateAction? duplicateAction,
  }) {
    return BulkProductRow(
      sheetRow: sheetRow,
      slNo: slNo,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      priceText: priceText ?? this.priceText,
      marginText: marginText ?? this.marginText,
      stockText: stockText ?? this.stockText,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      farmerName: farmerName ?? this.farmerName,
      included: included ?? this.included,
      duplicateAction: duplicateAction ?? this.duplicateAction,
      corrections: corrections,
      issues: issues,
      price: price,
      profitMargin: profitMargin,
      stock: stock,
      farmerId: farmerId,
      categoryName: categoryName,
      unitSymbol: unitSymbol,
      newCategory: newCategory,
      newUnit: newUnit,
      existingProductId: existingProductId,
      productKey: productKey,
    );
  }
}

/// Outcome of the write phase.
class BulkImportResult {
  const BulkImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.categoriesCreated,
    required this.unitsCreated,
  });

  final int created;
  final int updated;
  final int skipped;
  final List<BulkRowFailure> failed;
  final int categoriesCreated;
  final int unitsCreated;
}

class BulkRowFailure {
  const BulkRowFailure({required this.row, required this.message});

  final BulkProductRow row;
  final String message;
}
