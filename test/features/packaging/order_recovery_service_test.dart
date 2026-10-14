import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/packaging/services/order_recovery_service.dart';
import 'package:f2c/features/packaging/services/packing_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(String id, double price, double qty) => OrderItem(
      productId: id,
      productName: id,
      productCategory: 'veg',
      price: price,
      unit: 'kg',
      imageUrl: '',
      quantity: qty,
      farmerId: 'f',
      farmerName: 'F',
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late PackingService packing;
  late OrderRecoveryService recovery;
  late BillService billService;

  Future<OrderModel> seed(String id,
      {String customer = 'c1',
      OrderStatus status = OrderStatus.confirmed,
      String paymentStatus = 'pending'}) async {
    final base = OrderModel(
      id: id,
      customerId: customer,
      customerName: 'Customer',
      customerEmail: 'c@example.com',
      apartmentId: 'a1',
      apartmentName: 'Apt',
      items: [_item('tomato', 40, 5), _item('onion', 30, 3)],
      totalAmount: 0,
      status: status,
      createdAt: DateTime(2026, 10, 1),
      scheduledDate: DateTime(2026, 10, 5),
      deliveryDate: DateTime(2026, 10, 5),
      deliveryCharges: 30,
      paymentMethod: 'cod',
      paymentStatus: paymentStatus,
      confirmedAt: DateTime(2026, 10, 2),
    );
    final order = base.copyWith(totalAmount: base.subtotal);
    await firestore.collection('orders').doc(id).set(order.toFirestore());
    await billService.generateBillFromOrder(
      order: order,
      customerName: 'Customer',
      customerPhone: '1',
      scheduleName: 's',
      generatedBy: 't',
    );
    return order;
  }

  Future<void> packAndFinalize(String id,
      {double tomato = 5, double onion = 3}) async {
    await packing.savePackingSession(
      orderId: id,
      operationId: 'op_$id',
      packedBy: 'p',
      lines: [
        PackingLine(productId: 'tomato', quantity: tomato),
        PackingLine(productId: 'onion', quantity: onion),
      ],
    );
    await packing.finalizeOrder(orderId: id, finalizedBy: 'p');
  }

  Future<Map<String, dynamic>> raw(String path) async =>
      (await firestore.doc(path).get()).data()!;

  Future<OrderModel> read(String id) async => OrderModel.fromFirestore(
      await firestore.collection('orders').doc(id).get());

  Future<BillModel> bill(String id) async =>
      (await billService.getBillByOrderId(id))!;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    packing = PackingService(firestore: firestore);
    recovery = OrderRecoveryService(firestore: firestore);
    billService = BillService(firestore: firestore);
  });

  test('reverts a finalized order with weighed quantities to confirmed',
      () async {
    await seed('o1');
    await packAndFinalize('o1', tomato: 5.4, onion: 3.1);
    expect((await read('o1')).status, OrderStatus.ready);

    final result = await recovery.revertToConfirmed(
      orderId: 'o1',
      operationId: 'r1',
      revertedBy: 'admin',
      reason: 'corrupted',
    );
    expect(result.replayed, isFalse);

    final order = await read('o1');
    expect(order.status, OrderStatus.confirmed);
    expect(order.readyAt, isNull);
    expect(order.preparingAt, isNull);
    expect(order.deliveryId, isNull);
    expect(order.packagingId, isNull);
    expect(order.packingStatus, isNull);
    expect(order.items.map((i) => i.quantity), [5, 3]);
    expect(order.items.map((i) => i.packedQuantity), [0, 0]);
    expect(order.totalAmount, 5 * 40 + 3 * 30);
    expect(order.confirmedAt, DateTime(2026, 10, 2));
    expect(order.customerId, 'c1');
    expect(order.paymentStatus, 'pending');

    final b = await bill('o1');
    expect(b.status, 'draft');
    expect(b.actualTotal, isNull);
    expect(b.actualSubtotal, isNull);
    expect(b.hasVariations, isFalse);
    expect(b.orderedSubtotal, 290);
    expect(b.items.map((i) => i.orderedQuantity), [5, 3]);
    expect(b.items.every((i) => i.actualQuantity == null), isTrue);
  });

  test('reverts a partially packed order and allows packing again', () async {
    await seed('o1');
    await packing.savePackingSession(
      orderId: 'o1',
      operationId: 'op1',
      packedBy: 'p',
      lines: const [PackingLine(productId: 'tomato', quantity: 2)],
    );
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'x');
    var order = await read('o1');
    expect(order.status, OrderStatus.confirmed);
    expect(order.items.first.packedQuantity, 0);

    // Normal workflow works again, including a second finalization.
    await packAndFinalize('o1');
    order = await read('o1');
    expect(order.status, OrderStatus.ready);
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r2', revertedBy: 'a', reason: 'again');
    await packAndFinalize2(packing, 'o1');
    expect((await read('o1')).status, OrderStatus.ready);
    expect((await bill('o1')).status, 'final');
  });

  test('repairs a confirmed order that kept stale downstream state', () async {
    // The corrupted shape: status confirmed, final bill, stale ready fields.
    await seed('o1');
    await packAndFinalize('o1');
    await firestore.collection('orders').doc('o1').update({
      'status': 'confirmed',
      'packingStatus': '',
    });
    expect(
        OrderRecoveryEligibility.hasDownstreamState(await read('o1')), isTrue);

    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'fix');
    final order = await read('o1');
    expect(order.readyAt, isNull);
    expect(order.items.every((i) => i.packedQuantity == 0), isTrue);
    expect((await bill('o1')).status, 'draft');
    expect(OrderRecoveryEligibility.hasDownstreamState(order), isFalse);
  });

  test('reverts an in-transit order, clearing dispatch state', () async {
    await seed('o1');
    await seed('o2');
    await packAndFinalize('o1');
    await packAndFinalize('o2');
    await firestore.collection('orders').doc('o1').update(
        {'status': 'in_transit', 'inTransitAt': Timestamp.now()});
    final other = await raw('orders/o2');

    final result = await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'recalled');
    expect(result.previousStatus, 'in_transit');
    final order = await read('o1');
    expect(order.status, OrderStatus.confirmed);
    expect(order.inTransitAt, isNull);
    expect(order.readyAt, isNull);
    expect(order.deliveryId, isNull);
    expect((await bill('o1')).status, 'draft');
    expect(await raw('orders/o2'), other);
  });

  test('does not touch any other order, bill or customer data', () async {
    await seed('o1');
    await seed('o2');
    await seed('o3', customer: 'c2');
    await packAndFinalize('o1');
    await packAndFinalize('o2');
    await packAndFinalize('o3');

    Future<Map<String, Object?>> snapshot() async {
      final out = <String, Object?>{};
      for (final id in ['o2', 'o3']) {
        out['order/$id'] = (await raw('orders/$id'))..remove('updatedAt');
        final ops = await firestore
            .collection('orders')
            .doc(id)
            .collection('packing_operations')
            .get();
        out['ops/$id'] = {for (final d in ops.docs) d.id: d.data()};
      }
      final bills = await firestore.collection('bills').get();
      out['bills'] = {
        for (final d in bills.docs)
          if (d.data()['orderId'] != 'o1') d.id: d.data(),
      };
      return out;
    }

    final before = await snapshot();
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'x');
    expect(await snapshot(), before);
    expect((await read('o2')).status, OrderStatus.ready);
    expect((await bill('o3')).status, 'final');
  });

  test('preserves payment fields and the packing history, adds an audit',
      () async {
    await seed('o1');
    await packAndFinalize('o1');
    final opsBefore = (await firestore
            .collection('orders')
            .doc('o1')
            .collection('packing_operations')
            .get())
        .docs
        .length;

    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'admin-1', reason: 'why');
    final ops = await firestore
        .collection('orders')
        .doc('o1')
        .collection('packing_operations')
        .get();
    expect(ops.docs.length, opsBefore + 1);
    final audit = ops.docs.firstWhere((d) => d.id == 'revert_r1').data();
    expect(audit['type'], 'revert');
    expect(audit['previousStatus'], 'ready');
    expect(audit['resultingStatus'], 'confirmed');
    expect(audit['revertedBy'], 'admin-1');
    expect(audit['reason'], 'why');
    expect((audit['bills'] as List).single['status'], 'final');
    final order = await raw('orders/o1');
    expect(order['revertReason'], 'why');
    expect(order['paymentMethod'], 'cod');
  });

  test('retries are idempotent and write nothing the second time', () async {
    await seed('o1');
    await packAndFinalize('o1');
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'x');
    final before = await raw('orders/o1');
    final again = await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'x');
    expect(again.replayed, isTrue);
    expect(await raw('orders/o1'), before);
  });

  test('a second revert with a new id on a clean order is harmless', () async {
    await seed('o1');
    await packAndFinalize('o1');
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r1', revertedBy: 'a', reason: 'x');
    await recovery.revertToConfirmed(
        orderId: 'o1', operationId: 'r2', revertedBy: 'a', reason: 'x');
    final order = await read('o1');
    expect(order.status, OrderStatus.confirmed);
    expect(order.totalAmount, 290);
  });

  group('refusals leave data untouched', () {
    Future<void> expectRefused(String id, String code) async {
      final before = await raw('orders/$id');
      await expectLater(
        recovery.revertToConfirmed(
            orderId: id, operationId: 'rx', revertedBy: 'a', reason: 'x'),
        throwsA(isA<PackingException>().having((e) => e.code, 'code', code)),
      );
      expect(await raw('orders/$id'), before);
    }

    test('delivered, pending and cancelled orders', () async {
      await seed('d', status: OrderStatus.delivered);
      await seed('p', status: OrderStatus.pending);
      await seed('c', status: OrderStatus.cancelled);
      await expectRefused('d', 'not_revertable');
      await expectRefused('p', 'not_revertable');
      await expectRefused('c', 'not_revertable');
    });

    test('orders with a recorded payment', () async {
      await seed('p', status: OrderStatus.ready, paymentStatus: 'completed');
      await expectRefused('p', 'not_revertable');
    });

    test('paid bill', () async {
      await seed('b', status: OrderStatus.ready);
      final b = await bill('b');
      await firestore
          .collection('bills')
          .doc(b.billId)
          .update({'paymentStatus': 'completed'});
      await expectRefused('b', 'not_revertable');
    });

    test('missing order and missing reason', () async {
      await expectLater(
        recovery.revertToConfirmed(
            orderId: 'nope', operationId: 'r', revertedBy: 'a', reason: 'x'),
        throwsA(isA<PackingException>()
            .having((e) => e.code, 'code', 'not_found')),
      );
      await seed('o1');
      await expectLater(
        recovery.revertToConfirmed(
            orderId: 'o1', operationId: 'r', revertedBy: 'a', reason: '  '),
        throwsA(isA<PackingException>()
            .having((e) => e.code, 'code', 'reason_required')),
      );
    });
  });

  test('order without a bill reverts cleanly', () async {
    final order = await seed('o1');
    await firestore.collection('bills').get().then((s) async {
      for (final d in s.docs) {
        await d.reference.delete();
      }
    });
    await firestore
        .collection('orders')
        .doc('o1')
        .update({'status': 'ready', 'readyAt': Timestamp.now()});
    final result = await recovery.revertToConfirmed(
        orderId: order.id, operationId: 'r', revertedBy: 'a', reason: 'x');
    expect(result.billsReset, 0);
    expect((await read('o1')).status, OrderStatus.confirmed);
  });
}

Future<void> packAndFinalize2(PackingService packing, String id) async {
  await packing.savePackingSession(
    orderId: id,
    operationId: 'op2_$id',
    packedBy: 'p',
    lines: const [
      PackingLine(productId: 'tomato', quantity: 5),
      PackingLine(productId: 'onion', quantity: 3),
    ],
  );
  await packing.finalizeOrder(orderId: id, finalizedBy: 'p');
}
