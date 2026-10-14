import 'package:f2c/features/admin/presentation/pages/packaging/admin_packaging_page.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/packaging/services/packing_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(String id, double price, double qty, String unit) => OrderItem(
      productId: id,
      productName: id,
      productCategory: 'veg',
      price: price,
      unit: unit,
      imageUrl: '',
      quantity: qty,
      farmerId: 'farmer-$id',
      farmerName: 'Farmer $id',
    );

/// Regression tests for: "packing one product marked the other products as
/// packed". Root cause was the dialog pre-filling every item's session
/// quantity with its remaining quantity, so Save sent all of them.
void main() {
  late FakeFirebaseFirestore firestore;
  late OrderModel order;
  const orderId = 'order-0001-test';

  Future<OrderModel> readOrder() async => OrderModel.fromFirestore(
      await firestore.collection('orders').doc(orderId).get());

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    order = OrderModel(
      id: orderId,
      customerId: 'c1',
      customerName: 'Customer',
      customerEmail: 'c@example.com',
      apartmentId: 'a1',
      apartmentName: 'Apt',
      items: [
        _item('rice', 50, 10, 'kg'),
        _item('sugar', 40, 5, 'kg'),
        _item('oil', 120, 8, 'L'),
      ],
      totalAmount: 0,
      status: OrderStatus.confirmed,
      createdAt: DateTime(2026, 10, 1),
      scheduledDate: DateTime(2026, 10, 5),
      paymentMethod: 'cod',
      paymentStatus: 'pending',
    );
    order = order.copyWith(totalAmount: order.subtotal);
    await firestore.collection('orders').doc(orderId).set(order.toFirestore());
  });

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          farmersStreamProvider.overrideWith((ref) => Stream.value([])),
          currentUserProvider.overrideWith((ref) async => null),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PackingDialog(
                    order: order,
                    packingService: PackingService(firestore: firestore),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens with nothing pre-filled for any item', (tester) async {
    await openDialog(tester);
    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.length, 3);
    for (final field in fields) {
      expect(field.controller!.text, isEmpty);
    }
    expect(find.text('Packing now: 0 of 3 items'), findsOneWidget);
  });

  testWidgets('packing one product leaves the other products untouched',
      (tester) async {
    await openDialog(tester);

    // The dialog groups items by farmer name (oil, rice, sugar), so rice is
    // the second field on screen.
    await tester.enterText(find.byType(TextField).at(1), '4');
    await tester.pump();
    expect(find.text('Packing now: 1 of 3 items'), findsOneWidget);

    await tester.tap(find.text('Save Partial Packing'));
    await tester.pumpAndSettle();

    final saved = await readOrder();
    expect(saved.items.map((i) => i.packedQuantity), [4, 0, 0]);
    expect(saved.packingStatus, 'partially_packed');
    expect(saved.status, OrderStatus.preparing);

    final ops = await firestore
        .collection('orders')
        .doc(orderId)
        .collection('packing_operations')
        .get();
    expect(ops.docs.length, 1);
    final lines = ops.docs.single.data()['lines'] as List;
    expect(lines.length, 1);
    expect((lines.single as Map)['productId'], 'rice');
  });

  testWidgets('"Pack all remaining" is an explicit opt-in for every item',
      (tester) async {
    await openDialog(tester);
    await tester.tap(find.text('Pack all remaining'));
    await tester.pump();
    expect(find.text('Packing now: 3 of 3 items'), findsOneWidget);

    await tester.tap(find.text('Save & Mark Packed'));
    await tester.pumpAndSettle();

    final saved = await readOrder();
    expect(saved.items.map((i) => i.packedQuantity), [10, 5, 8]);
    expect(saved.status, OrderStatus.ready);
  });

  testWidgets('sync icon closes one item at its packed quantity',
      (tester) async {
    await openDialog(tester);

    // Rice is the second field/row on screen (items grouped by farmer name).
    await tester.enterText(find.byType(TextField).at(1), '9.5');
    await tester.pump();
    await tester.tap(
      find.byTooltip('Adjust to packed quantity (balance not billed)').at(1),
    );
    await tester.pump();
    expect(find.textContaining('will not be billed'), findsOneWidget);

    await tester.tap(find.text('Save Partial Packing'));
    await tester.pumpAndSettle();

    final saved = await readOrder();
    expect(saved.items[0].packedQuantity, 9.5);
    expect(saved.items[0].packingClosed, isTrue);
    // Sugar and oil are untouched and still pending.
    expect(saved.items[1].packedQuantity, 0);
    expect(saved.items[1].packingClosed, isFalse);
    expect(saved.items[2].packedQuantity, 0);
    expect(saved.status, OrderStatus.preparing);
  });
}
