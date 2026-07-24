import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/providers/schedule_cart_provider.dart';
import 'package:f2c/features/customer/providers/customer_providers.dart';
import 'package:f2c/features/customer/models/schedule_cart_model.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/customer/models/order_model.dart';

class CheckoutPageNew extends ConsumerStatefulWidget {
  const CheckoutPageNew({super.key});

  @override
  ConsumerState<CheckoutPageNew> createState() => _CheckoutPageNewState();
}

class _CheckoutPageNewState extends ConsumerState<CheckoutPageNew> {
  final _formKey = GlobalKey<FormState>();
  final _deliveryInstructionsController = TextEditingController();
  String _paymentMethod = 'cash_on_delivery';
  bool _isProcessing = false;
  Map<String, List<OrderModel>> _existingOrders = {};
  bool _isLoadingOrders = false;

  @override
  void initState() {
    super.initState();
    _loadExistingOrders();
  }

  Future<void> _loadExistingOrders() async {
    final customerAsync = ref.read(currentCustomerProvider);
    final customer = customerAsync.value;
    if (customer == null) return;

    setState(() => _isLoadingOrders = true);

    try {
      final carts = ref.read(scheduleCartsProvider);
      final existingOrdersMap = <String, List<OrderModel>>{};

      for (final cart in carts.values) {
        final ordersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: customer.id)
            .where('scheduleId', isEqualTo: cart.scheduleId)
            .where('status', isEqualTo: 'pending')
            .where('isDeleted', isEqualTo: false)
            .get();

        final orders = ordersSnapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .where((order) {
              if (order.deliveryDate == null) return false;
              final orderDate = DateTime(
                order.deliveryDate!.year,
                order.deliveryDate!.month,
                order.deliveryDate!.day,
              );
              final cartDate = DateTime(
                cart.deliveryDate.year,
                cart.deliveryDate.month,
                cart.deliveryDate.day,
              );
              return orderDate.isAtSameMomentAs(cartDate) && order.isEditable;
            })
            .toList();

        if (orders.isNotEmpty) {
          existingOrdersMap[cart.scheduleId] = orders;
        }
      }

      setState(() => _existingOrders = existingOrdersMap);
    } catch (e) {
      print('Error loading existing orders: $e');
    } finally {
      setState(() => _isLoadingOrders = false);
    }
  }

  @override
  void dispose() {
    _deliveryInstructionsController.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final carts = ref.watch(scheduleCartsProvider);
    final customerAsync = ref.watch(currentCustomerProvider);
    final modifiableCarts = carts.values.where((cart) => cart.canModify).toList()
      ..sort((a, b) => a.cutoffDateTime.compareTo(b.cutoffDateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          if (modifiableCarts.isEmpty) {
            return _buildEmptyCheckout();
          }

          if (_isLoadingOrders) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildCheckoutContent(context, customer, modifiableCarts);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildEmptyCheckout() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items to checkout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All items are past their cutoff time',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
              ),
              child: const Text('Back to Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutContent(
    BuildContext context,
    dynamic customer,
    List<ScheduleCartModel> carts,
  ) {
    final isMobile = _isMobile(context);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: isMobile
                  ? _buildMobileLayout(customer, carts)
                  : _buildDesktopLayout(customer, carts),
            ),
          ),
          _buildCheckoutFooter(carts),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(dynamic customer, List<ScheduleCartModel> carts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomerInfo(customer),
        const SizedBox(height: 24),
        _buildOrderSummary(carts),
        const SizedBox(height: 24),
        _buildDeliveryInstructions(),
        const SizedBox(height: 24),
        _buildPaymentMethod(),
      ],
    );
  }

  Widget _buildDesktopLayout(dynamic customer, List<ScheduleCartModel> carts) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomerInfo(customer),
              const SizedBox(height: 24),
              _buildDeliveryInstructions(),
              const SizedBox(height: 24),
              _buildPaymentMethod(),
            ],
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 1,
          child: _buildOrderSummary(carts),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(dynamic customer) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Customer Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.person_outline, 'Name', customer.name),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email_outlined, 'Email', customer.email),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone_outlined, 'Phone', customer.phone),
            if (customer.alternativePhone != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(Icons.phone_outlined, 'Alt Phone', customer.alternativePhone!),
            ],
            const SizedBox(height: 12),
            _buildInfoRow(Icons.apartment, 'Apartment', customer.apartmentName),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on_outlined, 'Address', customer.address),
          ],
        ),
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
              const SizedBox(height: 2),
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

  Widget _buildOrderSummary(List<ScheduleCartModel> carts) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Order Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Each schedule will be processed as a separate order',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const Divider(height: 24),
            ...carts.map((cart) => _buildScheduleCartSummary(cart)),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCartSummary(ScheduleCartModel cart) {
    final existingOrders = _existingOrders[cart.scheduleId];
    final hasExistingOrder = existingOrders != null && existingOrders.isNotEmpty;
    final existingOrder = hasExistingOrder ? existingOrders.first : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasExistingOrder ? Colors.orange : const Color(0xFF4CAF50),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (hasExistingOrder ? Colors.orange : const Color(0xFF4CAF50)).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (hasExistingOrder ? Colors.orange : const Color(0xFF4CAF50)).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasExistingOrder ? Icons.merge : Icons.calendar_today,
                  size: 20,
                  color: hasExistingOrder ? Colors.orange : const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.scheduleName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasExistingOrder ? 'Merging with existing order' : 'New Order',
                      style: TextStyle(
                        fontSize: 11,
                        color: hasExistingOrder ? Colors.orange[700] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.local_shipping, size: 16, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Delivery: ${DateFormat('EEE, dd MMM yyyy').format(cart.deliveryDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Time: ${cart.deliveryTime}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.edit_calendar, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Editable until: ${DateFormat('dd MMM, hh:mm a').format(cart.cutoffDateTime)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          
          // Show existing order items if merging
          if (hasExistingOrder && existingOrder != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200] ?? Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Existing Order Items',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...existingOrder.items.map((item) => _buildExistingItemRow(item, cart)),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // New cart items
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200] ?? Colors.green),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_shopping_cart, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      hasExistingOrder ? 'New Items to Add' : 'Cart Items',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...cart.items.values.map((item) => _buildCartItemRow(item, cart)),
              ],
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Total',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (hasExistingOrder && existingOrder != null)
                    Text(
                      'Existing: ₹${existingOrder.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${cart.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                  if (hasExistingOrder && existingOrder != null)
                    Text(
                      'Merged: ₹${(existingOrder.totalAmount + cart.totalAmount).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemRow(CartItemModel item, ScheduleCartModel cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedQuantity} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: Colors.red,
                onPressed: () {
                  ref.read(scheduleCartsProvider.notifier).decrementQuantity(cart.scheduleId, item.productId);
                },
              ),
              Text(
                item.formattedQuantity,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                color: const Color(0xFF4CAF50),
                onPressed: () {
                  ref.read(scheduleCartsProvider.notifier).incrementQuantity(cart.scheduleId, item.productId);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: Colors.grey[600],
                onPressed: () {
                  ref.read(scheduleCartsProvider.notifier).removeItem(cart.scheduleId, item.productId);
                },
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExistingItemRow(OrderItem item, ScheduleCartModel cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200] ?? Colors.orange),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.formattedQuantity} × ₹${item.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: Colors.orange[700],
                onPressed: () {
                  _showRemoveExistingItemDialog(item, cart);
                },
                tooltip: 'Remove from existing order',
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.formattedQuantity,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Text(
            '₹${item.totalPrice.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveExistingItemDialog(OrderItem item, ScheduleCartModel cart) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item from Existing Order'),
        content: Text('Are you sure you want to remove ${item.productName} from your existing order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Remove item from existing order
      try {
        final existingOrders = _existingOrders[cart.scheduleId];
        if (existingOrders != null && existingOrders.isNotEmpty) {
          final existingOrder = existingOrders.first;
          final orderRef = FirebaseFirestore.instance.collection('orders').doc(existingOrder.id);
          
          final updatedItems = existingOrder.items.where((i) => i.productId != item.productId).toList();
          final newTotal = updatedItems.fold(0.0, (sum, i) => sum + i.totalPrice);
          
          await orderRef.update({
            'items': updatedItems.map((i) => i.toJson()).toList(),
            'totalAmount': newTotal,
          });
          
          // Reload orders
          await _loadExistingOrders();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Item removed from existing order'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  Widget _buildDeliveryInstructions() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.note_alt_outlined,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Delivery Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deliveryInstructionsController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Add any special instructions for delivery (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Color(0xFF4CAF50),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentOption(
              'cash_on_delivery',
              'Cash on Delivery',
              Icons.money,
              'Pay when you receive your order',
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              'online',
              'Online Payment',
              Icons.credit_card,
              'Pay now using UPI, Card, or Net Banking',
              isComingSoon: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(
    String value,
    String title,
    IconData icon,
    String subtitle, {
    bool isComingSoon = false,
  }) {
    final isSelected = _paymentMethod == value;

    return InkWell(
      onTap: isComingSoon ? null : () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? const Color(0xFF4CAF50).withOpacity(0.05)
              : isComingSoon
                  ? Colors.grey[100]
                  : Colors.white,
        ),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _paymentMethod,
              onChanged: isComingSoon ? null : (val) => setState(() => _paymentMethod = val!),
              activeColor: const Color(0xFF4CAF50),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: isComingSoon
                  ? Colors.grey
                  : isSelected
                      ? const Color(0xFF4CAF50)
                      : Colors.grey[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isComingSoon ? Colors.grey : Colors.black87,
                        ),
                      ),
                      if (isComingSoon) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Coming Soon',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[900],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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

  Widget _buildCheckoutFooter(List<ScheduleCartModel> carts) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${carts.length} separate order${carts.length > 1 ? 's' : ''} will be created',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : () => _placeOrder(carts),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Place Orders',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${carts.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _placeOrder(List<ScheduleCartModel> carts) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final customerAsync = ref.read(currentCustomerProvider);
      final customer = customerAsync.value;

      if (customer == null) {
        throw Exception('Customer not found');
      }

      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();

      // Check for existing pending orders for each schedule
      for (final cart in carts) {
        // Query for existing pending order with same schedule and delivery date
        final existingOrdersSnapshot = await FirebaseFirestore.instance
            .collection('orders')
            .where('customerId', isEqualTo: customer.id)
            .where('scheduleId', isEqualTo: cart.scheduleId)
            .where('status', isEqualTo: 'pending')
            .where('isDeleted', isEqualTo: false)
            .get();

        // Filter by delivery date (Firestore doesn't support multiple where clauses on different fields easily)
        final existingOrders = existingOrdersSnapshot.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .where((order) {
              if (order.deliveryDate == null) return false;
              final orderDate = DateTime(
                order.deliveryDate!.year,
                order.deliveryDate!.month,
                order.deliveryDate!.day,
              );
              final cartDate = DateTime(
                cart.deliveryDate.year,
                cart.deliveryDate.month,
                cart.deliveryDate.day,
              );
              return orderDate.isAtSameMomentAs(cartDate) && 
                     order.isEditable; // Only merge if still editable
            })
            .toList();

        if (existingOrders.isNotEmpty) {
          // Merge with existing order
          final existingOrder = existingOrders.first;
          final orderRef = FirebaseFirestore.instance.collection('orders').doc(existingOrder.id);

          // Merge items - combine quantities if same product, add new items
          final Map<String, OrderItem> mergedItems = {};
          
          // Add existing items
          for (final item in existingOrder.items) {
            mergedItems[item.productId] = item;
          }
          
          // Add/merge new items
          for (final cartItem in cart.items.values) {
            if (mergedItems.containsKey(cartItem.productId)) {
              // Same product - add quantities
              final existingItem = mergedItems[cartItem.productId]!;
              mergedItems[cartItem.productId] = existingItem.copyWith(
                quantity: existingItem.quantity + cartItem.quantity,
              );
            } else {
              // New product - add to order
              mergedItems[cartItem.productId] = OrderItem(
                productId: cartItem.productId,
                productName: cartItem.productName,
                productCategory: cartItem.productCategory,
                price: cartItem.price,
                unit: cartItem.unit,
                imageUrl: cartItem.imageUrl,
                quantity: cartItem.quantity,
                farmerId: cartItem.farmerId,
                farmerName: cartItem.farmerName,
              );
            }
          }

          // Calculate new total
          final newTotal = mergedItems.values.fold(
            0.0,
            (sum, item) => sum + item.totalPrice,
          );

          // Update existing order
          final updatedOrder = existingOrder.copyWith(
            items: mergedItems.values.toList(),
            totalAmount: newTotal,
            deliveryInstructions: _deliveryInstructionsController.text.trim().isEmpty
                ? existingOrder.deliveryInstructions
                : _deliveryInstructionsController.text.trim(),
          );

          batch.update(orderRef, updatedOrder.toFirestore());
        } else {
          // Create new order
          final orderRef = FirebaseFirestore.instance.collection('orders').doc();

          final order = OrderModel(
            id: orderRef.id,
            customerId: customer.id,
            customerName: customer.name,
            customerEmail: customer.email,
            apartmentId: customer.apartmentId,
            apartmentName: customer.apartmentName,
            scheduleId: cart.scheduleId,
            scheduleName: cart.scheduleName,
            deliveryDate: cart.deliveryDate,
            deliveryTimeSlot: cart.deliveryTime,
            cutoffDateTime: cart.cutoffDateTime,
            hubName: cart.hubName,
            items: cart.items.values
                .map((item) => OrderItem(
                      productId: item.productId,
                      productName: item.productName,
                      productCategory: item.productCategory,
                      price: item.price,
                      unit: item.unit,
                      imageUrl: item.imageUrl,
                      quantity: item.quantity,
                      farmerId: item.farmerId,
                      farmerName: item.farmerName,
                    ))
                .toList(),
            totalAmount: cart.totalAmount,
            status: OrderStatus.pending,
            createdAt: now,
            scheduledDate: cart.deliveryDate,
            deliveryInstructions: _deliveryInstructionsController.text.trim().isEmpty
                ? null
                : _deliveryInstructionsController.text.trim(),
            paymentMethod: _paymentMethod,
            paymentStatus: _paymentMethod == 'cash_on_delivery' ? 'pending' : 'paid',
            canEdit: true,
          );

          batch.set(orderRef, order.toFirestore());
        }
      }

      await batch.commit();

      // Clear the carts
      ref.read(scheduleCartsProvider.notifier).clearAll();

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Order Placed Successfully!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your items have been added to your order${carts.length > 1 ? 's' : ''}:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...carts.map((cart) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Color(0xFF4CAF50)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${cart.scheduleName} - ₹${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Items added to existing orders will be combined. You can edit until cutoff time.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.pop(context); // Go back to dashboard
              },
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Continue Shopping'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      print('Error placing order: $e');
      print('Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Error Details'),
                  content: SingleChildScrollView(
                    child: Text(e.toString()),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }
}
