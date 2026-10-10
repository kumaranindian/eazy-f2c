import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/customer/services/billing_calculator.dart';
import 'package:f2c/features/packaging/services/packing_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
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

void main() {
  late FakeFirebaseFirestore firestore;
  late PackingService packing;
  late BillService billService;
  const orderId = 'order-1';

  Future<OrderModel> readOrder() async => OrderModel.fromFirestore(
      await firestore.collection('orders').doc(orderId).get());

  Future<BillModel> readBill() async =>
      (await billService.getBillByOrderId(orderId))!;

  Future<void> seed(List<OrderItem> items,
      {OrderStatus status = OrderStatus.confirmed,
      bool withBill = true}) async {
    final base = OrderModel(
      id: orderId,
      customerId: 'c1',
      customerName: 'Customer',
      customerEmail: 'c@example.com',
      apartmentId: 'a1',
      apartmentName: 'Apt',
      items: items,
      totalAmount: 0,
      status: status,
      createdAt: DateTime(2026, 10, 1),
      scheduledDate: DateTime(2026, 10, 5),
      deliveryDate: DateTime(2026, 10, 5),
      deliveryCharges: 30,
      cleaningCharges: 10,
      paymentMethod: 'cod',
      paymentStatus: 'pending',
    );
    final order = base.copyWith(totalAmount: base.subtotal);
    await firestore.collection('orders').doc(orderId).set(order.toFirestore());
    if (withBill) {
      await billService.generateBillFromOrder(
        order: order,
        customerName: 'Customer',
        customerPhone: '1',
        scheduleName: 's',
        generatedBy: 'test',
      );
    }
  }

  List<OrderItem> standardItems() => [
        _item('tomato', 40, 5, 'kg'),
        _item('onion', 30, 3, 'kg'),
        _item('spinach', 20, 4, 'bunch'),
      ];

  Future<PackingResult> pack(String op, Map<String, double> q) =>
      packing.savePackingSession(
        orderId: orderId,
        operationId: op,
        packedBy: 'packer',
        lines: q.entries
            .map((e) => PackingLine(productId: e.key, quantity: e.value))
            .toList(),
      );

  setUp(() {
    firestore = FakeFirebaseFirestore();
    packing = PackingService(firestore: firestore);
    billService = BillService(firestore: firestore);
  });

  group('multi-session packing', () {
    test('three sessions accumulate to the ordered total exactly once',
        () async {
      await seed(standardItems());

      await pack('op1', {'tomato': 2, 'onion': 1});
      var order = await readOrder();
      expect(order.status, OrderStatus.preparing);
      expect(order.packingStatus, 'partially_packed');
      expect(order.totalAmount, 370); // untouched by partial saves
      expect((await readBill()).status, 'draft');

      await pack('op2', {'tomato': 3, 'onion': 1, 'spinach': 2});
      order = await readOrder();
      expect(order.status, OrderStatus.preparing);
      expect(order.packingStatus, 'partially_packed');
      expect(order.items.map((i) => i.packedQuantity), [5, 2, 2]);

      final last = await pack('op3', {'onion': 1, 'spinach': 2});
      expect(last.packingStatus, 'fully_packed');
      // Packing alone never finalizes billing or releases to delivery.
      expect((await readOrder()).status, OrderStatus.preparing);

      final result =
          await packing.finalizeOrder(orderId: orderId, finalizedBy: 'packer');
      expect(result.replayed, isFalse);
      expect(result.totalAmount, 370);

      order = await readOrder();
      expect(order.status, OrderStatus.ready);
      expect(order.totalAmount, 370);
      expect(order.items.map((i) => i.quantity), [5, 3, 4]);

      final bill = await readBill();
      expect(bill.status, 'final');
      expect(bill.actualSubtotal, 370);
      expect(bill.actualTotal, 410); // + 30 delivery + 10 cleaning
      expect(bill.totalVariation, 0);
    });

    test('operation history is recorded with previous and resulting qty',
        () async {
      await seed(standardItems());
      await pack('op1', {'tomato': 2});
      await pack('op2', {'tomato': 1});
      final ops = await firestore
          .collection('orders')
          .doc(orderId)
          .collection('packing_operations')
          .get();
      expect(ops.docs.length, 2);
      final second = ops.docs.firstWhere((d) => d.id == 'op2').data();
      final line = (second['lines'] as List).single as Map;
      expect(line['previousPackedQuantity'], 2);
      expect(line['resultingPackedQuantity'], 3);
      expect(line['quantity'], 1);
      expect(second['packedBy'], 'packer');
    });

    test('fractional kg sessions sum without float drift', () async {
      await seed([_item('x', 33.33, 1, 'kg')]);
      for (var i = 0; i < 4; i++) {
        await pack('op$i', {'x': 0.25});
      }
      final order = await readOrder();
      expect(order.items.single.packedQuantity, 1.0);
      expect(PackingCalculator.isFullyPacked(order), isTrue);
    });
  });

  group('validation and atomicity', () {
    test('over-packing is rejected and nothing is partially applied', () async {
      await seed(standardItems());
      await pack('op1', {'tomato': 4});
      await expectLater(
        pack('op2', {'onion': 1, 'tomato': 2}), // tomato only has 1 left
        throwsA(
            isA<PackingException>().having((e) => e.code, 'code', 'over_pack')),
      );
      final order = await readOrder();
      expect(order.items.map((i) => i.packedQuantity), [4, 0, 0]);
      final ops = await firestore
          .collection('orders')
          .doc(orderId)
          .collection('packing_operations')
          .get();
      expect(ops.docs.map((d) => d.id), ['op1']);
    });

    test('negative, empty and unknown-item sessions are rejected', () async {
      await seed(standardItems());
      for (final q in [
        {'tomato': -1.0},
        {'tomato': 0.0},
        {'ghost': 1.0},
      ]) {
        await expectLater(pack('bad', q), throwsA(isA<PackingException>()));
      }
      expect((await readOrder()).status, OrderStatus.confirmed);
    });

    test('cannot pack a finalized or cancelled order', () async {
      await seed(standardItems(), status: OrderStatus.cancelled);
      await expectLater(
        pack('op', {'tomato': 1}),
        throwsA(isA<PackingException>()
            .having((e) => e.code, 'code', 'not_packable')),
      );
    });
  });

  group('idempotency and concurrency', () {
    test('same operation id applied twice changes quantities once', () async {
      await seed(standardItems());
      final first = await pack('same', {'tomato': 2});
      final retry = await pack('same', {'tomato': 2});
      expect(first.replayed, isFalse);
      expect(retry.replayed, isTrue);
      expect((await readOrder()).items.first.packedQuantity, 2);
    });

    // NOTE: fake_cloud_firestore does not implement optimistic-concurrency
    // retry, so truly simultaneous transactions cannot be exercised here. The
    // service reads the order and the operation doc inside one transaction;
    // real Firestore re-runs the loser against the committed state. These
    // tests cover the sequential outcome of that re-run.
    test('a different operation after the remainder is packed is rejected',
        () async {
      await seed([_item('tomato', 40, 5, 'kg')]);
      await pack('a', {'tomato': 5});
      await expectLater(
        pack('b', {'tomato': 5}),
        throwsA(
            isA<PackingException>().having((e) => e.code, 'code', 'over_pack')),
      );
      expect((await readOrder()).items.single.packedQuantity, 5);
    });

    test('finalization is idempotent and never overwrites a final bill',
        () async {
      await seed(standardItems());
      await pack('op', {'tomato': 5, 'onion': 3, 'spinach': 4});
      await packing.finalizeOrder(orderId: orderId, finalizedBy: 'p');
      final billBefore = await readBill();
      final orderBefore = await readOrder();

      final again =
          await packing.finalizeOrder(orderId: orderId, finalizedBy: 'p2');
      expect(again.replayed, isTrue);

      final billAfter = await readBill();
      expect(billAfter.actualTotal, billBefore.actualTotal);
      expect(billAfter.updatedBy, billBefore.updatedBy);
      expect((await readOrder()).totalAmount, orderBefore.totalAmount);
      expect((await firestore.collection('bills').get()).docs.length, 1);
    });

    test(
        'finalizing an order with a final bill but unfinished packing fails closed',
        () async {
      await seed(standardItems());
      final bill = await readBill();
      await billService.updateBillWithPackagingVariations(
        billId: bill.billId,
        updatedItems: bill.items,
        updatedBy: 'legacy',
      );
      await pack('op', {'tomato': 5, 'onion': 3, 'spinach': 4});
      await expectLater(
        packing.finalizeOrder(orderId: orderId, finalizedBy: 'p'),
        throwsA(isA<PackingException>()
            .having((e) => e.code, 'code', 'bill_finalized')),
      );
      expect((await readOrder()).status, OrderStatus.preparing);
    });
  });

  group('finalization and billing', () {
    test('cannot finalize while quantity remains', () async {
      await seed(standardItems());
      await pack('op', {'tomato': 5});
      await expectLater(
        packing.finalizeOrder(orderId: orderId, finalizedBy: 'p'),
        throwsA(isA<PackingException>()
            .having((e) => e.code, 'code', 'incomplete')),
      );
      expect((await readOrder()).status, OrderStatus.preparing);
      expect((await readBill()).status, 'draft');
    });

    test('short close bills only packed quantity and records variance',
        () async {
      await seed(standardItems());
      await pack('op', {'tomato': 5, 'onion': 1});
      await packing.finalizeOrder(
        orderId: orderId,
        finalizedBy: 'p',
        shortCloseReason: 'Spinach out of stock',
      );
      final order = await readOrder();
      expect(order.totalAmount, 5 * 40 + 1 * 30);
      final bill = await readBill();
      expect(bill.actualSubtotal, 230);
      expect(bill.actualTotal, 270);
      expect(bill.totalVariation, 270 - 410);
      expect(bill.hasVariations, isTrue);
      final spinach = bill.items.firstWhere((i) => i.productId == 'spinach');
      expect(spinach.orderedQuantity, 4);
      expect(spinach.actualQuantity, 0);
      expect(spinach.variationReason, 'Spinach out of stock');
    });

    test('packing and finalizing never touch payment state', () async {
      await seed(standardItems());
      await pack('op', {'tomato': 5, 'onion': 3, 'spinach': 4});
      await packing.finalizeOrder(orderId: orderId, finalizedBy: 'p');
      final order = await readOrder();
      expect(order.paymentStatus, 'pending');
      expect(order.paymentMethod, 'cod');
      expect((await readBill()).paymentStatus, 'pending');
      expect((await firestore.collection('transactions').get()).docs, isEmpty);
    });

    test('product master price changes do not alter the order snapshot',
        () async {
      await seed(standardItems());
      await firestore.collection('products').doc('tomato').set({'price': 999});
      await pack('op', {'tomato': 5, 'onion': 3, 'spinach': 4});
      await packing.finalizeOrder(orderId: orderId, finalizedBy: 'p');
      expect((await readBill()).actualSubtotal, 370);
    });

    test('order without a bill still finalizes', () async {
      await seed(standardItems(), withBill: false);
      await pack('op', {'tomato': 5, 'onion': 3, 'spinach': 4});
      final r = await packing.finalizeOrder(orderId: orderId, finalizedBy: 'p');
      expect(r.billUpdated, isFalse);
      expect((await readOrder()).status, OrderStatus.ready);
    });
  });

  group('legacy data', () {
    test('legacy finalized orders read as fully packed', () async {
      await seed(standardItems(), status: OrderStatus.ready);
      final order = await readOrder();
      expect(PackingCalculator.isFullyPacked(order), isTrue);
      expect(PackingCalculator.packedQuantityOf(order, order.items.first), 5);
    });

    test('legacy confirmed orders read as nothing packed', () async {
      await seed(standardItems());
      final order = await readOrder();
      expect(PackingCalculator.packingStatusOf(order), isNull);
      expect(
          PackingCalculator.remainingQuantityOf(order, order.items.first), 5);
    });
  });

  group('BillingCalculator', () {
    test('rounds each line half-up to paise and sums exactly', () {
      expect(
          BillingCalculator.lineAmountPaise(unitPrice: 33.33, quantity: 0.25),
          833); // 8.3325 -> 8.33
      expect(
          BillingCalculator.lineAmountPaise(unitPrice: 0.1, quantity: 3), 30);
      expect(
          BillingCalculator.lineAmount(unitPrice: 19.99, quantity: 3), 59.97);
    });

    test('total = subtotal + delivery + cleaning', () {
      expect(
        BillingCalculator.total(
            subtotal: 370, deliveryCharges: 30, cleaningCharges: 10),
        410,
      );
    });
  });
}
