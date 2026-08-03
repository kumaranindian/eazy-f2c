import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/models/bill_model.dart';
import 'package:f2c/features/customer/services/bill_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class WhatsAppNotificationService {
  final BillService _billService = BillService();

  /// Send WhatsApp notification for packed order
  /// This opens WhatsApp Web with pre-filled message
  Future<bool> sendPackedOrderNotification({
    required OrderModel order,
    required String customerPhone,
    required String customerName,
    bool includeBill = true,
  }) async {
    try {
      // Get bill if requested
      BillModel? bill;
      if (includeBill) {
        bill = await _billService.getBillByOrderId(order.id);
      }

      // Format phone number (remove spaces, dashes, and add country code if needed)
      String formattedPhone = _formatPhoneNumber(customerPhone);

      // Create message
      String message = _createPackedOrderMessage(
        order: order,
        customerName: customerName,
        bill: bill,
      );

      // Encode message for URL
      String encodedMessage = Uri.encodeComponent(message);

      // Create WhatsApp URL
      String whatsappUrl = 'https://wa.me/$formattedPhone?text=$encodedMessage';

      // Launch WhatsApp
      final uri = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        
        // Log notification
        await _logNotification(
          orderId: order.id,
          customerId: order.customerId,
          phone: formattedPhone,
          messageType: 'packed_order',
          includedBill: includeBill,
        );
        
        return true;
      } else {
        throw Exception('Could not launch WhatsApp');
      }
    } catch (e) {
      print('Error sending WhatsApp notification: $e');
      return false;
    }
  }

  /// Format phone number for WhatsApp
  String _formatPhoneNumber(String phone) {
    // Remove all non-numeric characters
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Add country code if not present (assuming India +91)
    if (!cleaned.startsWith('91') && cleaned.length == 10) {
      cleaned = '91$cleaned';
    }
    
    return cleaned;
  }

  /// Create message for packed order
  String _createPackedOrderMessage({
    required OrderModel order,
    required String customerName,
    BillModel? bill,
  }) {
    final deliveryDate = order.deliveryDate ?? order.createdAt;
    final dateStr = DateFormat('dd MMM yyyy').format(deliveryDate);
    
    StringBuffer message = StringBuffer();
    
    // Greeting
    message.writeln('🌾 *F2C - Farm2Community*');
    message.writeln('');
    message.writeln('Dear $customerName,');
    message.writeln('');
    
    // Order status
    message.writeln('✅ Your order has been *PACKED* and is ready for delivery!');
    message.writeln('');
    
    // Order details
    message.writeln('📦 *Order Details:*');
    message.writeln('Order ID: #${order.id.substring(0, 8).toUpperCase()}');
    message.writeln('Delivery Date: $dateStr');
    message.writeln('Schedule: ${order.scheduleName}');
    message.writeln('');
    
    // Items
    message.writeln('🛒 *Items:*');
    for (var item in order.items) {
      message.writeln('• ${item.productName} - ${item.quantity} ${item.unit}');
    }
    message.writeln('');
    
    // Bill information
    if (bill != null) {
      message.writeln('💰 *Bill Summary:*');
      message.writeln('Subtotal: ₹${bill.finalSubtotal.toStringAsFixed(2)}');
      
      if (bill.deliveryCharges > 0) {
        message.writeln('Delivery Charges: ₹${bill.deliveryCharges.toStringAsFixed(2)}');
      }
      
      if (bill.cleaningCharges > 0) {
        message.writeln('Cleaning Charges: ₹${bill.cleaningCharges.toStringAsFixed(2)}');
      }
      
      message.writeln('*Total: ₹${bill.finalTotal.toStringAsFixed(2)}*');
      
      // Variation note
      if (bill.hasVariations) {
        message.writeln('');
        message.writeln('ℹ️ *Note:* Some items had slight variations in weight/quantity during packaging.');
        if (bill.totalVariation != null && bill.totalVariation! != 0) {
          final variationText = bill.totalVariation! > 0 
              ? 'Additional ₹${bill.totalVariation!.toStringAsFixed(2)}'
              : 'Discount ₹${(-bill.totalVariation!).toStringAsFixed(2)}';
          message.writeln('Variation: $variationText');
        }
      }
      
      message.writeln('');
      message.writeln('Payment Status: ${_getPaymentStatusEmoji(bill.paymentStatus)} ${bill.paymentStatus.toUpperCase()}');
    } else {
      message.writeln('💰 *Amount:*');
      message.writeln('Total: ₹${order.grandTotal.toStringAsFixed(2)}');
      message.writeln('Payment: ${order.paymentStatus?.toUpperCase() ?? "PENDING"}');
    }
    
    message.writeln('');
    
    // Delivery instructions
    if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty) {
      message.writeln('📝 *Delivery Instructions:*');
      message.writeln(order.deliveryInstructions);
      message.writeln('');
    }
    
    // Footer
    message.writeln('Thank you for choosing F2C! 🌱');
    message.writeln('Fresh from Farm to Your Community');
    
    return message.toString();
  }

  /// Get payment status emoji
  String _getPaymentStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return '✅';
      case 'pending':
        return '⏳';
      case 'failed':
        return '❌';
      default:
        return '❓';
    }
  }

  /// Log notification to Firestore
  Future<void> _logNotification({
    required String orderId,
    required String customerId,
    required String phone,
    required String messageType,
    required bool includedBill,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'orderId': orderId,
        'customerId': customerId,
        'phone': phone,
        'messageType': messageType,
        'channel': 'whatsapp',
        'includedBill': includedBill,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'sent',
      });
    } catch (e) {
      print('Error logging notification: $e');
    }
  }

  /// Send bulk notifications for multiple orders
  /// Note: This requires customer phone numbers to be fetched from Firestore
  Future<Map<String, dynamic>> sendBulkNotifications({
    required List<OrderModel> orders,
    required Map<String, String> customerPhones, // Map of customerId to phone
    bool includeBill = true,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    List<String> failedOrders = [];

    for (var order in orders) {
      // Add delay between messages to avoid spam detection
      if (successCount > 0) {
        await Future.delayed(const Duration(seconds: 2));
      }

      // Get customer phone from map
      final phone = customerPhones[order.customerId];
      if (phone == null || phone.isEmpty) {
        failureCount++;
        failedOrders.add(order.id);
        continue;
      }

      final success = await sendPackedOrderNotification(
        order: order,
        customerPhone: phone,
        customerName: order.customerName,
        includeBill: includeBill,
      );

      if (success) {
        successCount++;
      } else {
        failureCount++;
        failedOrders.add(order.id);
      }
    }

    return {
      'total': orders.length,
      'success': successCount,
      'failure': failureCount,
      'failedOrders': failedOrders,
    };
  }
}
