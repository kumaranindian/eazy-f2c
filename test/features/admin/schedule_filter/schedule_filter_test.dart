import 'package:f2c/features/admin/presentation/widgets/schedule_name_filter.dart';
import 'package:f2c/features/admin/utils/schedule_filter.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

OrderModel order(String id, {String? schedule, OrderStatus? status}) {
  return OrderModel(
    id: id,
    customerId: 'c',
    customerName: 'Customer $id',
    customerEmail: 'c@x.com',
    apartmentId: 'a',
    apartmentName: 'Apt',
    items: const [],
    totalAmount: 0,
    status: status ?? OrderStatus.confirmed,
    createdAt: DateTime(2026, 10, 1),
    scheduledDate: DateTime(2026, 10, 5),
    scheduleName: schedule,
  );
}

void main() {
  final orders = [
    order('1', schedule: 'Sunday Fresh'),
    order('2', schedule: 'Wednesday Veg'),
    order('3', schedule: ' Sunday Fresh '),
    order('4'),
    order('5', schedule: '   '),
  ];

  group('ScheduleFilter', () {
    test('lists distinct trimmed names, sorted', () {
      expect(ScheduleFilter.namesOf(orders), ['Sunday Fresh', 'Wednesday Veg']);
    });

    test('detects orders without a schedule name', () {
      expect(ScheduleFilter.hasUnscheduled(orders), isTrue);
      expect(ScheduleFilter.hasUnscheduled([orders.first]), isFalse);
    });

    test('null selection keeps everything (same list instance)', () {
      expect(identical(ScheduleFilter.apply(orders, null), orders), isTrue);
    });

    test('filters by name, ignoring surrounding whitespace', () {
      final ids = ScheduleFilter.apply(orders, 'Sunday Fresh').map((o) => o.id);
      expect(ids, ['1', '3']);
    });

    test('no-schedule selection returns blank and missing names', () {
      final ids =
          ScheduleFilter.apply(orders, kNoScheduleFilterValue).map((o) => o.id);
      expect(ids, ['4', '5']);
    });

    test('unknown name returns nothing', () {
      expect(ScheduleFilter.apply(orders, 'Nope'), isEmpty);
    });
  });

  group('ScheduleNameFilter widget', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      required String? selected,
      required ValueChanged<String?> onChanged,
      List<OrderModel>? data,
    }) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                children: [
                  ScheduleNameFilter(
                    orders: data ?? orders,
                    selected: selected,
                    onChanged: onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows all options and reports the pick', (tester) async {
      String? picked = 'unset';
      await pump(
        tester,
        width: 390,
        selected: null,
        onChanged: (v) => picked = v,
      );
      expect(find.text('All Schedules'), findsOneWidget);

      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      expect(find.text('Sunday Fresh'), findsOneWidget);
      expect(find.text('Wednesday Veg'), findsOneWidget);
      expect(find.text('No schedule'), findsOneWidget);

      await tester.tap(find.text('Wednesday Veg'));
      await tester.pumpAndSettle();
      expect(picked, 'Wednesday Veg');
    });

    testWidgets('keeps a selection that is no longer in the data',
        (tester) async {
      await pump(
        tester,
        width: 390,
        selected: 'Gone Schedule',
        data: [order('1', schedule: 'Sunday Fresh')],
        onChanged: (_) {},
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Gone Schedule'), findsOneWidget);
    });

    testWidgets('long names do not overflow on a phone', (tester) async {
      final long = 'A very long schedule name ' * 6;
      await pump(
        tester,
        width: 320,
        selected: long.trim(),
        data: [order('1', schedule: long.trim())],
        onChanged: (_) {},
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButton<String?>));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
