import 'dart:io';

import 'package:f2c/features/admin/models/bulk_product_row.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/presentation/widgets/bulk_upload_dialog.dart';
import 'package:f2c/features/admin/providers/bulk_product_import_provider.dart';
import 'package:f2c/features/admin/services/bulk_product_parser.dart';
import 'package:f2c/features/admin/services/bulk_product_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _farmerName =
    'Bangalore - Sahaja Samrudha Organic Groceries Producer Company Limited';
final _now = DateTime(2026, 10, 26);

class _FakeController extends BulkImportController {
  _FakeController(super.ref, BulkImportState initial) {
    state = initial;
  }
}

BulkImportState _reviewState({required bool withFarmer}) {
  final farmers = [
    FarmerModel(
      id: 'f1',
      name: withFarmer ? _farmerName : 'Other Farmer',
      phone: '1',
      email: 'a@b.c',
      address: 'a',
      location: 'l',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    ),
  ];
  final categories = [
    CategoryModel(
      id: 'c1',
      name: 'Pulses',
      description: '',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    ),
  ];
  final units = [
    UnitModel(
      id: 'u1',
      name: 'Packet',
      symbol: 'packet',
      category: 'grocery',
      isActive: true,
      isDeleted: false,
      createdAt: _now,
      createdBy: 'u',
    ),
  ];
  final parsed = BulkProductParser.parse(
    bytes: File('test/features/admin/bulk_upload/fixtures/groceries.xlsx')
        .readAsBytesSync(),
    fileName: 'groceries.xlsx',
  ).rows;
  final ctx = BulkValidationContext(
    farmers: farmers,
    categories: categories,
    units: units,
    existingProducts: {'rajamudi rice - 1kg': 'p1'},
  );
  return BulkImportState(
    step: BulkImportStep.review,
    fileName: 'groceries.xlsx',
    rows: BulkProductValidator.validate(parsed, ctx),
    farmers: farmers,
    categories: categories,
    units: units,
    existingProducts: ctx.existingProducts,
  );
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  BulkImportState state,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        bulkImportControllerProvider.overrideWith(
          (ref) => _FakeController(ref, state),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: BulkUploadDialog()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  const sizes = {
    'phone': Size(390, 844),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    testWidgets('review step renders without overflow on ${entry.key}',
        (tester) async {
      await _pump(tester, entry.value, _reviewState(withFarmer: true));
      expect(find.text('Bulk Upload Products'), findsOneWidget);
      expect(find.textContaining('Import'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Scroll the list to exercise lazily built rows.
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -1500),
        );
        await tester.pump();
        final error = tester.takeException();
        expect(error, isNull, reason: 'after scroll $i');
      }
    });

    testWidgets('error rows render on ${entry.key}', (tester) async {
      await _pump(tester, entry.value, _reviewState(withFarmer: false));
      expect(find.text('Farmers not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('import stays disabled until approved', (tester) async {
    await _pump(
      tester,
      sizes['desktop']!,
      _reviewState(withFarmer: true),
    );
    final button = find.ancestor(
      of: find.text('Import 553 products'),
      matching: find.bySubtype<ElevatedButton>(),
    );
    expect(button, findsOneWidget);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  });

  testWidgets('upload step renders on phone', (tester) async {
    await _pump(
      tester,
      sizes['phone']!,
      const BulkImportState(),
    );
    expect(find.text('Choose file'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
