import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/repositories/category_repository.dart';
import 'package:f2c/features/admin/repositories/unit_repository.dart';
import 'package:f2c/features/admin/services/bulk_product_normalizer.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:uuid/uuid.dart';

/// Writes approved [BulkProductRow]s to Firestore.
///
/// Products are written in batches. A deterministic document id (derived
/// from the normalised product name) makes a retry of the same rows
/// idempotent instead of creating duplicates.
class BulkProductImportService {
  BulkProductImportService({
    required FirebaseFirestore firestore,
    required CategoryRepository categoryRepository,
    required UnitRepository unitRepository,
  })  : _firestore = firestore,
        _categoryRepository = categoryRepository,
        _unitRepository = unitRepository;

  final FirebaseFirestore _firestore;
  final CategoryRepository _categoryRepository;
  final UnitRepository _unitRepository;

  static const int batchSize = 400;
  static const Uuid _uuid = Uuid();

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  /// Non-deleted products keyed by normalised name, for duplicate checks.
  Future<Map<String, String>> loadExistingProducts() async {
    final snapshot = await _products.where('isDeleted', isEqualTo: false).get();
    final result = <String, String>{};
    for (final doc in snapshot.docs) {
      final name = doc.data()['name'] as String? ?? '';
      final key = BulkProductNormalizer.key(name);
      if (key.isNotEmpty) result.putIfAbsent(key, () => doc.id);
    }
    return result;
  }

  static String documentIdFor(String productKey) =>
      _uuid.v5(Namespace.url.value, 'f2c-product:$productKey');

  Future<BulkImportResult> import({
    required List<BulkProductRow> rows,
    required String userId,
    required UserRole userRole,
    void Function(int done, int total)? onProgress,
  }) async {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage products',
      );
    }

    final toWrite = rows.where((r) => r.willImport).toList();
    final skipped = rows.length - toWrite.length;
    final failures = <BulkRowFailure>[];
    var created = 0;
    var updated = 0;
    var done = 0;
    onProgress?.call(0, toWrite.length);

    // 1. Categories and units that do not exist yet.
    final categoriesCreated = <String>{};
    final unitsCreated = <String>{};
    final blocked = <BulkProductRow, String>{};
    final now = DateTime.now();

    for (final row in toWrite.where((r) => r.newCategory)) {
      final name = row.categoryName!;
      final key = BulkProductNormalizer.key(name);
      if (categoriesCreated.contains(key)) continue;
      try {
        await _categoryRepository.createCategory(
          CategoryModel(
            id: '',
            name: name,
            description: '',
            isActive: true,
            isDeleted: false,
            createdAt: now,
            createdBy: userId,
          ),
          userId,
          userRole,
        );
        categoriesCreated.add(key);
      } catch (e, stackTrace) {
        AppLogger.error('Bulk import: create category failed', e, stackTrace);
        blocked[row] = 'Could not create category "$name"';
      }
    }

    for (final row in toWrite.where((r) => r.newUnit)) {
      final symbol = row.unitSymbol!;
      if (unitsCreated.contains(symbol)) continue;
      try {
        await _unitRepository.createUnit(
          UnitModel(
            id: '',
            name: row.unit,
            symbol: symbol,
            category: row.categoryName == 'Meat' ? 'meat' : 'grocery',
            isActive: true,
            isDeleted: false,
            createdAt: now,
            createdBy: userId,
          ),
        );
        unitsCreated.add(symbol);
      } catch (e, stackTrace) {
        AppLogger.error('Bulk import: create unit failed', e, stackTrace);
        blocked[row] = 'Could not create unit "${row.unit}"';
      }
    }

    // Rows whose category/unit could not be created fail up front. Rows that
    // share the same missing category/unit fail with them.
    final writable = <BulkProductRow>[];
    for (final row in toWrite) {
      final reason = blocked[row] ??
          _sharedBlockReason(
            row,
            blocked,
            categoriesCreated: categoriesCreated,
            unitsCreated: unitsCreated,
          );
      if (reason != null) {
        failures.add(BulkRowFailure(row: row, message: reason));
        done++;
      } else {
        writable.add(row);
      }
    }
    onProgress?.call(done, toWrite.length);

    // 2. Products, in batches.
    for (var start = 0; start < writable.length; start += batchSize) {
      final chunk = writable.skip(start).take(batchSize).toList();
      try {
        final batch = _firestore.batch();
        for (final row in chunk) {
          if (row.isDuplicate &&
              row.duplicateAction == DuplicateAction.update) {
            batch.update(_products.doc(row.existingProductId), {
              'displayName': row.displayName,
              'price': row.price,
              'profitMargin': row.profitMargin,
              'stockQuantity': row.stock,
              'category': row.categoryName,
              'unit': row.unitSymbol,
              'farmerId': row.farmerId,
              'updatedAt': Timestamp.fromDate(now),
              'updatedBy': userId,
            });
          } else {
            final product = ProductModel(
              id: '',
              name: row.name,
              displayName: row.displayName,
              description: '',
              imageUrl: '',
              price: row.price!,
              profitMargin: row.profitMargin ?? 0,
              unit: row.unitSymbol!,
              category: row.categoryName!,
              farmerId: row.farmerId,
              isActive: true,
              isDeleted: false,
              createdAt: now,
              createdBy: userId,
              stockQuantity: row.stock ?? 0,
            );
            batch.set(
              _products.doc(documentIdFor(row.productKey)),
              product.toFirestore(),
            );
          }
        }
        await batch.commit();
        for (final row in chunk) {
          if (row.isDuplicate) {
            updated++;
          } else {
            created++;
          }
        }
      } catch (e, stackTrace) {
        AppLogger.error('Bulk import: batch failed', e, stackTrace);
        for (final row in chunk) {
          failures.add(
            BulkRowFailure(row: row, message: 'Batch write failed: $e'),
          );
        }
      }
      done += chunk.length;
      onProgress?.call(done, toWrite.length);
    }

    AppLogger.info(
      'Bulk import finished by $userId: $created created, $updated updated, '
      '${failures.length} failed, $skipped skipped',
    );

    return BulkImportResult(
      created: created,
      updated: updated,
      skipped: skipped,
      failed: failures,
      categoriesCreated: categoriesCreated.length,
      unitsCreated: unitsCreated.length,
    );
  }

  String? _sharedBlockReason(
    BulkProductRow row,
    Map<BulkProductRow, String> blocked, {
    required Set<String> categoriesCreated,
    required Set<String> unitsCreated,
  }) {
    if (row.newCategory &&
        !categoriesCreated
            .contains(BulkProductNormalizer.key(row.categoryName!))) {
      return 'Could not create category "${row.categoryName}"';
    }
    if (row.newUnit && !unitsCreated.contains(row.unitSymbol)) {
      return 'Could not create unit "${row.unit}"';
    }
    return null;
  }
}
