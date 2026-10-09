import 'package:f2c/core/shared/utils/farmer_grouping.dart';
import 'package:f2c/core/widgets/farmer_group_header.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem _item(String name, String? farmerId, String? farmerName,
        {double qty = 1, double price = 10}) =>
    OrderItem(
      productId: name,
      productName: name,
      productCategory: 'c',
      price: price,
      unit: 'kg',
      imageUrl: '',
      quantity: qty,
      farmerId: farmerId,
      farmerName: farmerName,
    );

List<FarmerGroup<OrderItem>> _group(List<OrderItem> items) => groupByFarmer(
      items,
      farmerIdOf: (i) => i.farmerId,
      farmerNameOf: (i) => i.farmerName,
    );

void main() {
  final interleaved = [
    _item('Tomato', 'a', 'Farmer A', qty: 5),
    _item('Banana', 'b', 'Farmer B', qty: 2),
    _item('Onion', 'a', 'Farmer A', qty: 3),
    _item('Coconut', 'c', 'Farmer C', qty: 10),
    _item('Mango', 'b', 'Farmer B', qty: 4),
  ];

  test('interleaved items are grouped, order kept inside each farmer', () {
    final groups = _group(interleaved);
    expect(
        groups.map((g) => g.farmerName), ['Farmer A', 'Farmer B', 'Farmer C']);
    expect(groups[0].items.map((i) => i.productName), ['Tomato', 'Onion']);
    expect(groups[1].items.map((i) => i.productName), ['Banana', 'Mango']);
    expect(groups[2].items.map((i) => i.productName), ['Coconut']);
  });

  test('every item appears exactly once; totals unchanged', () {
    final flat = flattenFarmerGroups(_group(interleaved));
    expect(flat.length, interleaved.length);
    expect(flat.toSet(), interleaved.toSet());
    double total(Iterable<OrderItem> l) =>
        l.fold(0.0, (s, i) => s + i.totalPrice);
    expect(total(flat), total(interleaved));
  });

  test('single farmer gives one group; ordering is deterministic', () {
    final single = [_item('x', 'a', 'A'), _item('y', 'a', 'A')];
    expect(_group(single).length, 1);
    expect(_group(interleaved.reversed.toList()).map((g) => g.farmerId),
        ['a', 'b', 'c']);
  });

  test('grouping uses id, not name; missing farmer goes last', () {
    final groups = _group([
      _item('p', null, null),
      _item('q', 'z', 'Zed'),
      _item('r', 'z', 'Zed (renamed)'),
      _item('s', null, 'Legacy'),
    ]);
    expect(groups.map((g) => g.farmerName),
        ['Legacy', 'Zed', unassignedFarmerLabel]);
    expect(groups[1].items.length, 2);
  });

  testWidgets('widget list has one header per farmer then its items',
      (tester) async {
    final widgets = buildFarmerGroupedWidgets<OrderItem>(
      interleaved,
      farmerIdOf: (i) => i.farmerId,
      farmerNameOf: (i) => i.farmerName,
      itemBuilder: (i, pos) => Text('${pos + 1}:${i.productName}'),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ListView(children: widgets)),
    ));
    expect(find.byType(FarmerGroupHeader), findsNWidgets(3));
    for (final n in [
      '1:Tomato',
      '2:Onion',
      '3:Banana',
      '4:Mango',
      '5:Coconut'
    ]) {
      expect(find.text(n), findsOneWidget);
    }
  });
}
