import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  in_transit,
  delivered,
  cancelled,
}

extension OrderStatusExtension on OrderStatus {
  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.in_transit:
        return 'In Transit';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get statusColor {
    switch (this) {
      case OrderStatus.pending:
        return '#FF9800'; // Orange - Waiting
      case OrderStatus.confirmed:
        return '#2196F3'; // Blue - Accepted
      case OrderStatus.preparing:
        return '#9C27B0'; // Purple - In Progress
      case OrderStatus.ready:
        return '#4CAF50'; // Green - Ready to Pickup
      case OrderStatus.in_transit:
        return '#FF6F00'; // Amber - On the Way
      case OrderStatus.delivered:
        return '#009688'; // Teal - Completed
      case OrderStatus.cancelled:
        return '#F44336'; // Red - Cancelled
    }
  }
}

@freezed
class OrderItem with _$OrderItem {
  const OrderItem._();

  const factory OrderItem({
    required String productId,
    required String productName,
    required String productCategory,
    required double price,
    required String unit,
    required String imageUrl,
    required double quantity,
    String? farmerId,
    String? farmerName,
  }) = _OrderItem;

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);

  double get totalPrice => price * quantity;

  // Parse unit to get base unit and quantity
  // Examples: "50g" -> (50, "g"), "100g" -> (100, "g"), "kg" -> (1, "kg")
  (double baseQuantity, String baseUnit) get _parsedUnit {
    final unitLower = unit.toLowerCase();
    
    // Check for numeric prefix (e.g., 50g, 100g, 250g)
    final numericMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-z]+)$').firstMatch(unitLower);
    if (numericMatch != null) {
      final qty = double.parse(numericMatch.group(1)!);
      final baseUnit = numericMatch.group(2)!;
      return (qty, baseUnit);
    }
    
    // Default case (e.g., "kg", "liter", "piece")
    return (1.0, unitLower);
  }

  // Check if unit is discrete (whole numbers only)
  bool get isDiscreteUnit {
    final discreteUnits = ['box', 'piece', 'bunch', 'packet', 'dozen', 'unit'];
    final unitLower = unit.toLowerCase();
    
    // Check if it's a discrete unit
    if (discreteUnits.contains(unitLower)) return true;
    
    // Check for gram-based units (e.g., 50g, 100g, 250g)
    // These should be treated as discrete (increment by whole units)
    final gramMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*g(?:ram)?s?$').firstMatch(unitLower);
    if (gramMatch != null) return true;
    
    return false;
  }

  // Get minimum quantity increment based on unit type
  double get quantityIncrement {
    if (isDiscreteUnit) {
      return 1.0;
    }
    
    final (baseQuantity, baseUnit) = _parsedUnit;
    
    // For gram-based units, increment by 1.0 (one more unit of the base quantity)
    if (baseUnit == 'g' || baseUnit == 'gram' || baseUnit == 'grams') {
      return 1.0;
    }
    
    // For kg, increment by 0.25 (1/4 kg)
    if (baseUnit == 'kg' || baseUnit == 'kilogram' || baseUnit == 'kilograms') {
      return 0.25;
    }
    
    // For liter, increment by 0.25
    if (baseUnit == 'l' || baseUnit == 'liter' || baseUnit == 'liters') {
      return 0.25;
    }
    
    // Default increment
    return 0.25;
  }

  // Format quantity for display (user-friendly format)
  String get formattedQuantity {
    if (isDiscreteUnit) {
      return quantity.toInt().toString();
    }
    
    final (baseQuantity, baseUnit) = _parsedUnit;
    
    // For gram-based units, show actual grams (e.g., 75g, 150g)
    if (baseUnit == 'g' || baseUnit == 'gram' || baseUnit == 'grams') {
      final actualGrams = (quantity * baseQuantity).toInt();
      return '$actualGrams$baseUnit';
    }
    
    // For kg, show as fractions or whole numbers
    if (baseUnit == 'kg' || baseUnit == 'kilogram' || baseUnit == 'kilograms') {
      if (quantity == 0.25) return '1/4 kg';
      if (quantity == 0.5) return '1/2 kg';
      if (quantity == 0.75) return '3/4 kg';
      if (quantity == quantity.roundToDouble()) {
        return '${quantity.toInt()} kg';
      }
      return '${quantity.toStringAsFixed(2)} kg';
    }
    
    // For liter, show decimals
    if (baseUnit == 'l' || baseUnit == 'liter' || baseUnit == 'liters') {
      return '${quantity.toStringAsFixed(2)} $baseUnit';
    }
    
    // Default
    return quantity.toStringAsFixed(2);
  }
}

@freezed
class OrderModel with _$OrderModel {
  const OrderModel._();

  const factory OrderModel({
    required String id,
    required String customerId,
    required String customerName,
    required String customerEmail,
    required String apartmentId,
    required String apartmentName,
    required List<OrderItem> items,
    required double totalAmount,
    required OrderStatus status,
    required DateTime createdAt,
    required DateTime scheduledDate,
    // Schedule-related fields
    String? scheduleId,
    String? scheduleName,
    DateTime? deliveryDate,
    String? deliveryTimeSlot,
    DateTime? cutoffDateTime,
    String? hubName,
    // Delivery and payment
    String? deliveryAddress,
    String? deliveryInstructions,
    String? paymentMethod,
    String? paymentStatus,
    // Transaction details
    String? transactionId,
    String? transactionReference,
    String? transactionScreenshot,
    DateTime? transactionVerifiedAt,
    String? transactionVerifiedBy,
    // Status timestamps
    DateTime? confirmedAt,
    DateTime? preparingAt,
    DateTime? readyAt,
    DateTime? inTransitAt,
    DateTime? deliveredAt,
    DateTime? cancelledAt,
    String? cancellationReason,
    // Unique IDs for each stage
    String? packagingId,
    String? deliveryId,
    // Charges from schedule
    @Default(0.0) double deliveryCharges,
    @Default(0.0) double cleaningCharges,
    // Flags
    @Default(false) bool isDeleted,
    @Default(false) bool canEdit, // Can edit before cutoff
  }) = _OrderModel;

  factory OrderModel.fromJson(Map<String, dynamic> json) =>
      _$OrderModelFromJson(json);

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Convert Timestamps to ISO strings for fromJson
    final convertedData = Map<String, dynamic>.from(data);
    
    // Helper function to convert Timestamp to ISO string
    String? timestampToIso(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) {
        return value.toDate().toIso8601String();
      }
      return value as String?;
    }
    
    // Convert all timestamp fields
    convertedData['createdAt'] = timestampToIso(data['createdAt']);
    convertedData['scheduledDate'] = timestampToIso(data['scheduledDate']);
    convertedData['deliveryDate'] = timestampToIso(data['deliveryDate']);
    convertedData['cutoffDateTime'] = timestampToIso(data['cutoffDateTime']);
    convertedData['confirmedAt'] = timestampToIso(data['confirmedAt']);
    convertedData['preparingAt'] = timestampToIso(data['preparingAt']);
    convertedData['readyAt'] = timestampToIso(data['readyAt']);
    convertedData['inTransitAt'] = timestampToIso(data['inTransitAt']);
    convertedData['deliveredAt'] = timestampToIso(data['deliveredAt']);
    convertedData['cancelledAt'] = timestampToIso(data['cancelledAt']);
    convertedData['transactionVerifiedAt'] = timestampToIso(data['transactionVerifiedAt']);
    
    return OrderModel.fromJson(convertedData).copyWith(id: doc.id);
  }

  Map<String, dynamic> toFirestore() {
    return toJson()
      ..['status'] = status.name
      ..['createdAt'] = Timestamp.fromDate(createdAt)
      ..['scheduledDate'] = Timestamp.fromDate(scheduledDate)
      ..['deliveryDate'] = deliveryDate != null ? Timestamp.fromDate(deliveryDate!) : null
      ..['cutoffDateTime'] = cutoffDateTime != null ? Timestamp.fromDate(cutoffDateTime!) : null
      ..['confirmedAt'] = confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null
      ..['preparingAt'] = preparingAt != null ? Timestamp.fromDate(preparingAt!) : null
      ..['readyAt'] = readyAt != null ? Timestamp.fromDate(readyAt!) : null
      ..['inTransitAt'] = inTransitAt != null ? Timestamp.fromDate(inTransitAt!) : null
      ..['deliveredAt'] = deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null
      ..['cancelledAt'] = cancelledAt != null ? Timestamp.fromDate(cancelledAt!) : null
      ..['transactionVerifiedAt'] = transactionVerifiedAt != null ? Timestamp.fromDate(transactionVerifiedAt!) : null
      ..['items'] = items.map((item) => item.toJson()).toList();
  }

  // Calculate subtotal (items only)
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  
  // Calculate grand total (subtotal + charges)
  double get grandTotal => subtotal + deliveryCharges + cleaningCharges;
  
  // Check if order can be edited
  // Orders can ONLY be edited if:
  // 1. canEdit flag is true
  // 2. Status is PENDING (not confirmed, preparing, ready, in_transit, delivered, or cancelled)
  // 3. Current time is before cutoff time
  bool get isEditable {
    if (!canEdit) return false;
    // Once order is confirmed or in any other status, editing is disabled
    if (status != OrderStatus.pending) return false;
    if (cutoffDateTime == null) return false;
    return DateTime.now().isBefore(cutoffDateTime!);
  }
}
