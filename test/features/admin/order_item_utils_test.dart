import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/utils/order_item_utils.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ProductModel _product() => ProductModel(
      id: 'p1',
      name: 'GANIKE LEAVES /KASHI LEAVES /MANATHAKKALI',
      displayName: 'MANATHAKKALI LEAVES (Bunch)',
      description: 'Fresh leafy',
      imageUrl: '',
      price: 20,
      unit: 'bunch',
      category: 'Leaves',
      farmerId: 'f1',
      isActive: true,
      isDeleted: false,
      createdAt: DateTime(2026),
      createdBy: 'admin',
    );

void main() {
  test('new item stores displayName, not name or description', () {
    final items = addProductToOrderItems([], _product(), 2);
    expect(items.single.productName, 'MANATHAKKALI LEAVES (Bunch)');
    expect(items.single.productName, isNot(_product().name));
    expect(items.single.productName, isNot(_product().description));
    expect(items.single.productId, 'p1');
  });

  test('adding to an existing order keeps existing items untouched', () {
    const existing = OrderItem(
      productId: 'p0',
      productName: 'Tomato',
      productCategory: 'Veg',
      price: 10,
      unit: 'kg',
      imageUrl: '',
      quantity: 1,
    );
    final items = addProductToOrderItems([existing], _product(), 1);
    expect(items.length, 2);
    expect(items.first, existing);
  });

  test('re-adding a product merges quantity and keeps the display name', () {
    var items = addProductToOrderItems([], _product(), 2);
    items = addProductToOrderItems(items, _product(), 3);
    expect(items.length, 1);
    expect(items.single.quantity, 5);
    expect(items.single.productName, 'MANATHAKKALI LEAVES (Bunch)');
  });

  test('quantity changes do not alter the name; totals are unchanged', () {
    final item = addProductToOrderItems([], _product(), 2).single;
    final more = item.copyWith(quantity: 4);
    final less = item.copyWith(quantity: 1);
    expect(more.productName, item.productName);
    expect(less.productName, item.productName);
    expect(more.totalPrice, 80);
    expect(less.totalPrice, 20);
  });

  test('save and reload through Firestore preserves the display name',
      () async {
    final db = FakeFirebaseFirestore();
    final items = addProductToOrderItems([], _product(), 2);
    await db.collection('orders').doc('o1').set({
      'items': items.map((i) => i.toJson()).toList(),
    });
    final doc = await db.collection('orders').doc('o1').get();
    final loaded = OrderItem.fromJson(
      Map<String, dynamic>.from((doc.data()!['items'] as List).first as Map),
    );
    expect(loaded.productName, 'MANATHAKKALI LEAVES (Bunch)');
    expect(loaded.quantity, 2);
    expect(loaded.price, 20);
  });
}
