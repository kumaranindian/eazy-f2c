import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/customer/providers/customer_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  String _selectedPaymentMethod = 'Cash on Delivery';
  String _deliveryInstructions = '';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final customerAsync = ref.watch(currentCustomerProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (cart.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Checkout'),
          backgroundColor: const Color(0xFF00C853),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                ),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      );
    }

    return customerAsync.when(
      data: (customer) {
        if (customer == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final totalAmount = cart.values.fold(0.0, (sum, item) => sum + item.totalPrice);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Checkout'),
            backgroundColor: const Color(0xFF00C853),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Delivery Information
                _buildDeliveryInfo(customer, isMobile),
                
                // Order Items
                _buildOrderItems(cart, isMobile),
                
                // Payment Method
                _buildPaymentMethod(isMobile),
                
                // Delivery Instructions
                _buildDeliveryInstructions(isMobile),
                
                // Order Summary
                _buildOrderSummary(totalAmount, isMobile),
                
                // Place Order Button
                _buildPlaceOrderButton(customer, totalAmount, isMobile),
                
                SizedBox(height: isMobile ? 100 : 32),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo(customer, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Information',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.person, 'Name', customer.name),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.email, 'Email', customer.email),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.location_on, 'Apartment', customer.apartmentName),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.phone, 'Phone', customer.phoneNumber ?? 'Not provided'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(Map<String, CartItemModel> cart, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Items',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          ...cart.values.map((item) => _buildOrderItemCard(item, isMobile)),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(CartItemModel item, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl,
              width: isMobile ? 60 : 80,
              height: isMobile ? 60 : 80,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: isMobile ? 60 : 80,
                height: isMobile ? 60 : 80,
                color: Colors.grey[200],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                width: isMobile ? 60 : 80,
                height: isMobile ? 60 : 80,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.farmerName ?? 'Unknown Farmer',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${item.price.toStringAsFixed(0)}/${item.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00C853),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${item.formattedQuantity} ${item.unit}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF00C853),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethod(bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Method',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          RadioListTile<String>(
            title: const Text('Cash on Delivery'),
            subtitle: const Text('Pay when you receive your order'),
            value: 'Cash on Delivery',
            groupValue: _selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
            activeColor: const Color(0xFF00C853),
          ),
          RadioListTile<String>(
            title: const Text('UPI Payment'),
            subtitle: const Text('Pay using UPI apps'),
            value: 'UPI',
            groupValue: _selectedPaymentMethod,
            onChanged: (value) {
              setState(() {
                _selectedPaymentMethod = value!;
              });
            },
            activeColor: const Color(0xFF00C853),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryInstructions(bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delivery Instructions (Optional)',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Add any special instructions for delivery...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (value) {
              _deliveryInstructions = value;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double totalAmount, bool isMobile) {
    return Container(
      margin: EdgeInsets.all(isMobile ? 16 : 24),
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Summary',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', totalAmount),
          const SizedBox(height: 8),
          _buildSummaryRow('Delivery Fee', 0.0),
          const Divider(height: 24),
          _buildSummaryRow(
            'Total',
            totalAmount,
            isBold: true,
            color: const Color(0xFF00C853),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? Colors.black87,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceOrderButton(customer, double totalAmount, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isProcessing ? null : () => _placeOrder(customer, totalAmount),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00C853),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(
                  'Place Order - ₹${totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _placeOrder(customer, double totalAmount) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final cart = ref.read(cartProvider);
      final user = ref.read(currentUserProvider).value;
      
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Create order items from cart
      final orderItems = cart.values.map((item) => OrderItem(
        productId: item.productId,
        productName: item.productName,
        productCategory: item.productCategory,
        price: item.price,
        unit: item.unit,
        imageUrl: item.imageUrl,
        quantity: item.quantity,
        farmerId: item.farmerId,
        farmerName: item.farmerName,
      )).toList();

      // Create order
      final order = OrderModel(
        id: '', // Will be set by Firestore
        customerId: customer.id,
        customerName: customer.name,
        customerEmail: customer.email,
        apartmentId: customer.apartmentId,
        apartmentName: customer.apartmentName,
        items: orderItems,
        totalAmount: totalAmount,
        status: OrderStatus.pending,
        createdAt: DateTime.now(),
        scheduledDate: DateTime.now(),
        deliveryAddress: customer.address,
        deliveryInstructions: _deliveryInstructions.isNotEmpty ? _deliveryInstructions : null,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: 'pending',
      );

      // Save to Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('orders')
          .add(order.toFirestore());

      // Clear cart
      ref.read(cartProvider.notifier).clear();

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00C853), size: 32),
                SizedBox(width: 12),
                Text('Order Placed Successfully!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Order ID: ${docRef.id}'),
                const SizedBox(height: 8),
                Text('Total Amount: ₹${totalAmount.toStringAsFixed(0)}'),
                const SizedBox(height: 8),
                const Text('Your order will be delivered soon.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to dashboard
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
