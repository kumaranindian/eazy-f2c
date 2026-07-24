import 'package:freezed_annotation/freezed_annotation.dart';

part 'cart_item_model.freezed.dart';
part 'cart_item_model.g.dart';

@freezed
class CartItemModel with _$CartItemModel {
  const CartItemModel._();

  const factory CartItemModel({
    required String productId,
    required String productName,
    required String productCategory,
    required double price,
    required String unit,
    required String imageUrl,
    required double quantity,
    String? farmerId,
    String? farmerName,
    String? scheduleId,
    String? scheduleName,
    @Default(false) bool isDiscreteUnit,
    @Default(0.25) double quantityIncrement,
  }) = _CartItemModel;

  factory CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

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
    return discreteUnits.contains(unit.toLowerCase());
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

  // Get display unit for price (e.g., "50g", "kg")
  String get displayUnit {
    return unit;
  }
}
