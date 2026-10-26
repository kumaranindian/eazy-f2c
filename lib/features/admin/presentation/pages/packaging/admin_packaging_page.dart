import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/core/widgets/farmer_group_header.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/core/widgets/responsive_data_table.dart';
import 'package:f2c/core/widgets/responsive_stat_cards_row.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/customer/services/billing_calculator.dart';
import 'package:f2c/features/customer/services/pdf_service.dart';
import 'package:f2c/features/packaging/services/packing_service.dart';
import 'package:f2c/features/admin/presentation/widgets/order_details_dialog.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/admin/presentation/widgets/schedule_name_filter.dart';
import 'package:f2c/features/admin/utils/schedule_filter.dart';

// Provider for packaging orders (confirmed and preparing status)
final packagingOrdersProvider =
    StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', whereIn: ['confirmed', 'preparing'])
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .toList();
      });
});

// Provider for ready/packed orders (ready for delivery)
final inProgressPackagingProvider =
    StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'ready')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

class AdminPackagingPage extends ConsumerStatefulWidget {
  const AdminPackagingPage({super.key});

  @override
  ConsumerState<AdminPackagingPage> createState() => _AdminPackagingPageState();
}

class _AdminPackagingPageState extends ConsumerState<AdminPackagingPage> {
  bool _showOrderPicking = true;
  bool _showMobileFilters = false;
  String _searchQuery = '';
  String _selectedHub = 'All Hubs';
  String? _selectedSchedule;
  String _selectedStatus = 'All Statuses';
  String _selectedDateFilter = 'This Week';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _applyDateFilter('This Week');
  }

  void _applyDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _selectedDateFilter = filter;

      switch (filter) {
        case 'This Week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now.add(Duration(days: 7 - now.weekday));
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Quarter':
          final quarter = ((now.month - 1) ~/ 3) + 1;
          final startMonth = (quarter - 1) * 3 + 1;
          _startDate = DateTime(now.year, startMonth, 1);
          _endDate = DateTime(now.year, startMonth + 3, 0);
          break;
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
        case 'Custom':
          // Will be set by date picker
          break;
        default:
          _startDate = null;
          _endDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final newOrdersAsync = ref.watch(packagingOrdersProvider);
    final inProgressAsync = ref.watch(inProgressPackagingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Packaging'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {},
            tooltip: DateFormat('dd MMM yyyy').format(DateTime.now()),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () {},
            tooltip: 'Export',
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {},
            tooltip: 'Print All',
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < _mobileBreakpoint;

          // On mobile the stats/tabs/filters stack would eat the whole
          // viewport, so the entire page scrolls as one list instead.
          if (isMobile) {
            return ListView(
              children: [
                _buildStatsCards(newOrdersAsync, inProgressAsync,
                    isMobile: true),
                _buildTabBar(isMobile: true),
                _buildFiltersRow(isMobile: true),
                if (_showOrderPicking)
                  _buildOrderPickingTable(newOrdersAsync, isMobile: true)
                else
                  _buildFarmerPickingTab(),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCards(newOrdersAsync, inProgressAsync),
              _buildTabBar(),
              _buildFiltersRow(),
              Expanded(
                child: _showOrderPicking
                    ? _buildOrderPickingTable(newOrdersAsync)
                    : _buildFarmerPickingTab(),
              ),
            ],
          );
        },
      ),
    );
  }

  static const double _mobileBreakpoint = 700;

  Widget _buildBreadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Dashboard',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          Text(' / ', style: TextStyle(color: Colors.grey[400])),
          const Text(
            'Packaging',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<List<OrderModel>> newOrders,
    AsyncValue<List<OrderModel>> inProgress, {
    bool isMobile = false,
  }) {
    final totalOrders =
        (newOrders.value?.length ?? 0) + (inProgress.value?.length ?? 0);
    final packedCount =
        inProgress.value?.where((o) => o.status == OrderStatus.ready).length ??
            0;
    final inProgressCount = inProgress.value
            ?.where((o) => o.status == OrderStatus.preparing)
            .length ??
        0;
    final pendingCount = newOrders.value
            ?.where((o) => o.status == OrderStatus.confirmed)
            .length ??
        0;
    final notifiedCount = 1; // Placeholder

    if (isMobile) {
      final chips = [
        ('Total', totalOrders, const Color(0xFF2196F3)),
        ('Packed', packedCount, const Color(0xFF4CAF50)),
        ('In Progress', inProgressCount, const Color(0xFFFF9800)),
        ('Pending', pendingCount, const Color(0xFFFFC107)),
        ('Notified', notifiedCount, const Color(0xFF9C27B0)),
      ];
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final chip in chips)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: chip.$3.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: chip.$3.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${chip.$2}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: chip.$3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        chip.$1,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black87),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: ResponsiveStatCardsRow(
        cards: [
          _buildStatCard(
            'Total Orders',
            totalOrders.toString(),
            Icons.receipt_long_outlined,
            const Color(0xFF2196F3),
          ),
          _buildStatCard(
            'Packed',
            packedCount.toString(),
            Icons.check_circle_outline,
            const Color(0xFF4CAF50),
          ),
          _buildStatCard(
            'In Progress',
            inProgressCount.toString(),
            Icons.inventory_2_outlined,
            const Color(0xFFFF9800),
          ),
          _buildStatCard(
            'Pending',
            pendingCount.toString(),
            Icons.pending_outlined,
            const Color(0xFFFFC107),
          ),
          _buildStatCard(
            'Notified',
            notifiedCount.toString(),
            Icons.notifications_outlined,
            const Color(0xFF9C27B0),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar({bool isMobile = false}) {
    final orderTab = _buildTab(
        'Order Picking', _showOrderPicking, Icons.inventory_2_outlined,
        isMobile: isMobile);
    final farmerTab = _buildTab(
        'Farmer Picking Lists', !_showOrderPicking, Icons.agriculture_outlined,
        isMobile: isMobile);

    return Container(
      padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24, isMobile ? 2 : 16, isMobile ? 16 : 24, isMobile ? 10 : 16),
      color: Colors.white,
      child: isMobile
          ? Row(
              children: [
                Expanded(child: orderTab),
                const SizedBox(width: 8),
                Expanded(child: farmerTab),
              ],
            )
          : Row(
              children: [
                orderTab,
                const SizedBox(width: 16),
                farmerTab,
              ],
            ),
    );
  }

  Widget _buildTab(String label, bool isSelected, IconData icon,
      {bool isMobile = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        setState(() {
          _showOrderPicking = label == 'Order Picking';
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 20, vertical: isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: isMobile ? 13 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersRow({bool isMobile = false}) {
    final searchField = TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search by Order ID or Customer',
        prefixIcon: const Icon(Icons.search, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        filled: true,
        fillColor: Colors.grey[50],
        isDense: true,
      ),
    );

    final filterControls = [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[50],
        ),
        child: Consumer(
          builder: (context, ref, child) {
            final hubsAsync = ref.watch(hubsStreamProvider);
            return hubsAsync.when(
              data: (hubs) {
                final hubNames = [
                  'All Hubs',
                  ...hubs.map((h) => h.name).toList()
                ];
                final validValue =
                    hubNames.contains(_selectedHub) ? _selectedHub : 'All Hubs';
                return DropdownButton<String>(
                  value: validValue,
                  underline: const SizedBox(),
                  isDense: true,
                  style: const TextStyle(fontSize: 13),
                  items: hubNames.map((hub) {
                    return DropdownMenuItem(
                        value: hub,
                        child: Text(hub, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedHub = value!),
                );
              },
              loading: () => DropdownButton<String>(
                value: 'All Hubs',
                underline: const SizedBox(),
                isDense: true,
                style: const TextStyle(fontSize: 13),
                items: const [
                  DropdownMenuItem(
                      value: 'All Hubs',
                      child:
                          Text('Loading...', style: TextStyle(fontSize: 13))),
                ],
                onChanged: null,
              ),
              error: (_, __) => DropdownButton<String>(
                value: 'All Hubs',
                underline: const SizedBox(),
                isDense: true,
                style: const TextStyle(fontSize: 13),
                items: const [
                  DropdownMenuItem(
                      value: 'All Hubs',
                      child: Text('Error', style: TextStyle(fontSize: 13))),
                ],
                onChanged: null,
              ),
            );
          },
        ),
      ),
      Consumer(
        builder: (context, ref, child) {
          final scheduleOrders = <OrderModel>[
            ...(ref.watch(packagingOrdersProvider).valueOrNull ?? const <OrderModel>[]),
            ...(ref.watch(inProgressPackagingProvider).valueOrNull ?? const <OrderModel>[]),
          ];
          return ScheduleNameFilter(
            orders: scheduleOrders,
            selected: _selectedSchedule,
            onChanged: (value) => setState(() {
              _currentPage = 1;
              _selectedSchedule = value;
            }),
          );
        },
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[50],
        ),
        child: DropdownButton<String>(
          value: _selectedStatus,
          underline: const SizedBox(),
          isDense: true,
          style: const TextStyle(fontSize: 13),
          items:
              ['All Statuses', 'Packed', 'Pending', 'Notified'].map((status) {
            return DropdownMenuItem(
                value: status,
                child: Text(status, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: (value) => setState(() => _selectedStatus = value!),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(6),
          color: Colors.grey[50],
        ),
        child: DropdownButton<String>(
          value: _selectedDateFilter,
          underline: const SizedBox(),
          isDense: true,
          style: const TextStyle(fontSize: 13),
          items: [
            'This Week',
            'This Month',
            'This Quarter',
            'This Year',
            'Custom'
          ].map((filter) {
            return DropdownMenuItem(
                value: filter,
                child: Text(filter, style: const TextStyle(fontSize: 13)));
          }).toList(),
          onChanged: (value) {
            if (value == 'Custom') {
              _showDateRangePicker();
            } else {
              _applyDateFilter(value!);
            }
          },
        ),
      ),
      if (_selectedDateFilter == 'Custom' &&
          _startDate != null &&
          _endDate != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF4CAF50)),
            borderRadius: BorderRadius.circular(6),
            color: const Color(0xFF4CAF50).withOpacity(0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range, size: 16, color: Color(0xFF4CAF50)),
              const SizedBox(width: 6),
              Text(
                '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _showDateRangePicker(),
                child:
                    const Icon(Icons.edit, size: 14, color: Color(0xFF4CAF50)),
              ),
            ],
          ),
        ),
    ];

    final filterButton = OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.filter_list, size: 16),
      label: const Text('Filter', style: TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: BorderSide(color: Colors.grey[300]!),
        minimumSize: const Size(60, 32),
      ),
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: _showMobileFilters ? 'Hide filters' : 'Filters',
                  isSelected: _showMobileFilters,
                  icon: const Icon(Icons.tune, size: 20),
                  selectedIcon: const Icon(Icons.close, size: 20),
                  onPressed: () => setState(
                      () => _showMobileFilters = !_showMobileFilters),
                ),
              ],
            ),
            if (_showMobileFilters) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: filterControls),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below this width the dropdowns (hub, schedule, status, date) +
          // search field don't fit on one line without squeezing the search
          // box or overflowing, so stack the search field above a wrapping
          // row of filter controls instead.
          final isNarrow = constraints.maxWidth < 1000;

          if (!isNarrow) {
            return Row(
              children: [
                Expanded(flex: 2, child: searchField),
                const SizedBox(width: 12),
                for (final control in filterControls) ...[
                  control,
                  const SizedBox(width: 12),
                ],
                const Spacer(),
                filterButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [...filterControls, filterButton],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderPickingTable(AsyncValue<List<OrderModel>> ordersAsync,
      {bool isMobile = false}) {
    return ordersAsync.when(
      data: (orders) {
        final filteredOrders = _filterOrders(orders);

        if (filteredOrders.isEmpty) {
          return isMobile
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: _buildEmptyState(),
                )
              : _buildEmptyState();
        }

        final totalPages = (filteredOrders.length / _itemsPerPage).ceil();
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex =
            (startIndex + _itemsPerPage).clamp(0, filteredOrders.length);
        final paginatedOrders = filteredOrders.sublist(startIndex, endIndex);

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final order in paginatedOrders) _buildOrderCard(order),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _buildPaginationControls(
                      filteredOrders.length, totalPages),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: ResponsiveDataTable(
                  minWidth: 1000,
                  header: _buildTableHeader(),
                  body: ListView.builder(
                    itemCount: paginatedOrders.length,
                    itemBuilder: (context, index) {
                      final order = paginatedOrders[index];
                      return _buildTableRow(order, index);
                    },
                  ),
                ),
              ),
              _buildPaginationControls(filteredOrders.length, totalPages),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => const Padding(
        padding: EdgeInsets.all(48),
        child: Center(
          child: Text('Unable to load packing orders. Please try again.'),
        ),
      ),
    );
  }

  /// Mobile replacement for a table row: the same data and the same actions
  /// as [_buildTableRow], stacked into a tappable-friendly card.
  Widget _buildOrderCard(OrderModel order) {
    final pkgId =
        order.packagingId ?? 'PKG${order.id.substring(0, 8).toUpperCase()}';
    final orderId = 'ORD${order.id.substring(0, 8).toUpperCase()}';
    final status = _getOrderStatus(order);
    final scheduleInfo = order.scheduleName ?? order.scheduleId ?? 'N/A';
    final hubInfo = order.hubName ?? 'N/A';
    final deliveryInfo = order.deliveryDate != null
        ? '${DateFormat('dd MMM').format(order.deliveryDate!)}${order.deliveryTimeSlot != null ? ', ${order.deliveryTimeSlot}' : ''}'
        : 'N/A';

    Widget detail(IconData icon, String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: Colors.grey[500]),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
    }

    Color statusColor;
    switch (status) {
      case 'Preparing':
        statusColor = const Color(0xFFFFC107);
        break;
      case 'Packed':
        statusColor = const Color(0xFF4CAF50);
        break;
      default:
        statusColor = const Color(0xFF2196F3);
    }

    final primaryLabel = status == 'Pending'
        ? 'Start'
        : status == 'Preparing'
            ? 'Continue'
            : status == 'Packed'
                ? 'Notify'
                : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            children: [
              Text(pkgId,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9C27B0))),
              Text(orderId,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2196F3))),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(height: 12),
          detail(Icons.event_note_outlined, 'Schedule', scheduleInfo),
          detail(Icons.store_outlined, 'Hub', hubInfo),
          detail(Icons.local_shipping_outlined, 'Delivery', deliveryInfo),
          detail(Icons.shopping_basket_outlined, 'Items',
              '${order.items.length}'),
          const SizedBox(height: 12),
          Row(
            children: [
              if (primaryLabel != null)
                Expanded(
                  child: ElevatedButton(
                    onPressed: status == 'Packed'
                        ? () {}
                        : () => _showPackingDialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: statusColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(60, 40),
                    ),
                    child: Text(primaryLabel),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                onPressed: () => _showOrderDetails(order),
                tooltip: 'View',
              ),
              IconButton.outlined(
                icon: const Icon(Icons.send_outlined, size: 18),
                onPressed: () {},
                tooltip: 'Send',
              ),
              IconButton.outlined(
                icon: const Icon(Icons.print_outlined, size: 18),
                onPressed: () => _printPackingSlip(order),
                tooltip: 'Print',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderCell('Pkg ID', flex: 1),
          _buildHeaderCell('Order ID', flex: 1),
          _buildHeaderCell('Customer', flex: 2),
          _buildHeaderCell('Schedule', flex: 1),
          _buildHeaderCell('HUB', flex: 1),
          _buildHeaderCell('Delivery', flex: 1),
          _buildHeaderCell('Items', flex: 1),
          _buildHeaderCell('Status', flex: 1),
          _buildHeaderCell('Actions', flex: 1),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String title, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildTableRow(OrderModel order, int index) {
    // Use stored packagingId if available, otherwise generate on-the-fly
    final pkgId =
        order.packagingId ?? 'PKG${order.id.substring(0, 8).toUpperCase()}';
    final orderId = 'ORD${order.id.substring(0, 8).toUpperCase()}';
    final status = _getOrderStatus(order);
    final scheduleInfo = order.scheduleName ?? order.scheduleId ?? 'N/A';
    final hubInfo = order.hubName ?? 'N/A';
    final deliveryInfo = order.deliveryDate != null
        ? '${DateFormat('dd MMM').format(order.deliveryDate!)}${order.deliveryTimeSlot != null ? ', ${order.deliveryTimeSlot}' : ''}'
        : 'N/A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          _buildCell(pkgId, flex: 1, color: const Color(0xFF9C27B0)),
          _buildCell(orderId, flex: 1, color: const Color(0xFF2196F3)),
          _buildCell(order.customerName, flex: 2),
          _buildCell(scheduleInfo, flex: 1),
          _buildCell(hubInfo, flex: 1),
          _buildCell(deliveryInfo, flex: 1),
          _buildCell('${order.items.length}', flex: 1),
          _buildStatusCell(status, flex: 1),
          _buildActionsCell(order, flex: 1),
        ],
      ),
    );
  }

  Widget _buildCell(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: color ?? Colors.black87,
          fontWeight: color != null ? FontWeight.w600 : FontWeight.normal,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(String status, {int flex = 1}) {
    Color color;
    Color bgColor;

    switch (status.toLowerCase()) {
      case 'pending':
        color = const Color(0xFF2196F3);
        bgColor = const Color(0xFF2196F3).withOpacity(0.1);
        break;
      case 'preparing':
        color = const Color(0xFFFFC107);
        bgColor = const Color(0xFFFFC107).withOpacity(0.1);
        break;
      case 'packed':
        color = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
        break;
      case 'notified':
        color = const Color(0xFF9C27B0);
        bgColor = const Color(0xFF9C27B0).withOpacity(0.1);
        break;
      default:
        color = Colors.grey;
        bgColor = Colors.grey.withOpacity(0.1);
    }

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          status,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActionsCell(OrderModel order, {int flex = 1}) {
    final status = _getOrderStatus(order);

    return Expanded(
      flex: flex,
      child: Row(
        children: [
          if (status == 'Pending')
            ElevatedButton(
              onPressed: () => _showPackingDialog(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('Start', style: TextStyle(fontSize: 12)),
            )
          else if (status == 'Preparing')
            ElevatedButton(
              onPressed: () => _showPackingDialog(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 12)),
            )
          else if (status == 'Packed')
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('Notify', style: TextStyle(fontSize: 12)),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18),
            onPressed: () => _showOrderDetails(order),
            tooltip: 'View',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_outlined, size: 18),
            onPressed: () {},
            tooltip: 'Send',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 18),
            onPressed: () => _printPackingSlip(order),
            tooltip: 'Print',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  String _getOrderStatus(OrderModel order) {
    if (order.status == OrderStatus.confirmed) {
      return 'Pending';
    } else if (order.status == OrderStatus.preparing) {
      return 'Preparing';
    } else if (order.status == OrderStatus.ready) {
      return 'Packed';
    }
    return 'Pending';
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      // Wrap instead of Row: identical when there's room for both pieces on
      // one line, but drops to a second line on very narrow screens instead
      // of overflowing.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage * _itemsPerPage).clamp(0, totalItems)} of $totalItems',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (totalPages > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 20),
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
        ],
      ),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var filtered = orders;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        return order.customerName.toLowerCase().contains(query) ||
            order.id.toLowerCase().contains(query);
      }).toList();
    }

    // Apply hub filter
    if (_selectedHub != 'All Hubs') {
      filtered = filtered.where((order) {
        return order.hubName == _selectedHub;
      }).toList();
    }

    // Apply schedule name filter
    filtered = ScheduleFilter.apply(filtered, _selectedSchedule);

    // Apply status filter
    if (_selectedStatus != 'All Statuses') {
      filtered = filtered.where((order) {
        final status = _getOrderStatus(order);
        return status == _selectedStatus;
      }).toList();
    }

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      filtered = filtered.where((order) {
        final orderDate = order.deliveryDate ?? order.createdAt;
        final dateOnly = DateTime(
          orderDate.year,
          orderDate.month,
          orderDate.day,
        );
        final start =
            DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(
            _endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
        return dateOnly.isAfter(start.subtract(const Duration(days: 1))) &&
            dateOnly.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    }

    return filtered;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No orders to pack',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerPickingTab() {
    return const Center(
      child: Text('Farmer Picking Lists - Coming Soon'),
    );
  }

  Future<void> _showPackingDialog(OrderModel order) async {
    // Just show the dialog - status will be updated when user saves
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => PackingDialog(order: order),
      );
    }
  }

  void _showPackingSlip(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => PackingSlipDialog(order: order),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  /// Opens the order's bill in a new tab for browser print / save as PDF.
  Future<void> _printPackingSlip(OrderModel order) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bill = await BillService().getOrCreateBillForOrder(
        order: order,
        createdBy: ref.read(currentUserProvider).valueOrNull?.id ?? 'admin',
      );
      if (bill == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No bill found for this order yet.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await PdfService().downloadBillPdf(bill);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
              'Bill opened in new tab. Use browser print (Ctrl+P) to print or save as PDF.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to open bill for printing', e);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to open the bill. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _selectedDateFilter = 'Custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

// Packing Dialog (simplified - reuse from old file)
class PackingDialog extends ConsumerStatefulWidget {
  final OrderModel order;

  /// Override for tests; defaults to the Firestore-backed service.
  final PackingService? packingService;

  const PackingDialog({super.key, required this.order, this.packingService});

  @override
  ConsumerState<PackingDialog> createState() => _PackingDialogState();
}

class _PackingDialogState extends ConsumerState<PackingDialog> {
  /// Quantity entered for THIS packing session only, per productId.
  final Map<String, double> _packNow = {};
  final Map<String, TextEditingController> _controllers = {};

  /// Items the packer chose to close at their packed quantity this session
  /// (e.g. 7.92 of 8 kg): the balance is neither pending nor billed.
  final Set<String> _closeNow = {};
  late final PackingService _packingService =
      widget.packingService ?? PackingService();
  bool _isProcessing = false;
  Map<String, String> _farmerNamesById = {};

  // One id per logical submission; kept across retries of the same payload so
  // a timed-out request that did commit is recognised and not re-applied.
  String _operationId = _newOperationId();
  String? _lastAttemptSignature;

  static String _newOperationId() {
    final random = math.Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return 'op_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  double _remainingOf(OrderItem item) =>
      PackingCalculator.remainingQuantityOf(widget.order, item);

  double _packedOf(OrderItem item) =>
      PackingCalculator.packedQuantityOf(widget.order, item);

  @override
  void initState() {
    super.initState();
    // Nothing is pre-filled: an item is only packed when the packer enters a
    // quantity (or taps "Pack remaining") for it. Pre-filling the remaining
    // quantity made untouched items get packed along with the edited one.
    for (final item in widget.order.items) {
      _packNow[item.productId] = 0;
      _controllers[item.productId] = TextEditingController();
    }
  }

  void _setPackNow(OrderItem item, double value) {
    final next = value.isNaN || value < 0 ? 0.0 : value;
    setState(() {
      _packNow[item.productId] = next;
      _controllers[item.productId]?.text =
          next == 0 ? '' : _formatQuantity(next);
    });
  }

  /// Quantity that will be packed in total for [item] if this session saves.
  double _packedAfterSession(OrderItem item) => BillingCalculator.fromMilli(
        BillingCalculator.toMilli(_packedOf(item)) +
            BillingCalculator.toMilli(_packNow[item.productId] ?? 0),
      );

  void _toggleClose(OrderItem item) {
    setState(() {
      if (!_closeNow.remove(item.productId)) _closeNow.add(item.productId);
    });
  }

  void _packAllRemaining() {
    for (final item in widget.order.items) {
      final remaining = _remainingOf(item);
      if (remaining > 0) _setPackNow(item, remaining);
    }
  }

  static String _formatQuantity(double value) {
    final text = value.toStringAsFixed(3);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  int get _itemsPackingNow => widget.order.items
      .where((i) => BillingCalculator.toMilli(_packNow[i.productId] ?? 0) > 0)
      .length;

  /// Null when valid, otherwise a message for the item's field.
  String? _validationError(OrderItem item) {
    final value = _packNow[item.productId] ?? 0;
    if (value.isNaN || value < 0) return 'Must be 0 or more';
    if (_closeNow.contains(item.productId) && _packedAfterSession(item) <= 0) {
      return 'Enter packed qty to adjust';
    }
    return null;
  }

  bool get _hasInvalidEntry =>
      widget.order.items.any((item) => _validationError(item) != null);

  bool get _hasEntries =>
      widget.order.items.any((i) => (_packNow[i.productId] ?? 0) > 0);

  /// True when, after this session, nothing remains to pack.
  bool get _completesOrder => widget.order.items.every((item) {
        if (_closeNow.contains(item.productId)) return true;
        final after = BillingCalculator.toMilli(_remainingOf(item)) -
            BillingCalculator.toMilli(_packNow[item.productId] ?? 0);
        return after <= 0;
      });

  String? _resolveFarmerName(OrderItem item) {
    if (item.farmerName != null && item.farmerName!.isNotEmpty) {
      return item.farmerName;
    }
    if (item.farmerId != null) {
      return _farmerNamesById[item.farmerId];
    }
    return null;
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(farmersStreamProvider).whenData((farmers) {
      _farmerNamesById = {
        for (final farmer in farmers) farmer.id: farmer.effectiveName,
      };
    });
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final pad = isMobile ? 16.0 : 24.0;

    final submitDisabled = _isProcessing ||
        _hasInvalidEntry ||
        (!_hasEntries &&
            _closeNow.isEmpty &&
            !PackingCalculator.isFullyPacked(widget.order));
    final submitButton = ElevatedButton.icon(
      onPressed: submitDisabled ? null : _submit,
      icon: _isProcessing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save),
      label: Text(
        _completesOrder ? 'Save & Mark Packed' : 'Save Partial Packing',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
      ),
    );
    final cancelButton = OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
      child: const Text('Cancel'),
    );

    Widget infoChip(IconData icon, String text) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: Colors.grey[800]),
            ),
          ),
        ],
      );
    }

    // Header and footer stay pinned; everything between them scrolls, so the
    // action buttons are always reachable however many items the order has.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(pad, isMobile ? 8 : 16, 8, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
          ),
          child: Row(
            children: [
              const Icon(Icons.inventory_2, color: Color(0xFF9C27B0)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pack Order #${widget.order.id.substring(0, 8)}',
                  style: TextStyle(
                    fontSize: isMobile ? 17 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Tooltip(
                message:
                    'Enter the quantity packed in this session only for the items you are packing now; items left empty are not changed. Earlier sessions are kept; the order is billed and sent to delivery only once everything is packed.',
                triggerMode: TooltipTriggerMode.tap,
                showDuration: const Duration(seconds: 10),
                constraints: const BoxConstraints(maxWidth: 320),
                padding: const EdgeInsets.all(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.info_outline,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.sync, color: Color(0xFF2196F3)),
                tooltip: 'Sync Order & Bill',
                onPressed: _isProcessing ? null : _syncOrderAndBill,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            padding: EdgeInsets.all(pad),
            shrinkWrap: true,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    infoChip(Icons.person_outline, widget.order.customerName),
                    infoChip(
                      Icons.calendar_today_outlined,
                      DateFormat('dd/MM/yyyy').format(widget.order.createdAt),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pack Items',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Packing now: $_itemsPackingNow of ${widget.order.items.length} items',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _isProcessing ? null : _packAllRemaining,
                    child: Text(
                      isMobile ? 'Pack all' : 'Pack all remaining',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...buildFarmerGroupedWidgets(
                widget.order.items,
                farmerIdOf: (item) => item.farmerId,
                farmerNameOf: _resolveFarmerName,
                itemBuilder: (item, _) => _buildPackItemRow(item, isMobile),
              ),
              const SizedBox(height: 4),
              _buildBillingSummary(),
              if (!_completesOrder &&
                  (_hasEntries ||
                      widget.order.items.any((i) => _packedOf(i) > 0)))
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isProcessing || _hasInvalidEntry
                        ? null
                        : _confirmShortClose,
                    icon: const Icon(Icons.flag_outlined, size: 18),
                    label: const Text('Close short & finalize'),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(pad, 12, pad, isMobile ? 12 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Colors.grey[200]!)),
          ),
          child: SafeArea(
            top: false,
            child: isMobile
                ? Row(
                    children: [
                      Expanded(child: cancelButton),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: submitButton),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: cancelButton),
                      const SizedBox(width: 16),
                      Expanded(child: submitButton),
                    ],
                  ),
          ),
        ),
      ],
    );

    // Phones get a full-screen sheet; larger screens keep the 600px dialog.
    if (isMobile) {
      return Dialog.fullscreen(child: SafeArea(child: content));
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(640.0, screenSize.width - 80),
          maxHeight: screenSize.height * 0.9,
        ),
        child: content,
      ),
    );
  }

  Widget _buildFarmerNameTag(String? farmerName) {
    if (farmerName == null || farmerName.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.agriculture, size: 12, color: Colors.green[700]),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              farmerName,
              style: TextStyle(fontSize: 11, color: Colors.green[700]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackItemRow(OrderItem item, bool isMobile) {
    final orderedQty = item.quantity;
    final packedSoFar = _packedOf(item);
    final remaining = _remainingOf(item);
    final packNow = _packNow[item.productId] ?? 0;
    final error = _validationError(item);
    final farmerName = _resolveFarmerName(item);
    final done = remaining == 0;

    String amount(double qty) => '₹${BillingCalculator.lineAmount(
          unitPrice: item.price,
          quantity: qty,
        ).toStringAsFixed(2)}';

    void setPackNow(double value) => _setPackNow(item, value);

    void decrement() => setPackNow(packNow - _getIncrementStep(item.unit));
    void increment() => setPackNow(packNow + _getIncrementStep(item.unit));

    void onQuantityTextChanged(String value) {
      final parsed = double.tryParse(value);
      setState(() => _packNow[item.productId] = parsed ?? 0);
    }

    // A larger minimum tap target than the icons' visual size, so +/- are
    // comfortable to tap on a touch screen without changing their look.
    const stepButtonConstraints = BoxConstraints(minWidth: 40, minHeight: 40);

    final quantityField = TextField(
      controller: _controllers[item.productId],
      enabled: !done && !_isProcessing,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.orange,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: const OutlineInputBorder(),
        hintText: '0',
        errorText: error,
        errorStyle: const TextStyle(fontSize: 10),
      ),
      onChanged: onQuantityTextChanged,
    );

    final stepper = Row(
      mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
      children: [
        IconButton.outlined(
          icon: const Icon(Icons.remove),
          onPressed: done || _isProcessing ? null : decrement,
          padding: EdgeInsets.zero,
          constraints: stepButtonConstraints,
        ),
        const SizedBox(width: 8),
        if (isMobile)
          Expanded(child: quantityField)
        else
          SizedBox(width: 70, child: quantityField),
        const SizedBox(width: 8),
        IconButton.outlined(
          icon: const Icon(Icons.add),
          onPressed: done || _isProcessing ? null : increment,
          padding: EdgeInsets.zero,
          constraints: stepButtonConstraints,
        ),
      ],
    );

    Widget column(String label, Color color, String value, String sub) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.productName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isMobile ? 15 : 14,
                ),
              ),
            ),
            if (done)
              const Chip(
                label: Text('Packed', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: Color(0xFFE8F5E9),
              ),
          ],
        ),
        Text(
          '₹${item.price.toStringAsFixed(0)}/${item.unit}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        _buildFarmerNameTag(farmerName),
      ],
    );

    final packedAfter = _packedAfterSession(item);
    final closing = _closeNow.contains(item.productId);
    final unbilled = BillingCalculator.fromMilli(
      math.max(
        0,
        BillingCalculator.toMilli(orderedQty) -
            BillingCalculator.toMilli(packedAfter),
      ),
    );
    final canAdjust = !done && packedAfter > 0 && unbilled > 0;

    final packRemainingButton = done
        ? (item.packingClosed && unbilled > 0
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Closed at ${_formatQuantity(packedSoFar)} ${item.unit}; '
                  '${_formatQuantity(unbilled)} ${item.unit} not billed',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              )
            : const SizedBox.shrink())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed:
                        _isProcessing ? null : () => setPackNow(remaining),
                    child: Text(
                      'Pack remaining (${_formatQuantity(remaining)} ${item.unit})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    tooltip: closing
                        ? 'Undo: keep remaining quantity pending'
                        : 'Adjust to packed quantity (balance not billed)',
                    icon: Icon(
                      Icons.sync,
                      color: closing ? Colors.orange[800] : null,
                    ),
                    onPressed: _isProcessing || (!canAdjust && !closing)
                        ? null
                        : () => _toggleClose(item),
                  ),
                ],
              ),
              if (closing)
                Text(
                  'Will close at ${_formatQuantity(packedAfter)} ${item.unit}; '
                  '${_formatQuantity(unbilled)} ${item.unit} '
                  '(${amount(unbilled)}) will not be billed',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
            ],
          );

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFF6FBF6) : Colors.white,
        border: Border.all(
          color: done ? const Color(0xFFC8E6C9) : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 12),
          if (isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  column(
                    'ORDERED',
                    Colors.blue,
                    '${_formatQuantity(orderedQty)} ${item.unit}',
                    amount(orderedQty),
                  ),
                  column(
                    'PACKED',
                    Colors.green,
                    '${_formatQuantity(packedSoFar)} ${item.unit}',
                    amount(packedSoFar),
                  ),
                  column(
                    'REMAINING',
                    remaining == 0 ? Colors.grey : Colors.red,
                    '${_formatQuantity(remaining)} ${item.unit}',
                    amount(remaining),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'PACK NOW',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  amount(packNow),
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
            const SizedBox(height: 6),
            stepper,
            packRemainingButton,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                column(
                    'ORDERED',
                    Colors.blue,
                    '${orderedQty.toStringAsFixed(2)} ${item.unit}',
                    amount(orderedQty)),
                column(
                    'PACKED SO FAR',
                    Colors.green,
                    '${packedSoFar.toStringAsFixed(2)} ${item.unit}',
                    amount(packedSoFar)),
                column(
                    'REMAINING',
                    remaining == 0 ? Colors.grey : Colors.red,
                    '${remaining.toStringAsFixed(2)} ${item.unit}',
                    amount(remaining)),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('PACK NOW',
                          style: TextStyle(fontSize: 11, color: Colors.orange)),
                      const SizedBox(height: 4),
                      stepper,
                      Text(
                        amount(packNow),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      packRemainingButton,
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBillingSummary() {
    // Derived from persisted packed quantities plus this session's entries;
    // never from a running total. Price is the order-level snapshot.
    final items = widget.order.items;
    final orderedTotal = BillingCalculator.subtotal(items, (i) => i.quantity);
    final packedValue = BillingCalculator.subtotal(items, (i) => _packedOf(i));
    final sessionValue = BillingCalculator.subtotal(
      items,
      (i) => _packNow[i.productId] ?? 0,
    );
    final afterSession = packedValue + sessionValue;
    final difference = afterSession - orderedTotal;

    Widget line(String label, String value, {Color? color, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(label, style: const TextStyle(color: Colors.grey)),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          line('Ordered value', '₹${orderedTotal.toStringAsFixed(2)}'),
          line('Packed in earlier sessions',
              '₹${packedValue.toStringAsFixed(2)}'),
          line('This session', '₹${sessionValue.toStringAsFixed(2)}'),
          const Divider(height: 16),
          line('Packed value after save', '₹${afterSession.toStringAsFixed(2)}',
              bold: true),
          line(
            'Vs ordered',
            '${difference > 0 ? '+' : ''}₹${difference.toStringAsFixed(2)}',
            color: difference == 0
                ? Colors.grey
                : (difference > 0 ? Colors.green : Colors.red),
          ),
        ],
      ),
    );
  }

  double _getIncrementStep(String unit) {
    final lowerUnit = unit.toLowerCase();
    if (lowerUnit.contains('g') || lowerUnit.contains('gram')) {
      return 1.0;
    }
    if (lowerUnit.contains('kg') || lowerUnit.contains('kilogram')) {
      return 0.25;
    }
    if (lowerUnit.contains('l') || lowerUnit.contains('liter')) {
      return 0.25;
    }
    if (lowerUnit.contains('piece') ||
        lowerUnit.contains('pc') ||
        lowerUnit.contains('nos')) {
      return 1.0;
    }
    return 0.25; // Default increment
  }

  Future<void> _syncOrderAndBill() async {
    setState(() => _isProcessing = true);

    try {
      final billService = BillService();

      // Get bill for this order
      final bill = await billService.getBillByOrderId(widget.order.id);

      if (bill == null) {
        // No bill exists - show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '⚠️ No bill found for this order. Bill will be created when order is packed.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Compare order items with bill items
      final mismatches = <String>[];
      bool hasDiscrepancy = false;

      // Check each order item
      for (var orderItem in widget.order.items) {
        final billItem = bill.items.cast<BillItemModel?>().firstWhere(
              (bi) => bi?.productId == orderItem.productId,
              orElse: () => null,
            );

        if (billItem == null) {
          mismatches.add('${orderItem.productName}: Missing in bill');
          hasDiscrepancy = true;
        } else {
          // Check if quantities match
          final billQty = billItem.actualQuantity ?? billItem.orderedQuantity;
          if ((billQty - orderItem.quantity).abs() > 0.01) {
            mismatches.add(
                '${orderItem.productName}: Bill shows $billQty ${orderItem.unit}, Order has ${orderItem.quantity} ${orderItem.unit}');
            hasDiscrepancy = true;
          }
        }
      }

      // Check for extra items in bill
      for (var billItem in bill.items) {
        final orderItem = widget.order.items.cast<OrderItem?>().firstWhere(
              (oi) => oi?.productId == billItem.productId,
              orElse: () => null,
            );

        if (orderItem == null) {
          mismatches.add('${billItem.productName}: In bill but not in order');
          hasDiscrepancy = true;
        }
      }

      if (!hasDiscrepancy) {
        // Everything is in sync
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('✓ Order and bill are in sync'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Show mismatches and offer to fix
        if (mounted) {
          final shouldFix = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Sync Issues Found'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Found ${mismatches.length} mismatch(es) between order and bill:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...mismatches.map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(color: Colors.orange)),
                              Expanded(child: Text(m)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),
                    const Text(
                      'Would you like to update the bill to match the current order?',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: const Text('Fix & Sync'),
                ),
              ],
            ),
          );

          if (shouldFix == true) {
            // Only a draft bill is re-derived; final bills are immutable.
            await billService.syncDraftBillWithOrder(
              orderId: widget.order.id,
              updatedBy: 'admin',
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Bill sync check failed', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Unable to verify the bill for this order. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Saves this session (if anything was entered) and, when nothing remains
  /// (or the packer explicitly closes the order short), finalizes the order
  /// and bill. Both steps are idempotent, so a retry is always safe.
  Future<void> _submit({String? shortCloseReason}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final lines = [
      for (final item in widget.order.items)
        if ((_packNow[item.productId] ?? 0) > 0)
          PackingLine(
            productId: item.productId,
            quantity: _packNow[item.productId]!,
          ),
    ];
    final signature = lines
        .map((l) => '${l.productId}:${BillingCalculator.toMilli(l.quantity)}')
        .followedBy((_closeNow.toList()..sort()).map((id) => 'close:$id'))
        .join('|');
    if (signature != _lastAttemptSignature) {
      _operationId = _newOperationId();
      _lastAttemptSignature = signature;
    }

    try {
      final packedBy = ref.read(currentUserProvider).valueOrNull?.id ?? 'admin';
      var fullyPacked = PackingCalculator.isFullyPacked(widget.order);
      if (lines.isNotEmpty || _closeNow.isNotEmpty) {
        final result = await _packingService.savePackingSession(
          orderId: widget.order.id,
          operationId: _operationId,
          lines: lines,
          packedBy: packedBy,
          closeProductIds: {..._closeNow},
        );
        fullyPacked = result.packingStatus == 'fully_packed';
      }

      var finalized = false;
      if (fullyPacked || shortCloseReason != null) {
        await _packingService.finalizeOrder(
          orderId: widget.order.id,
          finalizedBy: packedBy,
          shortCloseReason: fullyPacked ? null : shortCloseReason,
        );
        finalized = true;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(finalized
                      ? 'Order packed and bill finalized'
                      : 'Partial packing saved. Order stays in packaging.'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on PackingException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to save packing', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Unable to save packing. Tap save again to retry safely.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmShortClose() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Close order short?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Reason (required)',
            helperText: 'Unpacked quantities will not be billed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Close & finalize'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason != null && reason.isNotEmpty) {
      await _submit(shortCloseReason: reason);
    }
  }
}

// Packing Slip Dialog (simplified)
class PackingSlipDialog extends StatelessWidget {
  final OrderModel order;

  const PackingSlipDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFF2196F3)),
                const SizedBox(width: 12),
                Text(
                  'Packing Slip #${order.id.substring(0, 8)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Packing slip details here...'),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.print),
              label: const Text('Print'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
