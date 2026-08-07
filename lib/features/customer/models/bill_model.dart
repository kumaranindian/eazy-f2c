import 'package:cloud_firestore/cloud_firestore.dart';

class BillItemModel {
  final String productId;
  final String productName;
  final String farmerId;
  final String farmerName;
  final double orderedQuantity;
  final String orderedUnit;
  final double orderedPrice;
  final double orderedAmount;
  
  // Packaging variations
  final double? actualQuantity;
  final String? actualUnit;
  final double? actualPrice;
  final double? actualAmount;
  final double? weightVariation;
  final double? priceVariation;
  final String? variationReason;

  BillItemModel({
    required this.productId,
    required this.productName,
    required this.farmerId,
    required this.farmerName,
    required this.orderedQuantity,
    required this.orderedUnit,
    required this.orderedPrice,
    required this.orderedAmount,
    this.actualQuantity,
    this.actualUnit,
    this.actualPrice,
    this.actualAmount,
    this.weightVariation,
    this.priceVariation,
    this.variationReason,
  });

  double get finalQuantity => actualQuantity ?? orderedQuantity;
  double get finalPrice => actualPrice ?? orderedPrice;
  double get finalAmount => actualAmount ?? orderedAmount;
  bool get hasVariation => actualQuantity != null || actualPrice != null;

  // Format quantity for display
  String _formatQuantity(double quantity, String unit) {
    final unitLower = unit.toLowerCase();
    
    // Parse unit to get base quantity (e.g., "50g" -> 50)
    final numericMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z]+)$').firstMatch(unitLower);
    
    // For gram-based units (e.g., 50g, 100g, 250g)
    if (numericMatch != null) {
      final baseQuantity = double.parse(numericMatch.group(1)!);
      final baseUnit = numericMatch.group(2)!;
      
      if (baseUnit == 'g' || baseUnit == 'gram' || baseUnit == 'grams') {
        final totalGrams = (quantity * baseQuantity).toInt();
        return '${totalGrams}g';
      }
    }
    
    // For kg, show fractions or decimals
    if (unitLower == 'kg' || unitLower.contains('kilogram')) {
      if (quantity == 0.25) return '1/4 kg';
      if (quantity == 0.5) return '1/2 kg';
      if (quantity == 0.75) return '3/4 kg';
      if (quantity == quantity.roundToDouble()) {
        return '${quantity.toInt()} kg';
      }
      return '${quantity.toStringAsFixed(2)} kg';
    }
    
    // For discrete units (piece, box, etc.), show whole numbers
    final discreteUnits = ['box', 'piece', 'bunch', 'packet', 'dozen', 'unit'];
    if (discreteUnits.contains(unitLower)) {
      return '${quantity.toInt()}';
    }
    
    // Default: show quantity with unit
    return '${quantity.toStringAsFixed(2)} $unit';
  }

  String get formattedOrderedQuantity => _formatQuantity(orderedQuantity, orderedUnit);
  String get formattedActualQuantity => actualQuantity != null 
      ? _formatQuantity(actualQuantity!, actualUnit ?? orderedUnit) 
      : '-';

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'farmerId': farmerId,
      'farmerName': farmerName,
      'orderedQuantity': orderedQuantity,
      'orderedUnit': orderedUnit,
      'orderedPrice': orderedPrice,
      'orderedAmount': orderedAmount,
      'actualQuantity': actualQuantity,
      'actualUnit': actualUnit,
      'actualPrice': actualPrice,
      'actualAmount': actualAmount,
      'weightVariation': weightVariation,
      'priceVariation': priceVariation,
      'variationReason': variationReason,
    };
  }

  factory BillItemModel.fromMap(Map<String, dynamic> map) {
    return BillItemModel(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      farmerId: map['farmerId'] ?? '',
      farmerName: map['farmerName'] ?? '',
      orderedQuantity: (map['orderedQuantity'] as num?)?.toDouble() ?? 0.0,
      orderedUnit: map['orderedUnit'] ?? '',
      orderedPrice: (map['orderedPrice'] as num?)?.toDouble() ?? 0.0,
      orderedAmount: (map['orderedAmount'] as num?)?.toDouble() ?? 0.0,
      actualQuantity: (map['actualQuantity'] as num?)?.toDouble(),
      actualUnit: map['actualUnit'],
      actualPrice: (map['actualPrice'] as num?)?.toDouble(),
      actualAmount: (map['actualAmount'] as num?)?.toDouble(),
      weightVariation: (map['weightVariation'] as num?)?.toDouble(),
      priceVariation: (map['priceVariation'] as num?)?.toDouble(),
      variationReason: map['variationReason'],
    );
  }
}

class BillModel {
  final String billId;
  final String orderId;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  
  // Order details
  final DateTime orderDate;
  final DateTime deliveryDate;
  final String scheduleId;
  final String scheduleName;
  
  // Bill items
  final List<BillItemModel> items;
  
  // Financial details - Original
  final double orderedSubtotal;
  final double deliveryCharges;
  final double cleaningCharges;
  final double orderedTotal;
  
  // Financial details - Actual (after packaging)
  final double? actualSubtotal;
  final double? actualTotal;
  final double? totalVariation;
  
  // Payment details
  final String paymentMethod;
  final String paymentStatus;
  final DateTime? paidAt;
  
  // Bill metadata
  final String billNumber;
  final DateTime generatedAt;
  final DateTime? updatedAt;
  final String generatedBy;
  final String? updatedBy;
  final bool hasVariations;
  final String status; // draft, final, cancelled
  
  // Notes
  final String? notes;
  final String? packagingNotes;

  BillModel({
    required this.billId,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    required this.orderDate,
    required this.deliveryDate,
    required this.scheduleId,
    required this.scheduleName,
    required this.items,
    required this.orderedSubtotal,
    required this.deliveryCharges,
    required this.cleaningCharges,
    required this.orderedTotal,
    this.actualSubtotal,
    this.actualTotal,
    this.totalVariation,
    required this.paymentMethod,
    required this.paymentStatus,
    this.paidAt,
    required this.billNumber,
    required this.generatedAt,
    this.updatedAt,
    required this.generatedBy,
    this.updatedBy,
    required this.hasVariations,
    required this.status,
    this.notes,
    this.packagingNotes,
  });

  double get finalSubtotal => actualSubtotal ?? orderedSubtotal;
  double get finalTotal => actualTotal ?? orderedTotal;

  Map<String, dynamic> toFirestore() {
    return {
      'billId': billId,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'orderDate': Timestamp.fromDate(orderDate),
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'scheduleId': scheduleId,
      'scheduleName': scheduleName,
      'items': items.map((item) => item.toMap()).toList(),
      'orderedSubtotal': orderedSubtotal,
      'deliveryCharges': deliveryCharges,
      'cleaningCharges': cleaningCharges,
      'orderedTotal': orderedTotal,
      'actualSubtotal': actualSubtotal,
      'actualTotal': actualTotal,
      'totalVariation': totalVariation,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'billNumber': billNumber,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'generatedBy': generatedBy,
      'updatedBy': updatedBy,
      'hasVariations': hasVariations,
      'status': status,
      'notes': notes,
      'packagingNotes': packagingNotes,
    };
  }

  factory BillModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BillModel(
      billId: doc.id,
      orderId: data['orderId'] ?? '',
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerEmail: data['customerEmail'],
      customerAddress: data['customerAddress'],
      orderDate: (data['orderDate'] as Timestamp).toDate(),
      deliveryDate: (data['deliveryDate'] as Timestamp).toDate(),
      scheduleId: data['scheduleId'] ?? '',
      scheduleName: data['scheduleName'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => BillItemModel.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      orderedSubtotal: (data['orderedSubtotal'] as num?)?.toDouble() ?? 0.0,
      deliveryCharges: (data['deliveryCharges'] as num?)?.toDouble() ?? 0.0,
      cleaningCharges: (data['cleaningCharges'] as num?)?.toDouble() ?? 0.0,
      orderedTotal: (data['orderedTotal'] as num?)?.toDouble() ?? 0.0,
      actualSubtotal: (data['actualSubtotal'] as num?)?.toDouble(),
      actualTotal: (data['actualTotal'] as num?)?.toDouble(),
      totalVariation: (data['totalVariation'] as num?)?.toDouble(),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      paidAt: data['paidAt'] != null ? (data['paidAt'] as Timestamp).toDate() : null,
      billNumber: data['billNumber'] ?? '',
      generatedAt: (data['generatedAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      generatedBy: data['generatedBy'] ?? '',
      updatedBy: data['updatedBy'],
      hasVariations: data['hasVariations'] ?? false,
      status: data['status'] ?? 'draft',
      notes: data['notes'],
      packagingNotes: data['packagingNotes'],
    );
  }

  BillModel copyWith({
    String? billId,
    String? orderId,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    DateTime? orderDate,
    DateTime? deliveryDate,
    String? scheduleId,
    String? scheduleName,
    List<BillItemModel>? items,
    double? orderedSubtotal,
    double? deliveryCharges,
    double? cleaningCharges,
    double? orderedTotal,
    double? actualSubtotal,
    double? actualTotal,
    double? totalVariation,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? paidAt,
    String? billNumber,
    DateTime? generatedAt,
    DateTime? updatedAt,
    String? generatedBy,
    String? updatedBy,
    bool? hasVariations,
    String? status,
    String? notes,
    String? packagingNotes,
  }) {
    return BillModel(
      billId: billId ?? this.billId,
      orderId: orderId ?? this.orderId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      scheduleId: scheduleId ?? this.scheduleId,
      scheduleName: scheduleName ?? this.scheduleName,
      items: items ?? this.items,
      orderedSubtotal: orderedSubtotal ?? this.orderedSubtotal,
      deliveryCharges: deliveryCharges ?? this.deliveryCharges,
      cleaningCharges: cleaningCharges ?? this.cleaningCharges,
      orderedTotal: orderedTotal ?? this.orderedTotal,
      actualSubtotal: actualSubtotal ?? this.actualSubtotal,
      actualTotal: actualTotal ?? this.actualTotal,
      totalVariation: totalVariation ?? this.totalVariation,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paidAt: paidAt ?? this.paidAt,
      billNumber: billNumber ?? this.billNumber,
      generatedAt: generatedAt ?? this.generatedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      generatedBy: generatedBy ?? this.generatedBy,
      updatedBy: updatedBy ?? this.updatedBy,
      hasVariations: hasVariations ?? this.hasVariations,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      packagingNotes: packagingNotes ?? this.packagingNotes,
    );
  }
}
