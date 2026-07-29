import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/admin/presentation/widgets/order_details_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_order_dialog.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';

// Provider for all orders
final adminOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  String _selectedStatus = 'all';
  String _searchQuery = '';
  String _selectedHub = 'All HUBs';
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
    final ordersAsync = ref.watch(adminOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Orders'),
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
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(adminOrdersProvider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(ordersAsync),
          _buildFiltersRow(),
          Expanded(
            child: _buildOrdersTable(ordersAsync),
          ),
        ],
      ),
    );
  }

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
            'Orders',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(AsyncValue<List<OrderModel>> ordersAsync) {
    final orders = ordersAsync.value ?? [];
    final totalOrders = orders.length;
    final pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    final onTheWay = orders.where((o) => o.status == OrderStatus.preparing || o.status == OrderStatus.ready).length;
    final delivered = orders.where((o) => o.status == OrderStatus.delivered).length;
    final cancelled = orders.where((o) => o.status == OrderStatus.cancelled).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              totalOrders.toString(),
              Icons.receipt_long_outlined,
              const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingOrders.toString(),
              Icons.pending_outlined,
              const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'On The Way',
              onTheWay.toString(),
              Icons.local_shipping_outlined,
              const Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Delivered',
              delivered.toString(),
              Icons.check_circle_outline,
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Cancelled',
              cancelled.toString(),
              Icons.cancel_outlined,
              const Color(0xFFF44336),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
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

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
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
            ),
          ),
          const SizedBox(width: 12),
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
                    final hubNames = ['All HUBs', ...hubs.map((h) => h.name).toList()];
                    final validValue = hubNames.contains(_selectedHub) ? _selectedHub : 'All HUBs';
                    return DropdownButton<String>(
                      value: validValue,
                      underline: const SizedBox(),
                      isDense: true,
                      style: const TextStyle(fontSize: 13),
                      items: hubNames.map((hub) {
                        return DropdownMenuItem(value: hub, child: Text(hub, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedHub = value!),
                    );
                  },
                  loading: () => DropdownButton<String>(
                    value: 'All HUBs',
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'All HUBs', child: Text('Loading...', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButton<String>(
                    value: 'All HUBs',
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'All HUBs', child: Text('Error', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[50],
            ),
            child: DropdownButton<String>(
              value: _selectedStatus == 'all' ? 'All Statuses' : _selectedStatus.substring(0, 1).toUpperCase() + _selectedStatus.substring(1),
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 13),
              items: ['All Statuses', 'Pending', 'Confirmed', 'Preparing', 'Ready', 'Delivered', 'Cancelled'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedStatus = value == 'All Statuses' ? 'all' : value!.toLowerCase()),
            ),
          ),
          const SizedBox(width: 12),
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
              items: ['This Week', 'This Month', 'This Quarter', 'This Year', 'Custom'].map((filter) {
                return DropdownMenuItem(value: filter, child: Text(filter, style: const TextStyle(fontSize: 13)));
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
          const SizedBox(width: 12),
          if (_selectedDateFilter == 'Custom' && _startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2196F3)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF2196F3).withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Color(0xFF2196F3)),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _showDateRangePicker(),
                    child: const Icon(Icons.edit, size: 14, color: Color(0xFF2196F3)),
                  ),
                ],
              ),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.filter_list, size: 16),
            label: const Text('Filter', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              side: BorderSide(color: Colors.grey[300]!),
              minimumSize: const Size(60, 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTable(AsyncValue<List<OrderModel>> ordersAsync) {
    return ordersAsync.when(
      data: (orders) {
        final filteredOrders = _filterOrders(orders);

        if (filteredOrders.isEmpty) {
          return _buildEmptyState();
        }

        final totalPages = (filteredOrders.length / _itemsPerPage).ceil();
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage).clamp(0, filteredOrders.length);
        final paginatedOrders = filteredOrders.sublist(startIndex, endIndex);

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
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: paginatedOrders.length,
                  itemBuilder: (context, index) {
                    final order = paginatedOrders[index];
                    return _buildTableRow(order, index);
                  },
                ),
              ),
              _buildPaginationControls(filteredOrders.length, totalPages),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
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
          _buildHeaderCell('Order ID', flex: 1),
          _buildHeaderCell('Customer', flex: 2),
          _buildHeaderCell('Schedule', flex: 1),
          _buildHeaderCell('HUB', flex: 1),
          _buildHeaderCell('Apartment', flex: 1),
          _buildHeaderCell('Delivery', flex: 1),
          _buildHeaderCell('Amount (₹)', flex: 1),
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
    final orderId = order.id.substring(0, 8).toUpperCase();
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
          _buildCell('ORD$orderId', flex: 1, color: const Color(0xFF2196F3)),
          _buildCell(order.customerName, flex: 2),
          _buildCell(scheduleInfo, flex: 1),
          _buildCell(hubInfo, flex: 1),
          _buildCell(order.apartmentName, flex: 1),
          _buildCell(deliveryInfo, flex: 1),
          _buildCell('₹${order.totalAmount.toStringAsFixed(2)}', flex: 1),
          _buildStatusCell(order.status.displayName, order.status, flex: 1),
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

  Widget _buildStatusCell(String status, OrderStatus orderStatus, {int flex = 1}) {
    Color color;
    Color bgColor;
    
    switch (orderStatus) {
      case OrderStatus.pending:
        color = const Color(0xFFFFC107);
        bgColor = const Color(0xFFFFC107).withOpacity(0.1);
        break;
      case OrderStatus.confirmed:
        color = const Color(0xFF2196F3);
        bgColor = const Color(0xFF2196F3).withOpacity(0.1);
        break;
      case OrderStatus.preparing:
        color = const Color(0xFFFF9800);
        bgColor = const Color(0xFFFF9800).withOpacity(0.1);
        break;
      case OrderStatus.ready:
        color = const Color(0xFF9C27B0);
        bgColor = const Color(0xFF9C27B0).withOpacity(0.1);
        break;
      case OrderStatus.in_transit:
        color = const Color(0xFFFF6F00);
        bgColor = const Color(0xFFFF6F00).withOpacity(0.1);
        break;
      case OrderStatus.delivered:
        color = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
        break;
      case OrderStatus.cancelled:
        color = const Color(0xFFF44336);
        bgColor = const Color(0xFFF44336).withOpacity(0.1);
        break;
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
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF2196F3)),
            onPressed: () => _showOrderDetails(order),
            tooltip: 'View',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Edit button - available for pending and confirmed orders
          if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFFFF9800)),
              onPressed: () => _showEditOrderDialog(order),
              tooltip: 'Edit Order',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
          ],
          if (order.status == OrderStatus.pending) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 18, color: Color(0xFF4CAF50)),
              onPressed: () => _acceptOrder(order),
              tooltip: 'Accept',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFF44336)),
              onPressed: () => _rejectOrder(order),
              tooltip: 'Reject',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else if (order.status == OrderStatus.confirmed) ...[
            IconButton(
              icon: const Icon(Icons.check_circle, size: 18, color: Colors.grey),
              onPressed: null,
              tooltip: 'Already Accepted',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.grey),
              onPressed: null,
              tooltip: 'Cannot Reject',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.more_vert, size: 18),
              onPressed: () => _showOrderMenu(order),
              tooltip: 'More',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems, int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage * _itemsPerPage).clamp(0, totalItems)} of $totalItems',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (totalPages > 1)
            Row(
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

    // Apply hub filter
    if (_selectedHub != 'All HUBs') {
      filtered = filtered.where((order) {
        return order.hubName == _selectedHub;
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'all') {
      filtered = filtered.where((order) => order.status.name == _selectedStatus).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        return order.customerName.toLowerCase().contains(query) ||
            order.id.toLowerCase().contains(query);
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
        final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
        final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
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
          Icon(Icons.receipt_long_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No orders found',
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

  void _showOrderDetails(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => OrderDetailsDialog(order: order),
    );
  }

  void _showEditOrderDialog(OrderModel order) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditOrderDialog(order: order),
    );
    
    if (result == true && mounted) {
      // Refresh orders after successful edit
      ref.invalidate(adminOrdersProvider);
    }
  }

  Widget _buildStatusTimeline(OrderModel order) {
    final timelineItems = <Map<String, dynamic>>[];

    // Ordered
    timelineItems.add({
      'label': 'Ordered',
      'time': order.createdAt,
      'icon': Icons.shopping_cart,
      'color': const Color(0xFF2196F3),
      'completed': true,
    });

    // Confirmed
    if (order.confirmedAt != null) {
      timelineItems.add({
        'label': 'Accepted',
        'time': order.confirmedAt,
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.confirmed) {
      timelineItems.add({
        'label': 'Accepted',
        'time': order.confirmedAt,
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Accepted',
        'time': null,
        'icon': Icons.check_circle_outline,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Preparing
    if (order.preparingAt != null) {
      timelineItems.add({
        'label': 'Packing Started',
        'time': order.preparingAt,
        'icon': Icons.inventory_2,
        'color': const Color(0xFF9C27B0),
        'completed': true,
      });
    } else if (order.status == OrderStatus.preparing) {
      timelineItems.add({
        'label': 'Packing Started',
        'time': order.preparingAt,
        'icon': Icons.inventory_2,
        'color': const Color(0xFF9C27B0),
        'completed': true,
      });
    } else if (order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Packing Started',
        'time': null,
        'icon': Icons.inventory_2_outlined,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Ready
    if (order.readyAt != null) {
      timelineItems.add({
        'label': 'Packed',
        'time': order.readyAt,
        'icon': Icons.check_box,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.ready) {
      timelineItems.add({
        'label': 'Packed',
        'time': order.readyAt,
        'icon': Icons.check_box,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Packed',
        'time': null,
        'icon': Icons.check_box_outline_blank,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Delivered
    if (order.deliveredAt != null) {
      timelineItems.add({
        'label': 'Delivered',
        'time': order.deliveredAt,
        'icon': Icons.local_shipping,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.delivered) {
      timelineItems.add({
        'label': 'Delivered',
        'time': order.deliveredAt,
        'icon': Icons.local_shipping,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.ready || order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Delivered',
        'time': null,
        'icon': Icons.local_shipping_outlined,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Cancelled
    if (order.cancelledAt != null) {
      timelineItems.add({
        'label': 'Cancelled',
        'time': order.cancelledAt,
        'icon': Icons.cancel,
        'color': const Color(0xFFF44336),
        'completed': true,
      });
    }

    return Column(
      children: timelineItems.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == timelineItems.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item['completed'] ? item['color'] : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    item['icon'],
                    color: item['completed'] ? Colors.white : Colors.grey,
                    size: 20,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 40,
                    color: item['completed'] ? item['color'] : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'],
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: item['completed'] ? item['color'] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (item['time'] != null)
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(item['time']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      )
                    else
                      Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[400],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return const Color(0xFFFFC107);
      case OrderStatus.confirmed:
        return const Color(0xFF2196F3);
      case OrderStatus.preparing:
        return const Color(0xFF9C27B0);
      case OrderStatus.ready:
        return const Color(0xFF4CAF50);
      case OrderStatus.in_transit:
        return const Color(0xFFFF6F00);
      case OrderStatus.delivered:
        return const Color(0xFF009688);
      case OrderStatus.cancelled:
        return const Color(0xFFF44336);
    }
  }

  void _showOrderMenu(OrderModel order) {
    // Show order menu
  }

  Future<void> _acceptOrder(OrderModel order) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
      await orderRef.update({
        'status': 'confirmed',
        'confirmedAt': Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order accepted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting order: $e')),
        );
      }
    }
  }

  Future<void> _rejectOrder(OrderModel order) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
      await orderRef.update({
        'status': 'cancelled',
        'cancelledAt': Timestamp.fromDate(DateTime.now()),
        'cancellationReason': 'Rejected by admin',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order rejected successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting order: $e')),
        );
      }
    }
  }
}
