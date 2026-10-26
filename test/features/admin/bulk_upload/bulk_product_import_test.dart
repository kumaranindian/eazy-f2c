import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/services/bulk_product_normalizer.dart';
import 'package:f2c/features/admin/services/bulk_product_parser.dart';
import 'package:f2c/features/admin/services/bulk_product_validator.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 10, 26);

FarmerModel _farmer(String id, String name) => FarmerModel(
      id: id,
      name: name,
      phone: '1',
      email: 'a@b.c',
      address: 'a',
      location: 'l',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    );

CategoryModel _category(String name) => CategoryModel(
      id: name,
      name: name,
      description: '',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    );

UnitModel _unit(String name) => UnitModel(
      id: name,
      name: name,
      symbol: name.toLowerCase(),
      category: 'grocery',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    );

BulkValidationContext _ctx({
  List<FarmerModel>? farmers,
  List<CategoryModel>? categories,
  List<UnitModel>? units,
  Map<String, String> existing = const {},
  Map<String, String> mapping = const {},
}) =>
    BulkValidationContext(
      farmers: farmers ?? [_farmer('f1', 'Existing Farmer')],
      categories: categories ?? [_category('Cereals')],
      units: units ?? [_unit('Packet')],
      existingProducts: existing,
      farmerMapping: mapping,
    );

BulkParseResult _csv(String body) => BulkProductParser.parse(
      bytes: Uint8List.fromList(utf8.encode(body)),
      fileName: 'x.csv',
    );

const _header =
    'Sl No,PRODUCT NAME,DISPLAY NAME,PRICE,PROFIT MARGIN,STOCK,CATEGORY,UNIT,'
    'FARMER NAME\n';

void main() {
  group('BulkProductNormalizer', () {
    test('fixes known typos and reports them', () {
      final r = BulkProductNormalizer.fixTypos('Traditioanal Rice & Millets');
      expect(r.text, 'Traditional Rice & Millets');
      expect(r.corrected, isTrue);
      expect(BulkProductNormalizer.fixTypos('Sweetner').text, 'Sweetener');
    });

    test('whitespace tidying is not reported as a correction', () {
      final r = BulkProductNormalizer.fixTypos('  Pulses   Mix ');
      expect(r.text, 'Pulses Mix');
      expect(r.corrected, isFalse);
    });
  });

  group('BulkProductParser', () {
    test('rejects unsupported files and missing columns', () {
      expect(
        BulkProductParser.parse(
          bytes: Uint8List(0),
          fileName: 'x.pdf',
        ).hasErrors,
        isTrue,
      );
      final r = _csv('PRODUCT NAME,PRICE\nA,1\n');
      expect(r.errors.single, contains('CATEGORY'));
    });

    test('parses quoted CSV and defaults display name to name', () {
      final r = _csv(
        '$_header'
        '1,"Rice, Red - 1Kg",,50,5,10,Cereals,Packet,Existing Farmer\n',
      );
      expect(r.hasErrors, isFalse);
      expect(r.rows.single.name, 'Rice, Red - 1Kg');
      expect(r.rows.single.displayName, 'Rice, Red - 1Kg');
    });

    test('template parses', () {
      expect(_csv(BulkProductParser.templateCsv).rows, hasLength(1));
    });

    test('reads the real grocery sheet', () {
      final file = File(
        'test/features/admin/bulk_upload/fixtures/groceries.xlsx',
      );
      final r = BulkProductParser.parse(
        bytes: file.readAsBytesSync(),
        fileName: 'groceries.xlsx',
      );
      expect(r.errors, isEmpty);
      expect(r.rows, hasLength(554));
      expect(r.rows.first.name, 'Rajamudi Rice - 1Kg');
      expect(r.rows.first.sheetRow, 2);
      expect(r.rows.any((x) => x.category.contains('Traditioanal')), isFalse);
      expect(
        r.rows.where((x) => x.corrections.isNotEmpty),
        isNotEmpty,
      );
      final cats = r.rows.map((x) => x.category).toSet();
      expect(cats, contains('Traditional Rice & Millets'));
      expect(cats, contains('Sweetener'));
    });
  });

  group('BulkProductValidator', () {
    List<BulkProductRow> validate(String rows, [BulkValidationContext? c]) =>
        BulkProductValidator.validate(_csv('$_header$rows').rows, c ?? _ctx());

    test('valid row is OK and resolves farmer, category and unit', () {
      final r =
          validate('1,Rice,Rice,50,5,10,Cereals,Packet,existing farmer').single;
      expect(r.status, BulkRowStatus.ok);
      expect(r.farmerId, 'f1');
      expect(r.categoryName, 'Cereals');
      expect(r.unitSymbol, 'packet');
      expect(r.price, 50);
      expect(r.willImport, isTrue);
    });

    test('unknown farmer is an error and is not imported', () {
      final r = validate('1,Rice,Rice,50,5,10,Cereals,Packet,Nobody').single;
      expect(r.hasError, isTrue);
      expect(r.farmerId, isNull);
      expect(r.willImport, isFalse);
    });

    test('farmer mapping resolves an unknown sheet name', () {
      final r = validate(
        '1,Rice,Rice,50,5,10,Cereals,Packet,Nobody',
        _ctx(mapping: {'nobody': 'f1'}),
      ).single;
      expect(r.farmerId, 'f1');
      expect(r.hasError, isFalse);
    });

    test('price is rounded with a warning', () {
      final r =
          validate('1,Rice,Rice,107.925,10,30,Cereals,Packet,existing farmer')
              .single;
      expect(r.price, 107.93);
      expect(r.status, BulkRowStatus.warning);
    });

    test('bad numbers are errors', () {
      for (final row in [
        '1,A,A,abc,5,10,Cereals,Packet,existing farmer',
        '1,A,A,0,0,10,Cereals,Packet,existing farmer',
        '1,A,A,50,60,10,Cereals,Packet,existing farmer',
        '1,A,A,50,5,-1,Cereals,Packet,existing farmer',
        '1,A,A,50,5,1.5,Cereals,Packet,existing farmer',
      ]) {
        expect(validate(row).single.hasError, isTrue, reason: row);
      }
    });

    test('new category and unit are flagged as to be created', () {
      final r = validate('1,A,A,50,5,10,Spices,Bag,existing farmer').single;
      expect(r.newCategory, isTrue);
      expect(r.newUnit, isTrue);
      expect(r.hasError, isFalse);
    });

    test('existing product is a duplicate that skips by default', () {
      final r = validate(
        '1,Rice,Rice,50,5,10,Cereals,Packet,existing farmer',
        _ctx(existing: {'rice': 'p1'}),
      ).single;
      expect(r.status, BulkRowStatus.duplicate);
      expect(r.existingProductId, 'p1');
      expect(r.willImport, isFalse);
      expect(
        r.copyWith(duplicateAction: DuplicateAction.update).willImport,
        isTrue,
      );
    });

    test('repeated name in the file is an error on the later row', () {
      final rows = validate(
        '1,Rice,Rice,50,5,10,Cereals,Packet,existing farmer\n'
        '2, rice ,Rice,50,5,10,Cereals,Packet,existing farmer',
      );
      expect(rows[0].hasError, isFalse);
      expect(rows[1].hasError, isTrue);
    });

    test('excluding the first duplicate frees the second', () {
      final parsed = _csv(
        '$_header'
        '1,Rice,Rice,50,5,10,Cereals,Packet,existing farmer\n'
        '2,Rice,Rice,50,5,10,Cereals,Packet,existing farmer',
      ).rows;
      final edited = [parsed[0].copyWith(included: false), parsed[1]];
      final rows = BulkProductValidator.validate(edited, _ctx());
      expect(rows[1].hasError, isFalse);
    });

    test('real sheet: only the unknown farmer blocks rows', () {
      final file = File(
        'test/features/admin/bulk_upload/fixtures/groceries.xlsx',
      );
      final parsed = BulkProductParser.parse(
        bytes: file.readAsBytesSync(),
        fileName: 'groceries.xlsx',
      ).rows;
      const farmerName =
          'Bangalore - Sahaja Samrudha Organic Groceries Producer Company Limited';

      final withoutFarmer = BulkProductValidator.validate(parsed, _ctx());
      expect(withoutFarmer.every((r) => r.hasError), isTrue);

      final withFarmer = BulkProductValidator.validate(
        parsed,
        _ctx(farmers: [_farmer('f1', farmerName)]),
      );
      expect(withFarmer.where((r) => r.hasError), isEmpty);
      expect(withFarmer.every((r) => r.willImport), isTrue);
      expect(withFarmer.every((r) => r.profitMargin == 10), isTrue);
      expect(withFarmer.every((r) => r.stock == 30), isTrue);
      // 9 categories, 8 new + matching ones depend on existing; at least the
      // unit and fixed category names resolve.
      expect(
        withFarmer.map((r) => r.categoryName).toSet(),
        contains('Traditional Rice & Millets'),
      );
    });
  });
}
