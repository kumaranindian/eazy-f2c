import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';

/// Adds [product] to [items] for an admin order edit.
///
/// The item's `productName` is the customer-facing display name snapshot
/// (`product.displayName`), the same value the customer checkout stores.
/// If the product is already in the order its quantity is increased instead
/// of appending a duplicate line.
List<OrderItem> addProductToOrderItems(
  List<OrderItem> items,
  ProductModel product,
  double quantity, {
  String? farmerName,
}) {
  final index = items.indexWhere((i) => i.productId == product.id);
  if (index != -1) {
    final updated = [...items];
    updated[index] =
        items[index].copyWith(quantity: items[index].quantity + quantity);
    return updated;
  }
  return [
    ...items,
    OrderItem(
      productId: product.id,
      productName: product.displayName,
      productCategory: product.category,
      price: product.price,
      unit: product.unit,
      imageUrl: product.imageUrl,
      quantity: quantity,
      farmerId: product.farmerId,
      farmerName: farmerName,
    ),
  ];
}
