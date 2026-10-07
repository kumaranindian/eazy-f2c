import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(String id, double price, double quantity) => OrderItem(
      productId: id,
      productName: 'Product $id',
      productCategory: 'veg',
      price: price,
      unit: 'kg',
      imageUrl: '',
      quantity: quantity,
      farmerId: 'farmer-$id',
      farmerName: 'Farmer $id',
    );

OrderModel _order(List<OrderItem> items) {
  final base = OrderModel(
    id: 'order-1',
    customerId: 'customer-1',
    customerName: 'Customer',
    customerEmail: 'c@example.com',
    apartmentId: 'apt-1',
    apartmentName: 'Apt',
    items: items,
    totalAmount: 0,
    status: OrderStatus.pending,
    createdAt: DateTime(2026, 10, 1),
    scheduledDate: DateTime(2026, 10, 5),
    scheduleId: 'schedule-1',
    deliveryDate: DateTime(2026, 10, 5),
    deliveryCharges: 30,
    cleaningCharges: 10,
    canEdit: true,
  );
  return base.copyWith(totalAmount: base.subtotal);
}

void main() {
  late FakeFirebaseFirestore firestore;
  late BillService billService;
  late DocumentReference<Map<String, dynamic>> orderRef;

  /// Persists an edit the same way checkout does: items + recomputed
  /// totalAmount + updatedAt in a transaction.
  Future<void> persistItems(List<OrderItem> items) {
    return firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(orderRef);
      final current = OrderModel.fromFirestore(snapshot);
      final updated = current.copyWith(items: items);
      transaction.update(orderRef, {
        'items': updated.items.map((i) => i.toJson()).toList(),
        'totalAmount': updated.subtotal,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<OrderModel> readOrder() async =>
      OrderModel.fromFirestore(await orderRef.get());

  Future<BillModel> sync() async => (await billService.syncDraftBillWithOrder(
        orderId: orderRef.id,
        updatedBy: 'customer-1',
      ))!;

  void expectBillMatchesOrder(BillModel bill, OrderModel order) {
    expect(bill.items.length, order.items.length, reason: 'item count');
    for (final item in order.items) {
      final billItem =
          bill.items.singleWhere((b) => b.productId == item.productId);
      expect(billItem.orderedQuantity, item.quantity, reason: item.productId);
      expect(billItem.orderedPrice, item.price);
      expect(billItem.orderedAmount, item.totalPrice);
    }
    expect(bill.finalSubtotal, order.subtotal, reason: 'subtotal');
    expect(bill.deliveryCharges, order.deliveryCharges, reason: 'delivery');
    expect(bill.cleaningCharges, order.cleaningCharges, reason: 'cleaning');
    expect(bill.finalTotal, order.grandTotal, reason: 'grand total');
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    billService = BillService(firestore: firestore);
    orderRef = firestore.collection('orders').doc('order-1');
    await orderRef.set(
      _order([_item('a', 50, 2), _item('b', 20, 1)]).toFirestore(),
    );
    await billService.generateBillFromOrder(
      order: await readOrder(),
      customerName: 'Customer',
      customerPhone: '999',
      scheduleName: 'Schedule',
      generatedBy: 'customer-1',
    );
  });

  test('A: new order produces a matching bill', () async {
    final bill = (await billService.getBillByOrderId(orderRef.id))!;
    expectBillMatchesOrder(bill, await readOrder());
    expect(bill.finalTotal, 120 + 30 + 10);
  });

  test('B: adding a product is reflected in the bill', () async {
    await persistItems([_item('a', 50, 2), _item('b', 20, 1), _item('c', 5, 4)]);
    final bill = await sync();
    expectBillMatchesOrder(bill, await readOrder());
    expect(bill.items.map((i) => i.productId), contains('c'));
  });

  test('C/D: increasing and decreasing quantities are reflected', () async {
    await persistItems([_item('a', 50, 5), _item('b', 20, 1)]);
    var bill = await sync();
    expect(bill.items.firstWhere((i) => i.productId == 'a').orderedQuantity, 5);
    expectBillMatchesOrder(bill, await readOrder());

    await persistItems([_item('a', 50, 0.5), _item('b', 20, 1)]);
    bill = await sync();
    expect(
      bill.items.firstWhere((i) => i.productId == 'a').orderedQuantity,
      0.5,
    );
    expectBillMatchesOrder(bill, await readOrder());
  });

  test('E: removing a product removes it from the bill', () async {
    await persistItems([_item('a', 50, 2)]);
    final bill = await sync();
    expect(bill.items.map((i) => i.productId), isNot(contains('b')));
    expectBillMatchesOrder(bill, await readOrder());
  });

  test('F: sequential add/update/remove ends in the final state', () async {
    await persistItems([_item('a', 50, 2), _item('b', 20, 1), _item('c', 5, 1)]);
    await sync();
    await persistItems([_item('a', 50, 3), _item('b', 20, 1), _item('c', 5, 1)]);
    await sync();
    await persistItems([_item('a', 50, 3), _item('c', 5, 6)]);
    final bill = await sync();
    expectBillMatchesOrder(bill, await readOrder());
    expect(bill.finalTotal, 150 + 30 + 40);
  });

  test('G: rapid concurrent edits converge on the last persisted state',
      () async {
    await Future.wait([
      for (var q = 1; q <= 10; q++)
        persistItems([_item('a', 50, q.toDouble())]).then((_) => sync()),
    ]);
    final bill = (await billService.getBillByOrderId(orderRef.id))!;
    expectBillMatchesOrder(bill, await readOrder());
  });

  test('H: a fresh service instance (app reload) sees the latest bill',
      () async {
    await persistItems([_item('a', 50, 4), _item('d', 12, 2)]);
    await sync();
    final reloaded = BillService(firestore: firestore);
    final bill = (await reloaded.getBillByOrderId(orderRef.id))!;
    expectBillMatchesOrder(bill, await readOrder());
  });

  test('stale draft bill is repaired on view without any further edit',
      () async {
    // Simulates a bill left stale by the old code path: the order changed
    // but the bill was never regenerated.
    await orderRef.update({
      'items': [_item('a', 50, 2), _item('b', 20, 1), _item('e', 7, 3)]
          .map((i) => i.toJson())
          .toList(),
    });
    final bill = await sync();
    expectBillMatchesOrder(bill, await readOrder());
  });

  test('I: the bill handed to the viewer/PDF matches the order exactly',
      () async {
    await persistItems([_item('a', 33.25, 3), _item('b', 20, 7)]);
    final bill = await sync();
    final order = await readOrder();
    expectBillMatchesOrder(bill, order);
    expect(
      bill.items.fold<double>(0, (total, i) => total + i.finalAmount),
      order.subtotal,
    );
  });

  test('J: a finalized bill is never changed by later order edits', () async {
    final draft = (await billService.getBillByOrderId(orderRef.id))!;
    await billService.updateBillWithPackagingVariations(
      billId: draft.billId,
      updatedItems: draft.items,
      updatedBy: 'packer',
    );
    final finalized = (await billService.getBillById(draft.billId))!;
    expect(finalized.status, 'final');

    await persistItems([_item('z', 999, 9)]);
    final afterSync = await sync();

    expect(afterSync.status, 'final');
    expect(afterSync.items.map((i) => i.productId), ['a', 'b']);
    expect(afterSync.finalTotal, finalized.finalTotal);
  });

  test('cancelled bills are not resurrected by sync', () async {
    final draft = (await billService.getBillByOrderId(orderRef.id))!;
    await billService.cancelBill(draft.billId, 'admin');
    await persistItems([_item('a', 50, 9)]);
    final bill = await sync();
    expect(bill.status, 'cancelled');
    expect(bill.items.length, 2);
  });

  test('sync returns null when no bill exists for the order', () async {
    final result = await billService.syncDraftBillWithOrder(
      orderId: 'missing',
      updatedBy: 'x',
    );
    expect(result, isNull);
  });

  test('admin regenerate uses order subtotal + charges for the total',
      () async {
    await persistItems([_item('a', 50, 1)]);
    await billService.regenerateBillFromOrder(
      orderId: orderRef.id,
      updatedOrder: await readOrder(),
      updatedBy: 'admin',
    );
    final bill = (await billService.getBillByOrderId(orderRef.id))!;
    expectBillMatchesOrder(bill, await readOrder());
  });
}
