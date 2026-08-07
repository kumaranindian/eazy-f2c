import 'package:flutter/material.dart';
import 'package:f2c/core/utils/image_url_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/providers/customer_providers.dart';
import 'package:f2c/features/customer/models/order_model.dart';

// Provider for customer orders
final customerOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final customerAsync = ref.watch(currentCustomerProvider);

  return customerAsync.when(
    data: (customer) {
      if (customer == null) return Stream.value([]);

      return FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: customer.id)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();
      });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

class OrderHistoryPageNew extends ConsumerStatefulWidget {
  const OrderHistoryPageNew({super.key});

  @override
  ConsumerState<OrderHistoryPageNew> createState() => _OrderHistoryPageNewState();
}

class _OrderHistoryPageNewState extends ConsumerState<OrderHistoryPageNew> {
  OrderStatus? _filterStatus;
  String _searchQuery = '';

  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(customerOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_filterStatus != null) _buildFilterChip(),
          Expanded(
            child: ordersAsync.when(
              data: (orders) {
                final filteredOrders = _filterOrders(orders);

                if (filteredOrders.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildOrdersList(filteredOrders);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search orders...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text(_filterStatus!.displayName),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => setState(() => _filterStatus = null),
            backgroundColor: Color(int.parse(_filterStatus!.statusColor.replaceFirst('#', '0xFF'))),
            labelStyle: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _filterStatus != null || _searchQuery.isNotEmpty
                ? 'No orders found'
                : 'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterStatus != null || _searchQuery.isNotEmpty
                ? 'Try adjusting your filters'
                : 'Start shopping to place your first order',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> orders) {
    final isMobile = _isMobile(context);

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        return _buildOrderCard(orders[index], isMobile);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isMobile) {
    final statusColor = Color(int.parse(order.status.statusColor.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: order.isEditable ? Colors.orange.shade200 : Colors.grey.shade200,
          width: order.isEditable ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Order #${order.id.substring(0, 8)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (order.isEditable) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit, size: 12, color: Colors.orange[900]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Editable',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[900],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      order.status.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              if (order.scheduleName != null) ...[
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      order.scheduleName!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (order.deliveryDate != null) ...[
                Row(
                  children: [
                    Icon(Icons.local_shipping, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery: ${DateFormat('EEE, dd MMM yyyy').format(order.deliveryDate!)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Icon(Icons.shopping_bag, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '₹${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ),
              if (order.isEditable) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'You can edit this order until ${DateFormat('dd MMM, hh:mm a').format(order.cutoffDateTime!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders) {
    var filtered = orders;

    if (_filterStatus != null) {
      filtered = filtered.where((order) => order.status == _filterStatus).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((order) {
        return order.id.toLowerCase().contains(query) ||
            order.scheduleName?.toLowerCase().contains(query) == true ||
            order.items.any((item) => item.productName.toLowerCase().contains(query));
      }).toList();
    }

    return filtered;
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Orders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Orders'),
              leading: Radio<OrderStatus?>(
                value: null,
                groupValue: _filterStatus,
                onChanged: (value) {
                  setState(() => _filterStatus = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...OrderStatus.values.map((status) {
              return ListTile(
                title: Text(status.displayName),
                leading: Radio<OrderStatus?>(
                  value: status,
                  groupValue: _filterStatus,
                  onChanged: (value) {
                    setState(() => _filterStatus = value);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (order.isEditable)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _editOrder(order);
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildDetailSection('Order Information', [
                      _buildDetailRow('Order ID', '#${order.id.substring(0, 8)}'),
                      _buildDetailRow('Status', order.status.displayName),
                      _buildDetailRow('Placed On', DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
                      if (order.scheduleName != null)
                        _buildDetailRow('Schedule', order.scheduleName!),
                      if (order.deliveryDate != null)
                        _buildDetailRow('Delivery Date', DateFormat('dd MMM yyyy').format(order.deliveryDate!)),
                      if (order.deliveryTimeSlot != null)
                        _buildDetailRow('Time Slot', order.deliveryTimeSlot!),
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Items (${order.items.length})', [
                      ...order.items.map((item) => _buildOrderItem(item)),
                    ]),
                    const SizedBox(height: 24),
                    _buildDetailSection('Payment', [
                      _buildDetailRow('Payment Method', order.paymentMethod?.toUpperCase() ?? 'N/A'),
                      _buildDetailRow('Payment Status', order.paymentStatus?.toUpperCase() ?? 'N/A'),
                      _buildDetailRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}', isBold: true),
                    ]),
                    if (order.deliveryInstructions != null) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection('Delivery Instructions', [
                        Text(
                          order.deliveryInstructions!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF4CAF50) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              ImageUrlHelper.getSafeImageUrl(item.imageUrl),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 50,
                  height: 50,
                  color: Colors.grey[300],
                  child: Icon(Icons.image, color: Colors.grey[600]),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedQuantity} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  void _editOrder(OrderModel order) {
    // TODO: Implement order editing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Order editing feature coming soon!'),
        backgroundColor: Color(0xFF4CAF50),
      ),
    );
  }
}
