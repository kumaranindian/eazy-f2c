import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:f2c/features/customer/presentation/widgets/bill_view_dialog.dart';
import 'package:f2c/features/admin/services/whatsapp_notification_service.dart';

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
                // Show WhatsApp button only for ready/in_transit/delivered orders
                if (order.status == OrderStatus.ready || 
                    order.status == OrderStatus.in_transit || 
                    order.status == OrderStatus.delivered)
                  ElevatedButton.icon(
                    onPressed: () => _sendWhatsAppNotification(context),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('WhatsApp'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp green
                      foregroundColor: Colors.white,
                    ),
                  ),
                if (order.status == OrderStatus.ready || 
                    order.status == OrderStatus.in_transit || 
                    order.status == OrderStatus.delivered)
                  const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _viewBill(context),
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text('View Bill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
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
                    item.formattedQuantity,
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '₹${item.price.toStringAsFixed(2)}/${item.unit}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12),
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

  Future<void> _viewBill(BuildContext context) async {
    try {
      final billService = BillService();
      final bill = await billService.getBillByOrderId(order.id);
      
      if (bill == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bill not found for this order'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => BillViewDialog(bill: bill),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading bill: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendWhatsAppNotification(BuildContext context) async {
    // Get customer phone from Firestore
    String? customerPhone;
    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(order.customerId)
          .get();
      
      if (customerDoc.exists) {
        customerPhone = customerDoc.data()?['phone'] as String?;
      }
    } catch (e) {
      print('Error fetching customer phone: $e');
    }

    // Show confirmation dialog with options
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.send, color: Color(0xFF25D366)),
            SizedBox(width: 12),
            Text('Send WhatsApp Notification'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send order notification to ${order.customerName}?'),
            const SizedBox(height: 16),
            Text(
              'Phone: ${customerPhone ?? "Not available"}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            const Text(
              'The message will include:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            const Text('• Order status and details', style: TextStyle(fontSize: 12)),
            const Text('• Items list', style: TextStyle(fontSize: 12)),
            const Text('• Bill summary (if available)', style: TextStyle(fontSize: 12)),
            const Text('• Delivery information', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != true || !context.mounted) return;

    // Check if phone number is available
    if (customerPhone == null || customerPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Opening WhatsApp...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      // Send notification
      final whatsappService = WhatsAppNotificationService();
      final success = await whatsappService.sendPackedOrderNotification(
        order: order,
        customerPhone: customerPhone,
        customerName: order.customerName,
        includeBill: true,
      );

      if (!context.mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('WhatsApp opened successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF25D366),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open WhatsApp'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
