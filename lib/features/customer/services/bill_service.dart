import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:intl/intl.dart';

class BillService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a unique bill number
  String _generateBillNumber(DateTime date) {
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
    // Convert order items to bill items
    final billItems = order.items.map((orderItem) {
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

    final billNumber = _generateBillNumber(DateTime.now());

    final bill = BillModel(
      billId: '', // Will be set by Firestore
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
      items: billItems,
      orderedSubtotal: order.subtotal,
      deliveryCharges: order.deliveryCharges,
      cleaningCharges: order.cleaningCharges,
      orderedTotal: order.grandTotal,
      paymentMethod: order.paymentMethod ?? 'cash',
      paymentStatus: order.paymentStatus ?? 'pending',
      billNumber: billNumber,
      generatedAt: DateTime.now(),
      generatedBy: generatedBy,
      hasVariations: false,
      status: 'draft',
    );

    // Save to Firestore
    final docRef = await _firestore.collection('bills').add(bill.toFirestore());
    
    return bill.copyWith(billId: docRef.id);
  }

  /// Update bill with packaging variations
  Future<void> updateBillWithPackagingVariations({
    required String billId,
    required List<BillItemModel> updatedItems,
    required String updatedBy,
    String? packagingNotes,
  }) async {
    // Calculate new totals
    double actualSubtotal = 0.0;
    bool hasVariations = false;

    for (var item in updatedItems) {
      actualSubtotal += item.finalAmount;
      if (item.hasVariation) {
        hasVariations = true;
      }
    }

    // Get original bill to preserve charges
    final billDoc = await _firestore.collection('bills').doc(billId).get();
    final originalBill = BillModel.fromFirestore(billDoc);

    final actualTotal = actualSubtotal + 
                       originalBill.deliveryCharges + 
                       originalBill.cleaningCharges;
    final totalVariation = actualTotal - originalBill.orderedTotal;

    // Update bill
    await _firestore.collection('bills').doc(billId).update({
      'items': updatedItems.map((item) => item.toMap()).toList(),
      'actualSubtotal': actualSubtotal,
      'actualTotal': actualTotal,
      'totalVariation': totalVariation,
      'hasVariations': hasVariations,
      'status': 'final',
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
      'packagingNotes': packagingNotes,
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
}
