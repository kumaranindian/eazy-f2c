@TestOn('browser')
library;

import 'package:f2c/features/admin/presentation/pages/delivery/admin_delivery_page.dart';
import 'package:f2c/features/admin/presentation/pages/orders/admin_orders_page.dart';
import 'package:f2c/features/admin/presentation/pages/packaging/admin_packaging_page.dart';
import 'package:f2c/features/admin/presentation/widgets/schedule_name_filter.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel _order(String name, String schedule, OrderStatus status) {
  final now = DateTime.now();
  return OrderModel(
    id: 'order00000000000-$name',
    customerId: 'c',
    customerName: name,
    customerEmail: 'c@x.com',
    apartmentId: 'a',
    apartmentName: 'Apt',
    items: const [],
    totalAmount: 10,
    status: status,
    createdAt: now,
    scheduledDate: now,
    deliveryDate: now,
    scheduleName: schedule,
    hubName: 'Hub',
  );
}

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Widget page,
  List<Override> overrides,
) async {
  // The test font is wider than the real one, so unrelated existing widgets
  // (stat cards etc.) report overflows. The filter row itself is checked
  // geometrically in _expectFilterRowFits instead.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hubsStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ...overrides,
      ],
      child: MaterialApp(home: page),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// The schedule dropdown must be fully on screen and the search box must keep
/// a usable width at every layout.
void _expectFilterRowFits(WidgetTester tester, Size size) {
  final filter = tester.getRect(find.byType(ScheduleNameFilter));
  expect(filter.left, greaterThanOrEqualTo(0));
  expect(filter.right, lessThanOrEqualTo(size.width));

  final search = tester.getRect(find.byType(TextField).first);
  expect(search.width, greaterThanOrEqualTo(160));
}

Future<void> _pickSchedule(WidgetTester tester, String name) async {
  final dropdown = find.descendant(
    of: find.byType(ScheduleNameFilter),
    matching: find.byType(DropdownButton<String?>),
  );
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

void main() {
  const sizes = {
    'phone': Size(390, 900),
    'tablet': Size(820, 1180),
    'desktop': Size(1440, 900),
  };

  for (final entry in sizes.entries) {
    group('on ${entry.key}', () {
      testWidgets('orders page filters by schedule name', (tester) async {
        final orders = [
          _order('Alice', 'Sunday Fresh', OrderStatus.pending),
          _order('Bob', 'Wednesday Veg', OrderStatus.pending),
        ];
        await _pump(
          tester,
          entry.value,
          const AdminOrdersPage(),
          [adminOrdersProvider.overrideWith((ref) => Stream.value(orders))],
        );
        expect(find.byType(ScheduleNameFilter), findsOneWidget);
        _expectFilterRowFits(tester, entry.value);
        expect(find.textContaining('Alice'), findsWidgets);
        expect(find.textContaining('Bob'), findsWidgets);

        await _pickSchedule(tester, 'Wednesday Veg');
        expect(find.textContaining('Alice'), findsNothing);
        expect(find.textContaining('Bob'), findsWidgets);

        await _pickSchedule(tester, 'All Schedules');
        expect(find.textContaining('Alice'), findsWidgets);
      });

      testWidgets('packaging page filters by schedule name', (tester) async {
        final orders = [
          _order('Alice', 'Sunday Fresh', OrderStatus.confirmed),
          _order('Bob', 'Wednesday Veg', OrderStatus.confirmed),
        ];
        await _pump(
          tester,
          entry.value,
          const AdminPackagingPage(),
          [
            packagingOrdersProvider.overrideWith((ref) => Stream.value(orders)),
            inProgressPackagingProvider
                .overrideWith((ref) => Stream.value(const [])),
          ],
        );
        if (entry.key == 'phone') {
          // Filters sit behind the toggle on phones.
          await tester.tap(find.byIcon(Icons.tune));
          await tester.pumpAndSettle();
        }
        expect(find.byType(ScheduleNameFilter), findsOneWidget);
        _expectFilterRowFits(tester, entry.value);

        await _pickSchedule(tester, 'Sunday Fresh');
        expect(find.textContaining('Bob'), findsNothing);
        expect(find.textContaining('Alice'), findsWidgets);
      });

      testWidgets('delivery page filters by schedule name', (tester) async {
        final ready = [
          _order('Alice', 'Sunday Fresh', OrderStatus.ready),
          _order('Bob', 'Wednesday Veg', OrderStatus.ready),
        ];
        await _pump(
          tester,
          entry.value,
          const AdminDeliveryPage(),
          [
            readyOrdersProvider.overrideWith((ref) => Stream.value(ready)),
            inTransitOrdersProvider
                .overrideWith((ref) => Stream.value(const [])),
            deliveredOrdersProvider
                .overrideWith((ref) => Stream.value(const [])),
            pendingOrdersProvider.overrideWith((ref) => Stream.value(const [])),
            cancelledOrdersProvider
                .overrideWith((ref) => Stream.value(const [])),
          ],
        );
        expect(find.byType(ScheduleNameFilter), findsOneWidget);
        _expectFilterRowFits(tester, entry.value);

        await _pickSchedule(tester, 'Wednesday Veg');
        expect(find.textContaining('Alice'), findsNothing);
        expect(find.textContaining('Bob'), findsWidgets);
      });
    });
  }
}
