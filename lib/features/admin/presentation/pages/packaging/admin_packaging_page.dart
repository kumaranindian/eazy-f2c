import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/admin/presentation/widgets/order_details_dialog.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';

// Provider for packaging orders (confirmed status)
final packagingOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
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

// Provider for in-progress packaging orders
final inProgressPackagingProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('orders')
      .where('status', isEqualTo: 'preparing')
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
  String _searchQuery = '';
  String _selectedHub = 'All Hubs';
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
      body: Column(
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
            'Packaging',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<List<OrderModel>> newOrders,
    AsyncValue<List<OrderModel>> inProgress,
  ) {
    final totalOrders = (newOrders.value?.length ?? 0) + (inProgress.value?.length ?? 0);
    final packedCount = inProgress.value?.where((o) => o.status == OrderStatus.ready).length ?? 0;
    final inProgressCount = inProgress.value?.where((o) => o.status == OrderStatus.preparing).length ?? 0;
    final pendingCount = newOrders.value?.where((o) => o.status == OrderStatus.confirmed).length ?? 0;
    final notifiedCount = 1; // Placeholder

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
              'Packed',
              packedCount.toString(),
              Icons.check_circle_outline,
              const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              inProgressCount.toString(),
              Icons.inventory_2_outlined,
              const Color(0xFFFF9800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingCount.toString(),
              Icons.pending_outlined,
              const Color(0xFFFFC107),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Notified',
              notifiedCount.toString(),
              Icons.notifications_outlined,
              const Color(0xFF9C27B0),
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

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('Order Picking', _showOrderPicking, Icons.inventory_2_outlined),
          const SizedBox(width: 16),
          _buildTab('Farmer Picking Lists', !_showOrderPicking, Icons.agriculture_outlined),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected, IconData icon) {
    return InkWell(
      onTap: () {
        setState(() {
          _showOrderPicking = label == 'Order Picking';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
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
              items: ['All Statuses', 'Packed', 'Pending', 'Notified'].map((status) {
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

  Widget _buildOrderPickingTable(AsyncValue<List<OrderModel>> ordersAsync) {
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
    final pkgId = order.packagingId ?? 'PKG${order.id.substring(0, 8).toUpperCase()}';
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
      case 'packed':
        color = const Color(0xFF4CAF50);
        bgColor = const Color(0xFF4CAF50).withOpacity(0.1);
        break;
      case 'pending':
        color = const Color(0xFFFFC107);
        bgColor = const Color(0xFFFFC107).withOpacity(0.1);
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(60, 32),
              ),
              child: const Text('Start', style: TextStyle(fontSize: 12)),
            )
          else
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      return 'Packed';
    } else if (order.status == OrderStatus.ready) {
      return 'Notified';
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
    // Generate packagingId and update status to preparing if not already done
    if (order.status == OrderStatus.confirmed) {
      try {
        final orderRef = FirebaseFirestore.instance.collection('orders').doc(order.id);
        final packagingId = 'PKG${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8).toUpperCase()}';
        
        await orderRef.update({
          'status': 'preparing',
          'preparingAt': Timestamp.fromDate(DateTime.now()),
          'packagingId': packagingId,
        });
        
        print('Generated packagingId: $packagingId');
      } catch (e) {
        print('Error generating packagingId: $e');
        // Continue anyway to show the dialog
      }
    }
    
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

  void _printPackingSlip(OrderModel order) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printing packing slip...')),
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
}

// Packing Dialog (simplified - reuse from old file)
class PackingDialog extends StatefulWidget {
  final OrderModel order;

  const PackingDialog({super.key, required this.order});

  @override
  State<PackingDialog> createState() => _PackingDialogState();
}

class _PackingDialogState extends State<PackingDialog> {
  final Map<String, double> _packedQuantities = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    for (var item in widget.order.items) {
      _packedQuantities[item.productId] = item.quantity;
      _controllers[item.productId] = TextEditingController(
        text: item.quantity.toStringAsFixed(2),
      );
    }
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2, color: Color(0xFF9C27B0)),
                const SizedBox(width: 12),
                Text(
                  'Pack Order #${widget.order.id.substring(0, 8)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Enter actual packed quantities for each item. System will automatically adjust the final bill.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
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
                const Text('Order Date', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(DateFormat('dd/MM/yyyy').format(widget.order.createdAt)),
              ],
            ),
            const Divider(height: 32),
            const Text(
              'Pack Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.order.items.length,
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];
                  return _buildPackItemRow(item);
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildBillingSummary(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _saveAndMarkPacked,
                    icon: const Icon(Icons.save),
                    label: const Text('Save & Mark Packed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackItemRow(OrderItem item) {
    final orderedQty = item.quantity;
    final packedQty = _packedQuantities[item.productId] ?? orderedQty;
    final difference = packedQty - orderedQty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.productName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '₹${item.price.toStringAsFixed(0)}/${item.unit}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ORDERED', style: TextStyle(fontSize: 11, color: Colors.blue)),
                    const SizedBox(height: 4),
                    Text(
                      '${orderedQty.toStringAsFixed(2)} ${item.unit}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    Text(
                      '₹${(orderedQty * item.price).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('PACKED', style: TextStyle(fontSize: 11, color: Colors.orange)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () {
                            final current = _packedQuantities[item.productId] ?? orderedQty;
                            final increment = _getIncrementStep(item.unit);
                            final newValue = (current - increment).clamp(0.0, orderedQty * 2);
                            setState(() {
                              _packedQuantities[item.productId] = newValue;
                              _controllers[item.productId]?.text = newValue.toStringAsFixed(2);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(
                          width: 60,
                          child: TextField(
                            controller: _controllers[item.productId],
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              final parsed = double.tryParse(value);
                              if (parsed != null) {
                                setState(() => _packedQuantities[item.productId] = parsed);
                              }
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () {
                            final current = _packedQuantities[item.productId] ?? orderedQty;
                            final increment = _getIncrementStep(item.unit);
                            final newValue = current + increment;
                            setState(() {
                              _packedQuantities[item.productId] = newValue;
                              _controllers[item.productId]?.text = newValue.toStringAsFixed(2);
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    Text(
                      '₹${(packedQty * item.price).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DIFFERENCE', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(2)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: difference == 0 ? Colors.grey : (difference > 0 ? Colors.green : Colors.red),
                      ),
                    ),
                    Text(
                      '${difference > 0 ? '+' : ''}₹${(difference * item.price).toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
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
    double originalTotal = widget.order.totalAmount;
    double newTotal = 0;
    for (var item in widget.order.items) {
      final packedQty = _packedQuantities[item.productId] ?? item.quantity;
      newTotal += packedQty * item.price;
    }
    final difference = newTotal - originalTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Original Total', style: TextStyle(color: Colors.grey)),
              Text('₹${originalTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('New Total', style: TextStyle(color: Colors.grey)),
              Text('₹${newTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Difference', style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${difference > 0 ? '+' : ''}₹${difference.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: difference == 0 ? Colors.grey : (difference > 0 ? Colors.green : Colors.red),
                ),
              ),
            ],
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
    if (lowerUnit.contains('piece') || lowerUnit.contains('pc') || lowerUnit.contains('nos')) {
      return 1.0;
    }
    return 0.25; // Default increment
  }

  Future<void> _saveAndMarkPacked() async {
    setState(() => _isProcessing = true);
    
    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.order.id);
      
      double newTotal = 0;
      final updatedItems = widget.order.items.map((item) {
        final packedQty = _packedQuantities[item.productId] ?? item.quantity;
        newTotal += packedQty * item.price;
        return item.copyWith(quantity: packedQty);
      }).toList();

      final updateData = {
        'status': 'ready',
        'readyAt': Timestamp.fromDate(DateTime.now()),
        'items': updatedItems.map((item) => item.toJson()).toList(),
        'totalAmount': newTotal,
      };

      // Ensure deliveryDate is set if not already present (required for Delivery page query)
      if (widget.order.deliveryDate == null) {
        updateData['deliveryDate'] = Timestamp.fromDate(DateTime.now());
      }

      // Generate and save deliveryId if not already present
      if (widget.order.deliveryId == null) {
        final deliveryId = 'DLV${DateTime.now().millisecondsSinceEpoch.toString().substring(0, 8).toUpperCase()}';
        updateData['deliveryId'] = deliveryId;
        print('Generated deliveryId: $deliveryId');
      }

      print('Updating order ${widget.order.id} with status: ready');
      await orderRef.update(updateData);
      print('Order updated successfully');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order marked as packed successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
