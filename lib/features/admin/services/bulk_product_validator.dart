import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/services/bulk_product_normalizer.dart';

/// Reference data the rows are checked against.
class BulkValidationContext {
  const BulkValidationContext({
    required this.farmers,
    required this.categories,
    required this.units,
    required this.existingProducts,
    this.farmerMapping = const {},
  });

  final List<FarmerModel> farmers;
  final List<CategoryModel> categories;
  final List<UnitModel> units;

  /// Normalised product name -> id of a non-deleted product.
  final Map<String, String> existingProducts;

  /// Normalised sheet farmer name -> farmer id chosen by the admin.
  final Map<String, String> farmerMapping;
}

class BulkProductValidator {
  const BulkProductValidator._();

  static double? parseNumber(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'rs\.?|inr|₹', caseSensitive: false), '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  static double roundMoney(double value) =>
      double.parse((value + 1e-9).toStringAsFixed(2));

  /// Re-validates every row. Cheap enough to run on each edit.
  static List<BulkProductRow> validate(
    List<BulkProductRow> rows,
    BulkValidationContext ctx,
  ) {
    final categories = <String, CategoryModel>{
      for (final c in ctx.categories.where((c) => !c.isDeleted))
        BulkProductNormalizer.key(c.name): c,
    };
    final units = <String, UnitModel>{};
    for (final u in ctx.units.where((u) => !u.isDeleted)) {
      units[BulkProductNormalizer.key(u.symbol)] = u;
      units.putIfAbsent(BulkProductNormalizer.key(u.name), () => u);
    }

    final farmersByName = <String, Set<String>>{};
    for (final f in ctx.farmers.where((f) => !f.isDeleted)) {
      for (final label in {f.name, f.displayName ?? '', f.effectiveName}) {
        final key = BulkProductNormalizer.key(label);
        if (key.isEmpty) continue;
        farmersByName.putIfAbsent(key, () => <String>{}).add(f.id);
      }
    }
    final farmerIds = {for (final f in ctx.farmers) f.id};

    final variantNotes = _variantNotes(rows);
    final firstRowByKey = <String, int>{};

    return rows.map((row) {
      final issues = <RowIssue>[];
      void error(String field, String message) =>
          issues.add(RowIssue(RowIssueSeverity.error, message, field: field));
      void warn(String field, String message) =>
          issues.add(RowIssue(RowIssueSeverity.warning, message, field: field));
      void info(String field, String message) =>
          issues.add(RowIssue(RowIssueSeverity.info, message, field: field));

      final name = BulkProductNormalizer.tidy(row.name);
      final displayName = BulkProductNormalizer.tidy(row.displayName);
      if (name.isEmpty) error('Product name', 'Product name is required');
      if (displayName.isEmpty) {
        error('Display name', 'Display name is required');
      }

      // Price
      double? price;
      final rawPrice = parseNumber(row.priceText);
      if (row.priceText.trim().isEmpty) {
        error('Price', 'Price is required');
      } else if (rawPrice == null) {
        error('Price', 'Price "${row.priceText}" is not a number');
      } else if (rawPrice <= 0) {
        error('Price', 'Price must be greater than 0');
      } else {
        price = roundMoney(rawPrice);
        if ((price - rawPrice).abs() > 1e-9) {
          warn('Price', 'Price rounded from ${row.priceText} to $price');
        }
      }

      // Profit margin
      double? margin;
      if (row.marginText.trim().isEmpty) {
        margin = 0;
        warn('Profit margin', 'Profit margin is blank, using 0');
      } else {
        final rawMargin = parseNumber(row.marginText);
        if (rawMargin == null) {
          error('Profit margin',
              'Profit margin "${row.marginText}" is not a number');
        } else if (rawMargin < 0) {
          error('Profit margin', 'Profit margin cannot be negative');
        } else if (price != null && rawMargin > price) {
          error('Profit margin', 'Profit margin cannot exceed the price');
        } else {
          margin = roundMoney(rawMargin);
        }
      }

      // Stock
      int? stock;
      if (row.stockText.trim().isEmpty) {
        stock = 0;
        warn('Stock', 'Stock is blank, using 0');
      } else {
        final rawStock = parseNumber(row.stockText);
        if (rawStock == null || rawStock != rawStock.roundToDouble()) {
          error('Stock', 'Stock "${row.stockText}" must be a whole number');
        } else if (rawStock < 0) {
          error('Stock', 'Stock cannot be negative');
        } else {
          stock = rawStock.toInt();
        }
      }

      // Category
      String? categoryName;
      var newCategory = false;
      final categoryText = BulkProductNormalizer.tidy(row.category);
      if (categoryText.isEmpty) {
        error('Category', 'Category is required');
      } else {
        final existing = categories[BulkProductNormalizer.key(categoryText)];
        if (existing != null) {
          categoryName = existing.name;
        } else {
          categoryName = categoryText;
          newCategory = true;
          info('Category', 'Category "$categoryText" will be created');
        }
      }

      // Unit
      String? unitSymbol;
      var newUnit = false;
      final unitText = BulkProductNormalizer.tidy(row.unit);
      if (unitText.isEmpty) {
        error('Unit', 'Unit is required');
      } else {
        final existing = units[BulkProductNormalizer.key(unitText)];
        if (existing != null) {
          unitSymbol = existing.symbol;
        } else {
          unitSymbol = unitText.toLowerCase();
          newUnit = true;
          info('Unit', 'Unit "$unitText" will be created');
        }
      }

      // Farmer (existing farmers only)
      String? farmerId;
      final farmerKey = BulkProductNormalizer.key(row.farmerName);
      if (farmerKey.isEmpty) {
        error('Farmer', 'Farmer name is required');
      } else {
        final mapped = ctx.farmerMapping[farmerKey];
        if (mapped != null && farmerIds.contains(mapped)) {
          farmerId = mapped;
        } else {
          final matches = farmersByName[farmerKey];
          if (matches == null || matches.isEmpty) {
            error('Farmer',
                'Farmer "${row.farmerName}" does not exist. Only existing farmers are allowed');
          } else if (matches.length > 1) {
            error('Farmer',
                'More than one farmer is named "${row.farmerName}". Pick one');
          } else {
            farmerId = matches.first;
          }
        }
      }

      // Duplicates
      final productKey = BulkProductNormalizer.key(name);
      String? existingId;
      if (productKey.isNotEmpty) {
        existingId = ctx.existingProducts[productKey];
        if (row.included) {
          final first = firstRowByKey[productKey];
          if (first != null) {
            error(
                'Product name', 'Same product name as row $first in this file');
          } else {
            firstRowByKey[productKey] = row.sheetRow;
          }
        }
      }

      final note = variantNotes[productKey];
      if (note != null) warn('Product name', note);

      return row.withValidation(
        issues: issues,
        price: price,
        profitMargin: margin,
        stock: stock,
        farmerId: farmerId,
        categoryName: categoryName,
        unitSymbol: unitSymbol,
        newCategory: newCategory,
        newUnit: newUnit,
        existingProductId: existingId,
        productKey: productKey,
      );
    }).toList();
  }

  /// Product key -> note for names that use one of several spelling variants
  /// that both occur in the file.
  static Map<String, String> _variantNotes(List<BulkProductRow> rows) {
    final notes = <String, String>{};
    for (final group in BulkProductNormalizer.spellingVariants) {
      final used = <String>{};
      final matching = <String>[];
      for (final row in rows) {
        final key = BulkProductNormalizer.key(row.name);
        for (final variant in group) {
          if (key.contains(variant)) {
            used.add(variant);
            matching.add(key);
            break;
          }
        }
      }
      if (used.length < 2) continue;
      final message =
          'Spelling differs across rows (${group.join(' / ')}). Check which is right';
      for (final key in matching) {
        notes[key] = message;
      }
    }
    return notes;
  }
}
