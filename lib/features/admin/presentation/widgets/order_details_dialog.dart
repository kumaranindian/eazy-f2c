import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';

class OrderDetailsDialog extends StatelessWidget {
  final OrderModel order;

  const OrderDetailsDialog({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 800,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: Color(0xFF2196F3)),
                const SizedBox(width: 12),
                Text(
                  'Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildOrderInfo(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Panel - Status Timeline
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Timeline',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildVerticalTimeline()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Panel - Order Items
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Items',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildOrderItems()),
                        const SizedBox(height: 16),
                        const Text(
                          'Delivery Address',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(order.deliveryAddress ?? 'N/A', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('Customer', order.customerName),
          const SizedBox(height: 8),
          _buildInfoRow('Status', order.status.displayName),
          const SizedBox(height: 8),
          _buildInfoRow('Total Amount', '₹${order.totalAmount.toStringAsFixed(2)}'),
          if (order.scheduleId != null || order.scheduleName != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('Schedule', order.scheduleName ?? order.scheduleId ?? 'N/A'),
          ],
          if (order.hubName != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow('HUB', order.hubName!),
          ],
          if (order.deliveryDate != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Delivery Date',
              '${DateFormat('dd MMM yyyy').format(order.deliveryDate!)}${order.deliveryTimeSlot != null ? ', ${order.deliveryTimeSlot}' : ''}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value),
      ],
    );
  }

  Widget _buildVerticalTimeline() {
    final timelineItems = _buildTimelineItems();
    
    return ListView.builder(
      itemCount: timelineItems.length,
      itemBuilder: (context, index) {
        final item = timelineItems[index];
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
                    color: item['completed'] ? item['color'].withOpacity(0.1) : Colors.grey[100],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: item['completed'] ? item['color'] : Colors.grey[300]!,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    item['icon'],
                    color: item['completed'] ? item['color'] : Colors.grey,
                    size: 20,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 50,
                    color: Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['label'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: item['completed'] ? item['color'] : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['time'] != null
                          ? DateFormat('dd MMM yyyy, HH:mm').format(item['time'])
                          : 'Pending',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> _buildTimelineItems() {
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
        'label': 'Confirmed',
        'time': order.confirmedAt,
        'icon': Icons.check_circle,
        'color': const Color(0xFF2196F3),
        'completed': true,
      });
    } else if (order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Confirmed',
        'time': null,
        'icon': Icons.check_circle_outline,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Packing Started
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

    // Packed
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

    // In Transit
    if (order.inTransitAt != null) {
      timelineItems.add({
        'label': 'In Transit',
        'time': order.inTransitAt,
        'icon': Icons.local_shipping,
        'color': const Color(0xFF9C27B0),
        'completed': true,
      });
    } else if (order.status == OrderStatus.in_transit) {
      timelineItems.add({
        'label': 'In Transit',
        'time': order.inTransitAt,
        'icon': Icons.local_shipping,
        'color': const Color(0xFF9C27B0),
        'completed': true,
      });
    } else if (order.status == OrderStatus.ready || order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'In Transit',
        'time': null,
        'icon': Icons.local_shipping_outlined,
        'color': Colors.grey,
        'completed': false,
      });
    }

    // Delivered
    if (order.deliveredAt != null) {
      timelineItems.add({
        'label': 'Delivered',
        'time': order.deliveredAt,
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.delivered) {
      timelineItems.add({
        'label': 'Delivered',
        'time': order.deliveredAt,
        'icon': Icons.check_circle,
        'color': const Color(0xFF4CAF50),
        'completed': true,
      });
    } else if (order.status == OrderStatus.in_transit || order.status == OrderStatus.ready || order.status == OrderStatus.preparing || order.status == OrderStatus.confirmed || order.status == OrderStatus.pending) {
      timelineItems.add({
        'label': 'Delivered',
        'time': null,
        'icon': Icons.check_circle_outline,
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

    return timelineItems;
  }

  Widget _buildOrderItems() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: order.items.length,
        itemBuilder: (context, index) {
          final item = order.items[index];
          return Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    item.productName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${item.quantity} ${item.unit}',
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${item.price.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${(item.quantity * item.price).toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
