import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';

// Packaging status enum
enum PackagingStatus {
  start,
  pack,
  notify,
  done,
}

extension PackagingStatusExtension on PackagingStatus {
  String get displayName {
    switch (this) {
      case PackagingStatus.start:
        return 'Start';
      case PackagingStatus.pack:
        return 'Packing';
      case PackagingStatus.notify:
        return 'Notified';
      case PackagingStatus.done:
        return 'Done';
    }
  }

  Color get color {
    switch (this) {
      case PackagingStatus.start:
        return const Color(0xFF2196F3);
      case PackagingStatus.pack:
        return const Color(0xFFFF9800);
      case PackagingStatus.notify:
        return const Color(0xFF9C27B0);
      case PackagingStatus.done:
        return const Color(0xFF4CAF50);
    }
  }
}

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
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final newOrdersAsync = ref.watch(packagingOrdersProvider);
    final inProgressAsync = ref.watch(inProgressPackagingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Packaging'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.calendar_today, color: Colors.white, size: 18),
            label: Text(
              DateFormat('dd MMM yyyy').format(DateTime.now()),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            onPressed: () {},
            tooltip: 'Print All',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(packagingOrdersProvider);
              ref.invalidate(inProgressPackagingProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsCards(newOrdersAsync, inProgressAsync),
          _buildTabBar(),
          _buildFilters(),
          Expanded(
            child: _showOrderPicking
                ? _buildOrderPickingTab(newOrdersAsync)
                : _buildFarmerPickingTab(),
          ),
          _buildPaginationControls(newOrdersAsync),
        ],
      ),
    );
  }

  Widget _buildStatsCards(
    AsyncValue<List<OrderModel>> newOrders,
    AsyncValue<List<OrderModel>> inProgress,
  ) {
    final newCount = newOrders.value?.length ?? 0;
    final packedCount = inProgress.value?.where((o) => o.preparingAt != null).length ?? 0;
    final inProgressCount = inProgress.value?.length ?? 0;
    final pendingCount = newCount - packedCount;
    final notifiedCount = 1; // Placeholder

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Orders',
              newCount.toString(),
              '~96% on yesterday',
              Icons.receipt_long,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Packed',
              packedCount.toString(),
              '~96% on yesterday',
              Icons.inventory_2,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'In Progress',
              inProgressCount.toString(),
              'Currently packing',
              Icons.hourglass_empty,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Pending',
              pendingCount.toString(),
              'Awaiting packing',
              Icons.pending_actions,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Notified',
              notifiedCount.toString(),
              'Customer notified',
              Icons.notifications,
              Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildTab('Order Picking', _showOrderPicking),
          const SizedBox(width: 16),
          _buildTab('Farmer Picking Lists', !_showOrderPicking),
        ],
      ),
    );
  }

  Widget _buildTab(String label, bool isSelected) {
    return InkWell(
      onTap: () {
        setState(() {
          _showOrderPicking = label == 'Order Picking';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by Order ID or Customer',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedHub,
            items: ['All Hubs', 'Hub 1', 'Hub 2'].map((hub) {
              return DropdownMenuItem(value: hub, child: Text(hub));
            }).toList(),
            onChanged: (value) => setState(() => _selectedHub = value!),
          ),
          const SizedBox(width: 16),
          DropdownButton<String>(
            value: _selectedStatus,
            items: ['All Statuses', 'Pending', 'Packed', 'Notified'].map((status) {
              return DropdownMenuItem(value: status, child: Text(status));
            }).toList(),
            onChanged: (value) => setState(() => _selectedStatus = value!),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
            tooltip: 'Filter',
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPickingTab(AsyncValue<List<OrderModel>> ordersAsync) {
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: paginatedOrders.length,
          itemBuilder: (context, index) {
            final order = paginatedOrders[index];
            return _buildPackagingOrderCard(order);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }

  Widget _buildPaginationControls(AsyncValue<List<OrderModel>> ordersAsync) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: ordersAsync.when(
        data: (orders) {
          final filteredOrders = _filterOrders(orders);
          final totalPages = (filteredOrders.length / _itemsPerPage).ceil();

          if (totalPages <= 1) {
            return const SizedBox.shrink();
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              const SizedBox(width: 16),
              Text(
                'Page $_currentPage of $totalPages',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
            ],
          );
        },
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
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

    return filtered;
  }

  Widget _buildPackagingOrderCard(OrderModel order) {
    final packagingStatus = _getPackagingStatus(order);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9C27B0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'PKG${order.id.substring(0, 3).toUpperCase()}',
                    style: const TextStyle(
                      color: Color(0xFF9C27B0),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  order.id.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _buildPackagingStatusBadge(packagingStatus),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.apartmentName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${order.items.length} items',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  DateFormat('hh:mm a').format(order.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPackedItemsSummary(order),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showPackingDialog(order),
                    icon: const Icon(Icons.inventory_2, size: 18),
                    label: const Text('Start'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2196F3),
                      side: const BorderSide(color: Color(0xFF2196F3)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPackingSlip(order),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.print),
                  onPressed: () => _printPackingSlip(order),
                  tooltip: 'Print',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackedItemsSummary(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2, size: 16, color: Color(0xFF9C27B0)),
              const SizedBox(width: 8),
              const Text(
                'Packed Items',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9C27B0),
                ),
              ),
              const Spacer(),
              Text(
                '${order.items.length} items',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...order.items.take(3).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              )),
          if (order.items.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${order.items.length - 3} more items',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ),
        ],
      ),
    );
  }

  PackagingStatus _getPackagingStatus(OrderModel order) {
    if (order.status == OrderStatus.confirmed) {
      return PackagingStatus.start;
    } else if (order.status == OrderStatus.preparing) {
      return PackagingStatus.pack;
    } else if (order.status == OrderStatus.ready) {
      return PackagingStatus.notify;
    }
    return PackagingStatus.done;
  }

  Widget _buildPackagingStatusBadge(PackagingStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: status.color),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFarmerPickingTab() {
    return const Center(
      child: Text('Farmer Picking Lists - Coming Soon'),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2, size: 100, color: Colors.grey[300]),
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

  void _showPackingDialog(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => PackingDialog(order: order),
    );
  }

  void _showPackingSlip(OrderModel order) {
    showDialog(
      context: context,
      builder: (context) => PackingSlipDialog(order: order),
    );
  }

  void _printPackingSlip(OrderModel order) {
    // Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printing packing slip...')),
    );
  }
}

// Packing Dialog
class PackingDialog extends StatefulWidget {
  final OrderModel order;

  const PackingDialog({super.key, required this.order});

  @override
  State<PackingDialog> createState() => _PackingDialogState();
}

class _PackingDialogState extends State<PackingDialog> {
  final Map<String, double> _packedQuantities = {};
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize with ordered quantities
    for (var item in widget.order.items) {
      _packedQuantities[item.productId] = item.quantity;
    }
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
                  'Pack Order #${widget.order.id.substring(0, 4)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                        SizedBox(
                          width: 80,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              suffixText: item.unit,
                            ),
                            controller: TextEditingController(text: packedQty.toStringAsFixed(2)),
                            onChanged: (value) {
                              setState(() {
                                _packedQuantities[item.productId] = double.tryParse(value) ?? orderedQty;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${(packedQty * item.price).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DIFFERENCE', style: TextStyle(fontSize: 11, color: Colors.green)),
                    const SizedBox(height: 4),
                    Text(
                      '${difference >= 0 ? '+' : ''}${difference.toStringAsFixed(2)} ${item.unit}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: difference >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      '₹${(difference * item.price).toStringAsFixed(2)}',
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
    double preOrderTotal = 0;
    double postPackingTotal = 0;

    for (var item in widget.order.items) {
      preOrderTotal += item.totalPrice;
      final packedQty = _packedQuantities[item.productId] ?? item.quantity;
      postPackingTotal += packedQty * item.price;
    }

    final adjustment = postPackingTotal - preOrderTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'Billing Summary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Pre-Order Bill (Ordered Qty)'),
              Text('₹${preOrderTotal.toStringAsFixed(2)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Post-Packing Bill (Actual Qty)', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '₹${postPackingTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF9C27B0)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Adjustment'),
              Text(
                '₹${adjustment.toStringAsFixed(2)}',
                style: TextStyle(
                  color: adjustment >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndMarkPacked() async {
    setState(() => _isProcessing = true);

    try {
      // Update order with packed quantities
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.order.id);

      // Calculate new total
      double newTotal = 0;
      final updatedItems = widget.order.items.map((item) {
        final packedQty = _packedQuantities[item.productId] ?? item.quantity;
        newTotal += packedQty * item.price;
        return item.copyWith(quantity: packedQty);
      }).toList();

      await orderRef.update({
        'status': 'preparing',
        'preparingAt': Timestamp.fromDate(DateTime.now()),
        'items': updatedItems.map((item) => item.toJson()).toList(),
        'totalAmount': newTotal,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as packed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

// Packing Slip Dialog
class PackingSlipDialog extends StatelessWidget {
  final OrderModel order;

  const PackingSlipDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Order Packing Slip',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            // Packing slip content here
            const Text('Packing slip content - similar to screenshot'),
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
                    onPressed: () {},
                    icon: const Icon(Icons.print),
                    label: const Text('Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
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
}
