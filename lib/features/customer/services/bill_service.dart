import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/billing_calculator.dart';
import 'package:intl/intl.dart';

class BillService {
  BillService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Converts persisted order lines into bill lines. Every code path that
  /// builds bill items from an order goes through here.
  static List<BillItemModel> billItemsFromOrder(OrderModel order) {
    return order.items.map((orderItem) {
      return BillItemModel(
        productId: orderItem.productId,
        productName: orderItem.productName,
        farmerId: orderItem.farmerId ?? '',
        farmerName: orderItem.farmerName ?? 'Unknown',
        orderedQuantity: orderItem.quantity,
        orderedUnit: orderItem.unit,
        orderedPrice: orderItem.price,
        orderedAmount: orderItem.totalPrice,
      );
    }).toList();
  }

  /// Fixed bill document id for an order. Checkout and the on-demand repair
  /// both write to this id, so an order can never end up with two bills even
  /// when two writers race.
  static String billDocIdForOrder(String orderId) => 'bill_$orderId';

  /// A draft bill for [order]. Pure: shared by checkout (which writes it in
  /// the same transaction as the order) and by [generateBillFromOrder].
  static BillModel buildDraftBill({
    required OrderModel order,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required String scheduleName,
    required String generatedBy,
    String billId = '',
    DateTime? now,
  }) {
    final generatedAt = now ?? DateTime.now();
    return BillModel(
      billId: billId,
      orderId: order.id,
      customerId: order.customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      orderDate: order.createdAt,
      deliveryDate: order.deliveryDate ?? order.createdAt,
      scheduleId: order.scheduleId ?? '',
      scheduleName: scheduleName,
      items: billItemsFromOrder(order),
      orderedSubtotal: order.subtotal,
      deliveryCharges: order.deliveryCharges,
      cleaningCharges: order.cleaningCharges,
      orderedTotal: order.grandTotal,
      paymentMethod: order.paymentMethod ?? 'cash',
      paymentStatus: order.paymentStatus ?? 'pending',
      billNumber: _billNumberFor(generatedAt),
      generatedAt: generatedAt,
      generatedBy: generatedBy,
      hasVariations: false,
      status: 'draft',
    );
  }

  static String _billNumberFor(DateTime date) {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    final timeStr = DateFormat('HHmmss').format(date);
    return 'BILL-$dateStr-$timeStr';
  }

  /// Generate bill from order
  Future<BillModel> generateBillFromOrder({
    required OrderModel order,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
    String? customerAddress,
    required String scheduleName,
    required String generatedBy,
  }) async {
    final bill = buildDraftBill(
      order: order,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      customerAddress: customerAddress,
      scheduleName: scheduleName,
      generatedBy: generatedBy,
    );

    // Save to Firestore
    final docRef = await _firestore.collection('bills').add(bill.toFirestore());

    return bill.copyWith(billId: docRef.id);
  }

  /// Returns the order's bill, creating it only if none exists (orders whose
  /// checkout-time bill step failed, or that predate billing). An existing
  /// bill is returned untouched, whatever its status.
  ///
  /// A missing bill is rebuilt to match the order's stage: pending through
  /// preparing orders get a draft (packing finalizes it later); ready,
  /// in-transit and delivered orders get a final bill, because their order
  /// lines already hold the billed (packed) quantities. Cancelled orders get
  /// no bill. Customer contact details come from the `customers` record,
  /// falling back to what the order itself holds.
  Future<BillModel?> getOrCreateBillForOrder({
    required OrderModel order,
    required String createdBy,
  }) async {
    final existing = await getBillByOrderId(order.id);
    if (existing != null) return existing;
    if (order.status == OrderStatus.cancelled) return null;

    var phone = '';
    String? email = order.customerEmail;
    try {
      final customerDoc =
          await _firestore.collection('customers').doc(order.customerId).get();
      final data = customerDoc.data();
      if (data != null) {
        phone = (data['phone'] as String?) ?? '';
        final customerEmail = data['email'] as String?;
        if (customerEmail != null && customerEmail.isNotEmpty) {
          email = customerEmail;
        }
      }
    } catch (_) {
      // Contact details are optional on a bill; fall back to the order's.
    }

    final bill = buildDraftBill(
      order: order,
      customerName: order.customerName,
      customerPhone: phone,
      customerEmail: email,
      customerAddress: order.apartmentName,
      scheduleName: order.scheduleName ?? '',
      generatedBy: createdBy,
      billId: billDocIdForOrder(order.id),
    );

    final data = bill.toFirestore();
    const finalStages = {
      OrderStatus.ready,
      OrderStatus.in_transit,
      OrderStatus.delivered,
    };
    if (finalStages.contains(order.status)) {
      final items = finalBillItems(
        order: order,
        billable: {for (final i in order.items) i.productId: i.quantity},
        existing: const [],
      );
      data.addAll(finalBillFields(
        items: items,
        deliveryCharges: order.deliveryCharges,
        cleaningCharges: order.cleaningCharges,
        orderedTotal: order.grandTotal,
        updatedBy: createdBy,
        packagingNotes: 'Bill created from order after the fact',
      ));
    }

    final ref = _firestore.collection('bills').doc(billDocIdForOrder(order.id));
    await _firestore.runTransaction((transaction) async {
      // Another admin (or checkout) may have created it in the meantime.
      if ((await transaction.get(ref)).exists) return;
      transaction.set(ref, data);
    });
    return getBillById(ref.id);
  }

  /// Bill lines for a finalized order. [billable] maps productId to the
  /// approved final quantity. Ordered values are preserved from [existing]
  /// bill lines when present, otherwise taken from the order snapshot.
  static List<BillItemModel> finalBillItems({
    required OrderModel order,
    required Map<String, double> billable,
    required List<BillItemModel> existing,
    String? variationReason,
  }) {
    return order.items.map((orderItem) {
      BillItemModel? prior;
      for (final bi in existing) {
        if (bi.productId == orderItem.productId) prior = bi;
      }
      final orderedQty = prior?.orderedQuantity ?? orderItem.quantity;
      final orderedPrice = prior?.orderedPrice ?? orderItem.price;
      final actualQty = billable[orderItem.productId] ?? orderItem.quantity;
      final variation = actualQty - orderedQty;
      return BillItemModel(
        productId: orderItem.productId,
        productName: orderItem.productName,
        farmerId: orderItem.farmerId ?? '',
        farmerName: orderItem.farmerName ?? 'Unknown',
        orderedQuantity: orderedQty,
        orderedUnit: orderItem.unit,
        orderedPrice: orderedPrice,
        orderedAmount: BillingCalculator.lineAmount(
            unitPrice: orderedPrice, quantity: orderedQty),
        actualQuantity: actualQty,
        actualUnit: orderItem.unit,
        actualPrice: orderItem.price,
        actualAmount: BillingCalculator.lineAmount(
            unitPrice: orderItem.price, quantity: actualQty),
        weightVariation: variation,
        priceVariation: BillingCalculator.lineAmount(
            unitPrice: orderItem.price, quantity: variation),
        variationReason: variation != 0
            ? (variationReason ?? 'Weight variation during packaging')
            : null,
      );
    }).toList();
  }

  /// Firestore fields that turn a bill into its final form. The one place
  /// final totals are computed: actual = sum(lines) + charges.
  static Map<String, dynamic> finalBillFields({
    required List<BillItemModel> items,
    required double deliveryCharges,
    required double cleaningCharges,
    required double orderedTotal,
    required String updatedBy,
    String? packagingNotes,
  }) {
    var subtotalPaise = 0;
    var hasVariations = false;
    for (final item in items) {
      subtotalPaise += BillingCalculator.toPaise(item.finalAmount);
      if (item.hasVariation) hasVariations = true;
    }
    final actualSubtotal = BillingCalculator.toRupees(subtotalPaise);
    final actualTotal = BillingCalculator.total(
      subtotal: actualSubtotal,
      deliveryCharges: deliveryCharges,
      cleaningCharges: cleaningCharges,
    );
    return {
      'items': items.map((item) => item.toMap()).toList(),
      'actualSubtotal': actualSubtotal,
      'actualTotal': actualTotal,
      'totalVariation': BillingCalculator.toRupees(
        BillingCalculator.toPaise(actualTotal) -
            BillingCalculator.toPaise(orderedTotal),
      ),
      'hasVariations': hasVariations,
      'status': 'final',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'packagingNotes': packagingNotes,
    };
  }

  /// Update bill with packaging variations. Refuses to overwrite a bill that
  /// is already final.
  Future<void> updateBillWithPackagingVariations({
    required String billId,
    required List<BillItemModel> updatedItems,
    required String updatedBy,
    String? packagingNotes,
  }) async {
    final billRef = _firestore.collection('bills').doc(billId);
    await _firestore.runTransaction((transaction) async {
      final billDoc = await transaction.get(billRef);
      final originalBill = BillModel.fromFirestore(billDoc);
      if (originalBill.status == 'final') {
        throw StateError('Bill $billId is already final and cannot be overwritten.');
      }
      transaction.update(
        billRef,
        finalBillFields(
          items: updatedItems,
          deliveryCharges: originalBill.deliveryCharges,
          cleaningCharges: originalBill.cleaningCharges,
          orderedTotal: originalBill.orderedTotal,
          updatedBy: updatedBy,
          packagingNotes: packagingNotes,
        ),
      );
    });
  }

  /// Get bill by order ID
  Future<BillModel?> getBillByOrderId(String orderId) async {
    final querySnapshot = await _firestore
        .collection('bills')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    return BillModel.fromFirestore(querySnapshot.docs.first);
  }

  /// Get bill by ID
  Future<BillModel?> getBillById(String billId) async {
    final doc = await _firestore.collection('bills').doc(billId).get();
    
    if (!doc.exists) {
      return null;
    }

    return BillModel.fromFirestore(doc);
  }

  /// Get bills for customer
  Stream<List<BillModel>> getCustomerBills(String customerId) {
    return _firestore
        .collection('bills')
        .where('customerId', isEqualTo: customerId)
        .orderBy('generatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BillModel.fromFirestore(doc))
            .toList());
  }

  /// Update payment status
  Future<void> updatePaymentStatus({
    required String billId,
    required String paymentStatus,
    DateTime? paidAt,
  }) async {
    await _firestore.collection('bills').doc(billId).update({
      'paymentStatus': paymentStatus,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt) : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel bill
  Future<void> cancelBill(String billId, String updatedBy) async {
    await _firestore.collection('bills').doc(billId).update({
      'status': 'cancelled',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    });
  }

  /// Regenerate bill from updated order
  Future<void> regenerateBillFromOrder({
    required String orderId,
    required OrderModel updatedOrder,
    required String updatedBy,
  }) async {
    // Get existing bill
    final existingBill = await getBillByOrderId(orderId);
    
    if (existingBill == null) {
      return; // No bill to update
    }

    final billItems = billItemsFromOrder(updatedOrder);

    // Totals come from OrderModel's getters so the bill can never disagree
    // with the order it was built from.
    final newSubtotal = updatedOrder.subtotal;
    final newTotal = updatedOrder.grandTotal;

    // Update the bill
    await _firestore.collection('bills').doc(existingBill.billId).update({
      'items': billItems.map((item) => item.toMap()).toList(),
      'orderedSubtotal': newSubtotal,
      'deliveryCharges': updatedOrder.deliveryCharges,
      'cleaningCharges': updatedOrder.cleaningCharges,
      'orderedTotal': newTotal,
      'actualSubtotal': newSubtotal, // Reset actual to match ordered
      'actualTotal': newTotal,
      'totalVariation': 0.0,
      'hasVariations': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'generatedAt': FieldValue.serverTimestamp(), // Update generation time
    });
  }

  /// Re-derives a draft bill from the order as currently persisted in
  /// Firestore and returns the up-to-date bill (or null if none exists).
  ///
  /// Only bills with status 'draft' are touched: 'final' bills (set by
  /// packaging) and 'cancelled' bills are immutable snapshots and are
  /// returned unchanged. The order and bill are read inside a transaction,
  /// so if the order changes concurrently the transaction retries and the
  /// bill always ends up matching the latest committed order.
  Future<BillModel?> syncDraftBillWithOrder({
    required String orderId,
    required String updatedBy,
  }) async {
    final billQuery = await _firestore
        .collection('bills')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    if (billQuery.docs.isEmpty) {
      return null;
    }

    final billRef = billQuery.docs.first.reference;
    final orderRef = _firestore.collection('orders').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      final orderSnap = await transaction.get(orderRef);
      final billSnap = await transaction.get(billRef);
      if (!orderSnap.exists || !billSnap.exists) return;

      final bill = BillModel.fromFirestore(billSnap);
      if (bill.status != 'draft') return;

      final order = OrderModel.fromFirestore(orderSnap);
      final items =
          billItemsFromOrder(order).map((item) => item.toMap()).toList();

      final isUpToDate =
          jsonEncode(items) ==
              jsonEncode(bill.items.map((item) => item.toMap()).toList()) &&
          bill.orderedSubtotal == order.subtotal &&
          bill.deliveryCharges == order.deliveryCharges &&
          bill.cleaningCharges == order.cleaningCharges &&
          bill.orderedTotal == order.grandTotal &&
          bill.actualSubtotal == null &&
          bill.actualTotal == null;
      if (isUpToDate) return;

      transaction.update(billRef, {
        'items': items,
        'orderedSubtotal': order.subtotal,
        'deliveryCharges': order.deliveryCharges,
        'cleaningCharges': order.cleaningCharges,
        'orderedTotal': order.grandTotal,
        // A draft has not been packed yet, so there are no actual values.
        'actualSubtotal': null,
        'actualTotal': null,
        'totalVariation': null,
        'hasVariations': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': updatedBy,
      });
    });

    return getBillById(billRef.id);
  }
}
