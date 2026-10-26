import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/repositories/category_repository.dart';
import 'package:f2c/features/admin/repositories/unit_repository.dart';
import 'package:f2c/features/admin/services/bulk_product_import_service.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCategories implements CategoryRepository {
  final created = <String>[];

  @override
  Future<String> createCategory(
    CategoryModel category,
    String userId,
    UserRole userRole,
  ) async {
    created.add(category.name);
    return 'cat-${created.length}';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeUnits implements UnitRepository {
  final created = <String>[];

  @override
  Future<UnitModel> createUnit(UnitModel unit) async {
    created.add(unit.symbol);
    return unit;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BulkProductRow _row(
  int n, {
  String name = 'Rice',
  bool newCategory = false,
  bool newUnit = false,
  String? existingId,
  DuplicateAction action = DuplicateAction.skip,
}) {
  return BulkProductRow(
    sheetRow: n,
    slNo: '$n',
    name: '$name $n',
    displayName: '$name $n',
    priceText: '50',
    marginText: '5',
    stockText: '10',
    category: 'Cereals',
    unit: 'Packet',
    farmerName: 'F',
    duplicateAction: action,
  ).withValidation(
    issues: const [],
    price: 50,
    profitMargin: 5,
    stock: 10,
    farmerId: 'f1',
    categoryName: 'Cereals',
    unitSymbol: 'packet',
    newCategory: newCategory,
    newUnit: newUnit,
    existingProductId: existingId,
    productKey: '${name.toLowerCase()} $n',
  );
}

void main() {
  late FakeFirebaseFirestore firestore;
  late _FakeCategories categories;
  late _FakeUnits units;
  late BulkProductImportService service;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    categories = _FakeCategories();
    units = _FakeUnits();
    service = BulkProductImportService(
      firestore: firestore,
      categoryRepository: categories,
      unitRepository: units,
    );
  });

  test('creates active products with no image and creates category/unit once',
      () async {
    final rows = [
      _row(1, newCategory: true, newUnit: true),
      _row(2, newCategory: true, newUnit: true),
    ];
    final result = await service.import(
      rows: rows,
      userId: 'admin1',
      userRole: UserRole.admin,
    );

    expect(result.created, 2);
    expect(result.failed, isEmpty);
    expect(categories.created, ['Cereals']);
    expect(units.created, ['packet']);

    final docs = await firestore.collection('products').get();
    expect(docs.docs, hasLength(2));
    final data = docs.docs.first.data();
    expect(data['imageUrl'], '');
    expect(data['description'], '');
    expect(data['isActive'], true);
    expect(data['isDeleted'], false);
    expect(data['farmerId'], 'f1');
    expect(data['category'], 'Cereals');
    expect(data['unit'], 'packet');
    expect(data['price'], 50);
    expect(data['stockQuantity'], 10);
    expect(data['createdBy'], 'admin1');
  });

  test('re-running the same rows does not create duplicates', () async {
    final rows = [_row(1), _row(2)];
    for (var i = 0; i < 2; i++) {
      await service.import(
        rows: rows,
        userId: 'a',
        userRole: UserRole.admin,
      );
    }
    expect((await firestore.collection('products').get()).docs, hasLength(2));
  });

  test('skipped duplicates are not written; update keeps image/description',
      () async {
    await firestore.collection('products').doc('p1').set({
      'name': 'Rice 1',
      'displayName': 'Old',
      'imageUrl': 'https://img/x.png',
      'description': 'Keep me',
      'price': 10,
      'isActive': false,
      'isDeleted': false,
    });
    await firestore.collection('products').doc('p2').set({
      'name': 'Rice 2',
      'price': 10,
      'isDeleted': false,
    });

    final result = await service.import(
      rows: [
        _row(1, existingId: 'p1', action: DuplicateAction.update),
        _row(2, existingId: 'p2'),
      ],
      userId: 'a',
      userRole: UserRole.admin,
    );

    expect(result.updated, 1);
    expect(result.created, 0);
    expect(result.skipped, 1);

    final p1 = (await firestore.collection('products').doc('p1').get()).data()!;
    expect(p1['price'], 50);
    expect(p1['displayName'], 'Rice 1');
    expect(p1['imageUrl'], 'https://img/x.png');
    expect(p1['description'], 'Keep me');
    expect(p1['isActive'], false);

    final p2 = (await firestore.collection('products').doc('p2').get()).data()!;
    expect(p2['price'], 10);
  });

  test('rows with errors or excluded are never written', () async {
    final bad = _row(1).withValidation(
      issues: const [RowIssue(RowIssueSeverity.error, 'x')],
      price: 50,
      profitMargin: 5,
      stock: 10,
      farmerId: null,
      categoryName: 'Cereals',
      unitSymbol: 'packet',
      newCategory: false,
      newUnit: false,
      existingProductId: null,
      productKey: 'rice 1',
    );
    final excluded = _row(2).copyWith(included: false);
    final result = await service.import(
      rows: [bad, excluded, _row(3)],
      userId: 'a',
      userRole: UserRole.admin,
    );
    expect(result.created, 1);
    expect(result.skipped, 2);
    expect((await firestore.collection('products').get()).docs, hasLength(1));
  });

  test('batches more than one chunk', () async {
    final rows = [for (var i = 1; i <= 850; i++) _row(i)];
    final progress = <int>[];
    final result = await service.import(
      rows: rows,
      userId: 'a',
      userRole: UserRole.superAdmin,
      onProgress: (done, total) => progress.add(done),
    );
    expect(result.created, 850);
    expect(progress.last, 850);
    expect(
      (await firestore.collection('products').get()).docs,
      hasLength(850),
    );
  });

  test('non-admin roles are rejected before any write', () async {
    await expectLater(
      service.import(
        rows: [_row(1)],
        userId: 'c',
        userRole: UserRole.customer,
      ),
      throwsA(anything),
    );
    expect((await firestore.collection('products').get()).docs, isEmpty);
  });

  test('loadExistingProducts ignores deleted products', () async {
    await firestore
        .collection('products')
        .doc('a')
        .set({'name': ' Rice  One ', 'isDeleted': false});
    await firestore
        .collection('products')
        .doc('b')
        .set({'name': 'Gone', 'isDeleted': true});
    final existing = await service.loadExistingProducts();
    expect(existing, {'rice one': 'a'});
  });
}
