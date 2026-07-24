import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/admin/presentation/widgets/order_details_dialog.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';

// Provider for ready orders (ready for pickup)
final readyOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
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

// Provider for in transit orders
final inTransitOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'in_transit')
      .where('isDeleted', isEqualTo: false)
      .orderBy('deliveryDate', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

// Provider for delivered orders
final deliveredOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'delivered')
      .where('isDeleted', isEqualTo: false)
      .orderBy('deliveredAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

// Provider for pending orders (confirmed but not yet packed)
final pendingOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'confirmed')
      .where('isDeleted', isEqualTo: false)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

// Provider for cancelled orders
final cancelledOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'cancelled')
      .where('isDeleted', isEqualTo: false)
      .orderBy('cancelledAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
  });
});

class AdminDeliveryPage extends ConsumerStatefulWidget {
  const AdminDeliveryPage({super.key});

  @override
  ConsumerState<AdminDeliveryPage> createState() => _AdminDeliveryPageState();
}

class _AdminDeliveryPageState extends ConsumerState<AdminDeliveryPage> {
  String _searchQuery = '';
  String _selectedHub = 'All Hubs';
  String _selectedStatus = 'Ready for Pickup';
  String _selectedDateFilter = 'This Week';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _applyDateFilter('All Time');
  }

  void _applyDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _selectedDateFilter = filter;
      
      switch (filter) {
        case 'All Time':
          _startDate = null;
          _endDate = null;
          break;
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
    final readyOrdersAsync = ref.watch(readyOrdersProvider);
    final inTransitOrdersAsync = ref.watch(inTransitOrdersProvider);
    final deliveredOrdersAsync = ref.watch(deliveredOrdersProvider);
    final pendingOrdersAsync = ref.watch(pendingOrdersProvider);
    final cancelledOrdersAsync = ref.watch(cancelledOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Deliveries'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () {},
            tooltip: DateFormat('dd MMM yyyy').format(DateTime.now()),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Delivery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(readyOrdersAsync, inTransitOrdersAsync, deliveredOrdersAsync, pendingOrdersAsync, cancelledOrdersAsync),
          _buildFiltersRow(),
          Expanded(
            child: _buildDeliveriesTable(readyOrdersAsync, inTransitOrdersAsync, deliveredOrdersAsync),
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
            'Deliveries',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<List<OrderModel>> readyOrders,
    AsyncValue<List<OrderModel>> inTransitOrders,
    AsyncValue<List<OrderModel>> deliveredOrders,
    AsyncValue<List<OrderModel>> pendingOrders,
    AsyncValue<List<OrderModel>> cancelledOrders,
  ) {
    final totalDeliveries = (readyOrders.value?.length ?? 0) + (inTransitOrders.value?.length ?? 0) + (deliveredOrders.value?.length ?? 0);
    final ready = readyOrders.value?.length ?? 0;
    final inTransit = inTransitOrders.value?.length ?? 0;
    final delivered = deliveredOrders.value?.length ?? 0;
    final pending = pendingOrders.value?.length ?? 0;
    final failedCancelled = cancelledOrders.value?.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Deliveries',
              totalDeliveries.toString(),
              Icons.local_shipping_outlined,
              const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Ready for Pickup',
              ready.toString(),
              Icons.inventory_2_outlined,
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Transit',
              inTransit.toString(),
              Icons.flight_takeoff_outlined,
              const Color(0xFF9C27B0),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Delivered',
              delivered.toString(),
              Icons.check_circle_outline,
              const Color(0xFF2196F3),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pending.toString(),
              Icons.pending_outlined,
              const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Failed / Cancelled',
              failedCancelled.toString(),
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
                hintText: 'Search by Delivery ID, Order ID or Customer',
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
                    final hubNames = ['All Hubs', ...hubs.map((h) => h.name).toList()];
                    final validValue = hubNames.contains(_selectedHub) ? _selectedHub : 'All Hubs';
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
                    value: 'All Hubs',
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'All Hubs', child: Text('Loading...', style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: null,
                  ),
                  error: (_, __) => DropdownButton<String>(
                    value: 'All Hubs',
                    underline: const SizedBox(),
                    isDense: true,
                    style: const TextStyle(fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'All Hubs', child: Text('Error', style: TextStyle(fontSize: 13))),
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
              value: _selectedStatus,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 13),
              items: ['All Statuses', 'Ready for Pickup', 'In Transit', 'Delivered'].map((status) {
                return DropdownMenuItem(value: status, child: Text(status, style: const TextStyle(fontSize: 13)));
              }).toList(),
              onChanged: (value) => setState(() => _selectedStatus = value!),
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
              items: ['All Time', 'This Week', 'This Month', 'This Quarter', 'This Year', 'Custom'].map((filter) {
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
                border: Border.all(color: const Color(0xFF4CAF50)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF4CAF50).withOpacity(0.05),
              ),
              child: Row(
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
                    child: const Icon(Icons.edit, size: 14, color: Color(0xFF4CAF50)),
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

  Widget _buildDeliveriesTable(
    AsyncValue<List<OrderModel>> readyOrdersAsync,
    AsyncValue<List<OrderModel>> inTransitOrdersAsync,
    AsyncValue<List<OrderModel>> deliveredOrdersAsync,
  ) {
    return readyOrdersAsync.when(
      data: (readyOrders) {
        return inTransitOrdersAsync.when(
          data: (inTransitOrders) {
            return deliveredOrdersAsync.when(
              data: (deliveredOrders) {
                final allOrders = [...readyOrders, ...inTransitOrders, ...deliveredOrders];
                final filteredOrders = _filterOrders(allOrders);

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
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(child: Text('Error: $error')),
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
          _buildHeaderCell('Dlv ID', flex: 1),
          _buildHeaderCell('Order ID', flex: 1),
          _buildHeaderCell('Customer', flex: 2),
          _buildHeaderCell('Schedule', flex: 1),
          _buildHeaderCell('HUB', flex: 1),
          _buildHeaderCell('Delivery', flex: 1),
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
    // Use stored deliveryId if available, otherwise generate on-the-fly
    final dlvId = order.deliveryId ?? 'DLV${order.id.substring(0, 8).toUpperCase()}';
    final orderId = 'ORD${order.id.substring(0, 8).toUpperCase()}';
    final isDelivered = order.status == OrderStatus.delivered;
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
          _buildCell(dlvId, flex: 1, color: const Color(0xFF4CAF50)),
          _buildCell(orderId, flex: 1, color: const Color(0xFF2196F3)),
          _buildCell(order.customerName, flex: 2),
          _buildCell(scheduleInfo, flex: 1),
          _buildCell(hubInfo, flex: 1),
          _buildCell(deliveryInfo, flex: 1),
          _buildStatusCell(isDelivered ? 'Delivered' : 'In Transit', isDelivered, flex: 1),
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

  Widget _buildDeliveryPartnerCell({int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Karthik R',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            'TN09 JU 1234',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCell(String status, bool isDelivered, {int flex = 1}) {
    final color = isDelivered ? const Color(0xFF4CAF50) : const Color(0xFF9C27B0);
    final bgColor = color.withOpacity(0.1);

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
    final isReady = order.status == OrderStatus.ready;
    final isInTransit = order.status == OrderStatus.in_transit;
    final isDelivered = order.status == OrderStatus.delivered;
    
    return Expanded(
      flex: flex,
      child: Row(
        children: [
          if (isReady)
            ElevatedButton(
              onPressed: () => _markAsInTransit(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 28),
              ),
              child: const Text('Start Delivery', style: TextStyle(fontSize: 11)),
            )
          else if (isInTransit)
            ElevatedButton(
              onPressed: () => _markAsDelivered(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(60, 28),
              ),
              child: const Text('Deliver', style: TextStyle(fontSize: 11)),
            )
          else if (isDelivered)
            const Icon(Icons.check_circle, size: 18, color: Color(0xFF4CAF50)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4CAF50)),
            onPressed: () => _showOrderDetails(order),
            tooltip: 'View',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 18),
            onPressed: () {},
            tooltip: 'More',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsDelivered(OrderModel order) async {
    // Show payment collection dialog
    showDialog(
      context: context,
      builder: (context) => PaymentCollectionDialog(order: order),
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

    // Apply status filter
    if (_selectedStatus != 'All Statuses') {
      filtered = filtered.where((order) {
        if (_selectedStatus == 'Ready for Pickup') {
          return order.status == OrderStatus.ready;
        } else if (_selectedStatus == 'In Transit') {
          return order.status == OrderStatus.in_transit;
        } else if (_selectedStatus == 'Delivered') {
          return order.status == OrderStatus.delivered;
        }
        return false;
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
          Icon(Icons.local_shipping_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No deliveries found',
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

  Future<void> _markAsInTransit(OrderModel order) async {
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
      await orderRef.update({
        'status': 'in_transit',
        'inTransitAt': Timestamp.fromDate(DateTime.now()),
      });
      if (mounted) {
        // Change status filter to 'All Statuses' so the user can see the order in its new state
        setState(() => _selectedStatus = 'All Statuses');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as in transit')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

// Payment Collection Dialog
class PaymentCollectionDialog extends StatefulWidget {
  final OrderModel order;

  const PaymentCollectionDialog({super.key, required this.order});

  @override
  State<PaymentCollectionDialog> createState() => _PaymentCollectionDialogState();
}

class _PaymentCollectionDialogState extends State<PaymentCollectionDialog> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _transactionIdController = TextEditingController();
  final TextEditingController _transactionReferenceController = TextEditingController();
  bool _isProcessing = false;
  String _selectedPaymentMethod = 'cash';
  String? _gpayId;
  String? _transactionScreenshot;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.order.totalAmount.toStringAsFixed(2);
    _loadGpayId();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _transactionIdController.dispose();
    _transactionReferenceController.dispose();
    super.dispose();
  }

  Future<void> _loadGpayId() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('payment')
          .get();
      
      if (doc.exists && mounted) {
        setState(() {
          _gpayId = doc.data()?['gpayId'];
        });
      }
    } catch (e) {
      print('Error loading GPay ID: $e');
    }
  }

  Future<void> _confirmDelivery() async {
    setState(() => _isProcessing = true);
    
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.order.id);
      final collectedAmount = double.tryParse(_amountController.text) ?? widget.order.totalAmount;
      
      final updateData = {
        'status': 'delivered',
        'deliveredAt': Timestamp.fromDate(DateTime.now()),
        'paymentStatus': 'completed',
        'paymentMethod': _selectedPaymentMethod,
      };

      // Add transaction details for GPay payments
      if (_selectedPaymentMethod == 'gpay') {
        if (_transactionIdController.text.trim().isNotEmpty) {
          updateData['transactionId'] = _transactionIdController.text.trim();
        }
        if (_transactionReferenceController.text.trim().isNotEmpty) {
          updateData['transactionReference'] = _transactionReferenceController.text.trim();
        }
        final screenshot = _transactionScreenshot;
        if (screenshot != null) {
          updateData['transactionScreenshot'] = screenshot;
        }
        updateData['transactionVerifiedAt'] = Timestamp.fromDate(DateTime.now());
        updateData['transactionVerifiedBy'] = 'Admin'; // TODO: Use actual admin name
      }
      
      await orderRef.update(updateData);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order delivered and payment collected successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                const Text(
                  'Collect Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Order ID', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('ORD${widget.order.id.substring(0, 8).toUpperCase()}'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Customer', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(widget.order.customerName),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        '₹${widget.order.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Method:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('Cash', style: TextStyle(fontSize: 14)),
                    value: 'cash',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    title: const Text('GPay', style: TextStyle(fontSize: 14)),
                    value: 'gpay',
                    groupValue: _selectedPaymentMethod,
                    onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedPaymentMethod == 'gpay') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 80, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'GPay Payment',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    if (_gpayId != null) ...[
                      Text(
                        'Pay to: $_gpayId',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF4CAF50)),
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      'Amount: ₹${widget.order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Transaction Details',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transactionIdController,
                decoration: InputDecoration(
                  labelText: 'Transaction ID (Optional)',
                  hintText: 'e.g., TXN123456789',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _transactionReferenceController,
                decoration: InputDecoration(
                  labelText: 'Reference Number (Optional)',
                  hintText: 'e.g., UPI Ref No',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  // TODO: Implement screenshot upload
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Screenshot upload coming soon')),
                  );
                },
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Upload Payment Screenshot'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              'Enter collected amount:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: '₹',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmDelivery,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Confirm Delivery'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
