import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/customer/services/billing_calculator.dart';
import 'package:f2c/features/packaging/services/packing_service.dart';

class RevertResult {
  const RevertResult({
    required this.operationId,
    required this.replayed,
    required this.previousStatus,
    required this.billsReset,
    required this.itemsRestored,
  });

  final String operationId;

  /// True when [operationId] had already been applied; nothing was written.
  final bool replayed;
  final String previousStatus;
  final int billsReset;
  final int itemsRestored;
}

/// Why an order cannot be reverted, or null when it can.
class OrderRecoveryEligibility {
  const OrderRecoveryEligibility._();

  static const _revertableStatuses = {
    OrderStatus.confirmed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.in_transit,
  };

  /// True when the order carries any state produced after confirmation.
  static bool hasDownstreamState(OrderModel order) =>
      order.status != OrderStatus.confirmed ||
      order.preparingAt != null ||
      order.readyAt != null ||
      order.inTransitAt != null ||
      order.deliveredAt != null ||
      (order.packagingId?.isNotEmpty ?? false) ||
      (order.deliveryId?.isNotEmpty ?? false) ||
      (order.packingStatus?.isNotEmpty ?? false) ||
      order.items.any((i) => i.packedQuantity > 0 || i.packingClosed);

  /// Hard stops: the order has left the building or money has been taken, which
  /// a database edit cannot undo.
  static String? blockedReason(OrderModel order) {
    if (!_revertableStatuses.contains(order.status)) {
      return 'An order that is ${order.status.displayName} cannot be '
          'reverted to Confirmed. Only confirmed, preparing, ready or '
          'in-transit orders can be recovered.';
    }
    return _paymentBlock(
      paymentStatus: order.paymentStatus,
      transactionId: order.transactionId,
      verifiedAt: order.transactionVerifiedAt,
    );
  }

  static String? _paymentBlock({
    String? paymentStatus,
    String? transactionId,
    Object? verifiedAt,
  }) {
    if (paymentStatus == 'completed' ||
        (transactionId?.isNotEmpty ?? false) ||
        verifiedAt != null) {
      return 'A payment is recorded for this order. Payments are never '
          'reversed automatically; resolve it manually before reverting.';
    }
    return null;
  }
}

/// Reverts ONE order to `confirmed`, undoing everything the packing and
/// delivery workflow wrote for it.
///
/// Scope is the order document, the bills whose `orderId` is that order, and a
/// new audit document under that order. No other order, product, customer or
/// aggregate is read or written. Payment fields, the order's items/prices and
/// the existing `packing_operations` history are preserved; the revert itself
/// is recorded as an immutable `revert_<operationId>` audit entry holding a
/// snapshot of the previous state.
class OrderRecoveryService {
  OrderRecoveryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<RevertResult> revertToConfirmed({
    required String orderId,
    required String operationId,
    required String revertedBy,
    required String reason,
  }) async {
    final trimmedReason = reason.trim();
    if (orderId.isEmpty) {
      throw PackingException('not_found', 'Order not found.');
    }
    if (trimmedReason.isEmpty) {
      throw PackingException(
          'reason_required', 'Enter a reason for reverting this order.');
    }

    final orderRef = _firestore.collection('orders').doc(orderId);
    final auditId = 'revert_$operationId';
    final auditRef =
        orderRef.collection('packing_operations').doc(auditId);

    // Transactions cannot run queries; resolve this order's bills first and
    // re-validate that list after the commit.
    final billRefs = await _billRefsFor(orderId);

    final result = await runPackingTransaction<RevertResult>(
      _firestore,
      (transaction) async {
        final auditSnap = await transaction.get(auditRef);
        final orderSnap = await transaction.get(orderRef);
        final billSnaps = [
          for (final ref in billRefs) await transaction.get(ref),
        ];

        if (!orderSnap.exists) {
          throw PackingException('not_found', 'Order not found.');
        }
        final order = OrderModel.fromFirestore(orderSnap);

        if (auditSnap.exists) {
          return RevertResult(
            operationId: operationId,
            replayed: true,
            previousStatus: auditSnap.data()?['previousStatus'] as String? ??
                order.status.name,
            billsReset: billSnaps.length,
            itemsRestored: order.items.length,
          );
        }

        final blocked = OrderRecoveryEligibility.blockedReason(order);
        if (blocked != null) {
          throw PackingException('not_revertable', blocked);
        }
        for (final snap in billSnaps.where((s) => s.exists)) {
          final data = snap.data() ?? const <String, dynamic>{};
          final paid = data['paymentStatus'] == 'completed' ||
              data['paidAt'] != null;
          if (paid) {
            throw PackingException(
              'not_revertable',
              'The bill for this order is marked paid. Payments are never '
                  'reversed automatically; resolve it manually before '
                  'reverting.',
            );
          }
        }

        // A final bill keeps the original ordered quantity on every line, so
        // an order that the old flow overwrote with billed quantities gets its
        // ordered quantity back from there. Otherwise the order's own
        // quantity is still the ordered one.
        final orderedFromBill = <String, double>{};
        for (final snap in billSnaps.where((s) => s.exists)) {
          final data = snap.data()!;
          if (data['status'] != 'final') continue;
          for (final line in (data['items'] as List<dynamic>? ?? const [])) {
            final map = line as Map<String, dynamic>;
            final productId = map['productId'] as String?;
            final ordered = (map['orderedQuantity'] as num?)?.toDouble();
            if (productId != null && ordered != null && ordered > 0) {
              orderedFromBill[productId] = ordered;
            }
          }
        }

        final restoredItems = [
          for (final item in order.items)
            item.copyWith(
              quantity: orderedFromBill[item.productId] ?? item.quantity,
              packedQuantity: 0,
              packingClosed: false,
            ),
        ];
        final restoredOrder = order.copyWith(items: restoredItems);
        final subtotal =
            BillingCalculator.subtotal(restoredItems, (i) => i.quantity);
        final orderedTotal = BillingCalculator.total(
          subtotal: subtotal,
          deliveryCharges: order.deliveryCharges,
          cleaningCharges: order.cleaningCharges,
        );

        final billSummaries = <Map<String, dynamic>>[];
        for (final snap in billSnaps.where((s) => s.exists)) {
          final data = snap.data()!;
          billSummaries.add({
            'billId': snap.id,
            'status': data['status'],
            'orderedTotal': data['orderedTotal'],
            'actualSubtotal': data['actualSubtotal'],
            'actualTotal': data['actualTotal'],
            'paymentStatus': data['paymentStatus'],
            'packagingNotes': data['packagingNotes'],
            'lineCount': (data['items'] as List<dynamic>?)?.length ?? 0,
          });
          transaction.update(snap.reference, {
            'items': BillService.billItemsFromOrder(restoredOrder)
                .map((i) => i.toMap())
                .toList(),
            'orderedSubtotal': subtotal,
            'orderedTotal': orderedTotal,
            'actualSubtotal': null,
            'actualTotal': null,
            'totalVariation': null,
            'hasVariations': false,
            'status': 'draft',
            'packagingNotes': null,
            'updatedAt': FieldValue.serverTimestamp(),
            'updatedBy': revertedBy,
          });
        }

        Timestamp? ts(DateTime? v) => v == null ? null : Timestamp.fromDate(v);
        transaction.update(orderRef, {
          'status': 'confirmed',
          'items': restoredItems.map((i) => i.toJson()).toList(),
          'totalAmount': subtotal,
          'packingStatus': null,
          'packagingId': null,
          'deliveryId': null,
          'preparingAt': null,
          'readyAt': null,
          'inTransitAt': null,
          'deliveredAt': null,
          if (order.confirmedAt == null) 'confirmedAt': Timestamp.now(),
          'updatedAt': FieldValue.serverTimestamp(),
          'revertedToConfirmedAt': FieldValue.serverTimestamp(),
          'revertedToConfirmedBy': revertedBy,
          'revertReason': trimmedReason,
        });

        transaction.set(auditRef, {
          'operationId': auditId,
          'orderId': orderId,
          'type': 'revert',
          'status': 'applied',
          'previousStatus': order.status.name,
          'resultingStatus': 'confirmed',
          'revertedBy': revertedBy,
          'reason': trimmedReason,
          'previousState': {
            'totalAmount': order.totalAmount,
            'packingStatus': order.packingStatus,
            'packagingId': order.packagingId,
            'deliveryId': order.deliveryId,
            'preparingAt': ts(order.preparingAt),
            'readyAt': ts(order.readyAt),
            'inTransitAt': ts(order.inTransitAt),
            'deliveredAt': ts(order.deliveredAt),
            'items': [
              for (final item in order.items)
                {
                  'productId': item.productId,
                  'quantity': item.quantity,
                  'packedQuantity': item.packedQuantity,
                  'packingClosed': item.packingClosed,
                },
            ],
          },
          'bills': billSummaries,
          'restoredTotalAmount': subtotal,
          'retained': const [
            'order items, prices and customer details',
            'payment fields',
            'packing_operations history',
            'notifications log',
          ],
          'createdAt': FieldValue.serverTimestamp(),
        });

        return RevertResult(
          operationId: operationId,
          replayed: false,
          previousStatus: order.status.name,
          billsReset: billSummaries.length,
          itemsRestored: restoredItems.length,
        );
      },
    );

    await _verify(orderId, billRefs: billRefs);
    return result;
  }

  Future<List<DocumentReference<Map<String, dynamic>>>> _billRefsFor(
      String orderId) async {
    final snapshot = await _firestore
        .collection('bills')
        .where('orderId', isEqualTo: orderId)
        .get();
    return [for (final doc in snapshot.docs) doc.reference];
  }

  /// Postconditions; a failure here is reported, never swallowed as success.
  Future<void> _verify(
    String orderId, {
    required List<DocumentReference<Map<String, dynamic>>> billRefs,
  }) async {
    final order = OrderModel.fromFirestore(
        await _firestore.collection('orders').doc(orderId).get());
    final problems = <String>[
      if (order.status != OrderStatus.confirmed) 'status is not confirmed',
      if (order.items.any((i) => i.packedQuantity != 0 || i.packingClosed))
        'packed quantities remain',
      if (order.readyAt != null || order.deliveryId != null)
        'delivery fields remain',
    ];
    final current = await _billRefsFor(orderId);
    final known = billRefs.map((r) => r.id).toSet();
    if (current.any((r) => !known.contains(r.id))) {
      problems.add('a bill appeared during recovery and was not reset');
    }
    for (final ref in current) {
      final data = (await ref.get()).data();
      if (data != null && data['status'] == 'final') {
        problems.add('bill ${ref.id} is still final');
      }
    }
    if (problems.isNotEmpty) {
      throw PackingException(
        'verification_failed',
        'Recovery was applied but verification failed: '
            '${problems.join('; ')}. Review this order manually.',
      );
    }
  }
}
