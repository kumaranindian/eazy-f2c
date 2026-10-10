import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/customer/services/billing_calculator.dart';

class PackingException implements Exception {
  PackingException(this.code, this.message);

  /// 'invalid_quantity' | 'over_pack' | 'unknown_item' | 'not_packable' |
  /// 'incomplete' | 'bill_finalized' | 'not_found'
  final String code;
  final String message;

  @override
  String toString() => message;
}

class PackingLine {
  const PackingLine({required this.productId, required this.quantity});

  final String productId;

  /// Quantity packed in THIS session only.
  final double quantity;
}

class PackingResult {
  const PackingResult({
    required this.operationId,
    required this.replayed,
    required this.packingStatus,
  });

  final String operationId;

  /// True when [operationId] had already been applied; nothing was written.
  final bool replayed;
  final String? packingStatus;
}

class FinalizeResult {
  const FinalizeResult({
    required this.replayed,
    required this.billUpdated,
    required this.totalAmount,
  });

  final bool replayed;

  /// False when the order has no bill document (bills are created elsewhere).
  final bool billUpdated;
  final double totalAmount;
}

/// Applies packing sessions and finalization to an order atomically.
///
/// Every session is a Firestore transaction that (a) reads the latest order,
/// (b) rejects an already-applied operation id, (c) validates against the
/// persisted remaining quantity and (d) writes the order and an immutable
/// `orders/{id}/packing_operations/{operationId}` audit record together.
///
/// Packing never touches payments. `items[].quantity` stays the ordered
/// quantity until [finalizeOrder], which preserves the pre-existing
/// post-packing semantics (quantity/totalAmount = billed values, status
/// `ready`) that delivery and reporting already depend on.
class PackingService {
  PackingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const finalizeOperationId = 'finalize';
  static const _packableStatuses = {
    OrderStatus.confirmed,
    OrderStatus.preparing,
  };

  CollectionReference<Map<String, dynamic>> _operations(String orderId) =>
      _firestore
          .collection('orders')
          .doc(orderId)
          .collection('packing_operations');

  Future<PackingResult> savePackingSession({
    required String orderId,
    required String operationId,
    required List<PackingLine> lines,
    required String packedBy,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final opRef = _operations(orderId).doc(operationId);

    return _firestore.runTransaction((transaction) async {
      final opSnap = await transaction.get(opRef);
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw PackingException('not_found', 'Order not found.');
      }
      final order = OrderModel.fromFirestore(orderSnap);

      if (opSnap.exists) {
        // Retry of an operation that already committed: report, don't re-apply.
        return PackingResult(
          operationId: operationId,
          replayed: true,
          packingStatus: PackingCalculator.packingStatusOf(order),
        );
      }
      if (!_packableStatuses.contains(order.status)) {
        throw PackingException(
          'not_packable',
          'This order is ${order.status.displayName} and can no longer be packed.',
        );
      }

      final sessionMilli = <String, int>{};
      for (final line in lines) {
        final milli = BillingCalculator.toMilli(line.quantity);
        if (line.quantity.isNaN || line.quantity.isInfinite || milli < 0) {
          throw PackingException(
              'invalid_quantity', 'Quantities must be zero or positive.');
        }
        if (milli == 0) continue;
        sessionMilli[line.productId] =
            (sessionMilli[line.productId] ?? 0) + milli;
      }
      if (sessionMilli.isEmpty) {
        throw PackingException('invalid_quantity',
            'Enter a quantity to pack for at least one item.');
      }

      final opLines = <Map<String, dynamic>>[];
      final updatedItems = <OrderItem>[];
      for (final item in order.items) {
        final add = sessionMilli.remove(item.productId);
        if (add == null) {
          updatedItems.add(item);
          continue;
        }
        final previous = BillingCalculator.toMilli(
            PackingCalculator.packedQuantityOf(order, item));
        final remaining = BillingCalculator.toMilli(item.quantity) - previous;
        if (add > remaining) {
          throw PackingException(
            'over_pack',
            '${item.productName}: only '
                '${BillingCalculator.fromMilli(remaining < 0 ? 0 : remaining)} '
                '${item.unit} remaining, cannot pack '
                '${BillingCalculator.fromMilli(add)}.',
          );
        }
        final resulting = previous + add;
        opLines.add({
          'productId': item.productId,
          'productName': item.productName,
          'unit': item.unit,
          'orderedQuantity': item.quantity,
          'quantity': BillingCalculator.fromMilli(add),
          'previousPackedQuantity': BillingCalculator.fromMilli(previous),
          'resultingPackedQuantity': BillingCalculator.fromMilli(resulting),
        });
        updatedItems.add(
          item.copyWith(packedQuantity: BillingCalculator.fromMilli(resulting)),
        );
      }
      if (sessionMilli.isNotEmpty) {
        throw PackingException('unknown_item',
            'Item ${sessionMilli.keys.first} is not part of this order.');
      }

      final updated = order.copyWith(items: updatedItems);
      final packingStatus = PackingCalculator.packingStatusOf(updated);
      final now = Timestamp.now();
      final orderUpdate = <String, dynamic>{
        'items': updatedItems.map((i) => i.toJson()).toList(),
        'packingStatus': packingStatus,
        'status': 'preparing',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (order.preparingAt == null) orderUpdate['preparingAt'] = now;
      if (order.packagingId == null || order.packagingId!.isEmpty) {
        orderUpdate['packagingId'] =
            'PKG${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
      }

      transaction.update(orderRef, orderUpdate);
      transaction.set(opRef, {
        'operationId': operationId,
        'orderId': orderId,
        'type': 'pack',
        'status': 'applied',
        'lines': opLines,
        'packedBy': packedBy,
        'resultingPackingStatus': packingStatus,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return PackingResult(
        operationId: operationId,
        replayed: false,
        packingStatus: packingStatus,
      );
    });
  }

  /// Moves a fully packed order to `ready` and finalizes its bill, once.
  ///
  /// [shortCloseReason] explicitly accepts the packed quantity as final for
  /// items that cannot be completed; the shortfall is then not billed.
  Future<FinalizeResult> finalizeOrder({
    required String orderId,
    required String finalizedBy,
    String? shortCloseReason,
  }) async {
    final orderRef = _firestore.collection('orders').doc(orderId);
    final opRef = _operations(orderId).doc(finalizeOperationId);

    // Transactions cannot run queries; resolve the bill reference first.
    final billQuery = await _firestore
        .collection('bills')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    final billRef =
        billQuery.docs.isEmpty ? null : billQuery.docs.first.reference;

    return _firestore.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw PackingException('not_found', 'Order not found.');
      }
      final order = OrderModel.fromFirestore(orderSnap);
      final billSnap = billRef == null ? null : await transaction.get(billRef);

      if (PackingCalculator.isFinalized(order)) {
        return FinalizeResult(
          replayed: true,
          billUpdated: billSnap?.exists ?? false,
          totalAmount: order.totalAmount,
        );
      }
      if (!_packableStatuses.contains(order.status)) {
        throw PackingException('not_packable',
            'This order is ${order.status.displayName} and cannot be finalized.');
      }

      final shortfall = order.items.any(
          (item) => PackingCalculator.remainingQuantityOf(order, item) > 0);
      final reason = shortCloseReason?.trim();
      if (shortfall && (reason == null || reason.isEmpty)) {
        throw PackingException(
            'incomplete', 'Some items still have quantity left to pack.');
      }

      // Billable quantity = persisted packed quantity (ordered quantity when
      // fully packed). Price is the order-level snapshot, never the master.
      final billable = <String, double>{
        for (final item in order.items)
          item.productId: PackingCalculator.packedQuantityOf(order, item),
      };
      final finalItems = order.items
          .map((item) => item.copyWith(
                quantity: billable[item.productId]!,
                packedQuantity: billable[item.productId]!,
              ))
          .toList();
      final subtotal =
          BillingCalculator.subtotal(finalItems, (item) => item.quantity);

      var billUpdated = false;
      if (billRef != null && billSnap != null && billSnap.exists) {
        final bill = BillModel.fromFirestore(billSnap);
        if (bill.status == 'final') {
          throw PackingException('bill_finalized',
              'A final bill already exists for this order; reconcile it manually instead of overwriting.');
        }
        final billItems = BillService.finalBillItems(
          order: order,
          billable: billable,
          existing: bill.items,
          variationReason: reason,
        );
        transaction.update(
          billRef,
          BillService.finalBillFields(
            items: billItems,
            deliveryCharges: bill.deliveryCharges,
            cleaningCharges: bill.cleaningCharges,
            orderedTotal: bill.orderedTotal,
            updatedBy: finalizedBy,
            packagingNotes: reason == null
                ? 'Finalized from packaging'
                : 'Closed short: $reason',
          ),
        );
        billUpdated = true;
      }

      final now = Timestamp.now();
      final orderUpdate = <String, dynamic>{
        'status': 'ready',
        'readyAt': now,
        'items': finalItems.map((i) => i.toJson()).toList(),
        'totalAmount': subtotal,
        'packingStatus': 'fully_packed',
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (order.packagingId == null || order.packagingId!.isEmpty) {
        orderUpdate['packagingId'] =
            'PKG${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
      }
      if (order.preparingAt == null) orderUpdate['preparingAt'] = now;
      if (order.deliveryDate == null) orderUpdate['deliveryDate'] = now;
      if (order.deliveryId == null) {
        orderUpdate['deliveryId'] =
            'DLV${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8)}';
      }
      transaction.update(orderRef, orderUpdate);
      transaction.set(opRef, {
        'operationId': finalizeOperationId,
        'orderId': orderId,
        'type': 'finalize',
        'status': 'applied',
        'shortClosed': shortfall,
        'shortCloseReason': reason,
        'finalSubtotal': subtotal,
        'finalizedBy': finalizedBy,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return FinalizeResult(
        replayed: false,
        billUpdated: billUpdated,
        totalAmount: subtotal,
      );
    });
  }
}
