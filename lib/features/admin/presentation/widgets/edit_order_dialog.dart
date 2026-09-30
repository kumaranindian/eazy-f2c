import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:f2c/core/utils/image_url_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/providers/product_providers.dart';
import 'package:f2c/features/customer/services/bill_service.dart';

class EditOrderDialog extends ConsumerStatefulWidget {
  final OrderModel order;

  const EditOrderDialog({super.key, required this.order});

  @override
  ConsumerState<EditOrderDialog> createState() => _EditOrderDialogState();
}

class _EditOrderDialogState extends ConsumerState<EditOrderDialog> {
  late List<OrderItem> _items;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.order.items);
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final horizontalInset = isMobile ? 16.0 : 40.0;
    // Desktop keeps the existing 900px-wide, 700px-tall dialog; mobile uses
    // almost the full viewport with safe margins instead of the old fixed
    // size, which was wider and taller than most phone viewports.
    final maxDialogWidth = isMobile
        ? screenSize.width - horizontalInset * 2
        : math.min(900.0, screenSize.width - horizontalInset * 2);
    final maxDialogHeight = math.min(700.0, screenSize.height * 0.9);

    final saveButton = ElevatedButton(
      onPressed: _isSaving ? null : _saveChanges,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 12 : 16,
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text('Save Changes'),
    );

    final totalsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subtotal: ₹${_calculateSubtotal().toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14),
        ),
        if (widget.order.deliveryCharges > 0)
          Text(
            'Delivery Charges: ₹${widget.order.deliveryCharges.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14),
          ),
        if (widget.order.cleaningCharges > 0)
          Text(
            'Cleaning Charges: ₹${widget.order.cleaningCharges.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 14),
          ),
        const SizedBox(height: 8),
        Text(
          'Grand Total: ₹${_calculateGrandTotal().toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF4CAF50),
          ),
        ),
      ],
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit, color: Color(0xFF2196F3)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Edit Order #${widget.order.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Customer: ${widget.order.customerName}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Order Items Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Order Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showAddProductDialog(productsAsync),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4CAF50),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No items in order',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                return _buildItemCard(
                                  _items[index],
                                  index,
                                  isMobile,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),

              const Divider(),
              const SizedBox(height: 16),

              // Summary and Actions
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    totalsColumn,
                    const SizedBox(height: 16),
                    saveButton,
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: totalsColumn),
                    const SizedBox(width: 24),
                    saveButton,
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(OrderItem item, int index, bool isMobile) {
    // A larger minimum tap target than the icons' visual size, so +/- are
    // comfortable to tap on a touch screen without changing their look.
    const stepButtonConstraints = BoxConstraints(minWidth: 40, minHeight: 40);

    final productInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.productName,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.productCategory,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        if (item.farmerName != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.agriculture, size: 12, color: Colors.green[700]),
              const SizedBox(width: 4),
              Text(
                item.farmerName!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
        ],
      ],
    );

    final quantityControl = Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => _decrementQuantity(index),
            padding: const EdgeInsets.all(8),
            constraints: stepButtonConstraints,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              item.formattedQuantity,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => _incrementQuantity(index),
            padding: const EdgeInsets.all(8),
            constraints: stepButtonConstraints,
          ),
        ],
      ),
    );

    if (isMobile) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: productInfo),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _removeItem(index),
                    tooltip: 'Remove',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  quantityControl,
                  const Spacer(),
                  Text(
                    '₹${item.price.toStringAsFixed(2)} each',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Total: ₹${item.totalPrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(flex: 3, child: productInfo),
            const SizedBox(width: 16),
            quantityControl,
            const SizedBox(width: 16),

            // Price
            SizedBox(
              width: 80,
              child: Text(
                '₹${item.price.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 16),

            // Total
            SizedBox(
              width: 100,
              child: Text(
                '₹${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50),
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 16),

            // Remove Button
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _removeItem(index),
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  void _incrementQuantity(int index) {
    setState(() {
      final item = _items[index];
      _items[index] = item.copyWith(
        quantity: item.quantity + item.quantityIncrement,
      );
    });
  }

  void _decrementQuantity(int index) {
    setState(() {
      final item = _items[index];
      final newQuantity = item.quantity - item.quantityIncrement;
      if (newQuantity > 0) {
        _items[index] = item.copyWith(quantity: newQuantity);
      }
    });
  }

  void _removeItem(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Are you sure you want to remove ${_items[index].productName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _items.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showAddProductDialog(AsyncValue<List<ProductModel>> productsAsync) {
    productsAsync.when(
      data: (products) {
        showDialog(
          context: context,
          builder: (context) => _AddProductDialog(
            products: products,
            onProductAdded: (product, quantity) {
              setState(() {
                _items.add(OrderItem(
                  productId: product.id,
                  productName: product.name,
                  productCategory: product.category,
                  price: product.price,
                  unit: product.unit,
                  imageUrl: product.imageUrl ?? '',
                  quantity: quantity,
                  farmerId: product.farmerId,
                  farmerName: null, // Will be populated from order context if needed
                ));
              });
            },
          ),
        );
      },
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading products...')),
        );
      },
      error: (error, stack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading products: $error')),
        );
      },
    );
  }

  double _calculateSubtotal() {
    return _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateGrandTotal() {
    return _calculateSubtotal() + 
           widget.order.deliveryCharges + 
           widget.order.cleaningCharges;
  }

  Future<void> _saveChanges() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order must have at least one item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(widget.order.id);
      final currentUser = FirebaseAuth.instance.currentUser;
      
      final updatedOrder = widget.order.copyWith(
        items: _items,
        totalAmount: _calculateSubtotal(),
      );

      // Update the order
      await orderRef.update(updatedOrder.toFirestore());

      // Regenerate the bill with updated order items
      final billService = BillService();
      await billService.regenerateBillFromOrder(
        orderId: widget.order.id,
        updatedOrder: updatedOrder,
        updatedBy: currentUser?.uid ?? 'admin',
      );

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order and bill updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _AddProductDialog extends StatefulWidget {
  final List<ProductModel> products;
  final Function(ProductModel, double) onProductAdded;

  const _AddProductDialog({
    required this.products,
    required this.onProductAdded,
  });

  @override
  State<_AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<_AddProductDialog> {
  ProductModel? _selectedProduct;
  double _quantity = 1.0;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredProducts = widget.products.where((product) {
      if (_searchQuery.isEmpty) return true;
      return product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             product.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final horizontalInset = isMobile ? 16.0 : 40.0;
    final maxDialogWidth = isMobile
        ? screenSize.width - horizontalInset * 2
        : math.min(600.0, screenSize.width - horizontalInset * 2);
    final maxDialogHeight = math.min(500.0, screenSize.height * 0.9);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxDialogWidth,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.add_shopping_cart, color: Color(0xFF4CAF50)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add Product',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            
            // Product List
            Expanded(
              child: ListView.builder(
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final isSelected = _selectedProduct?.id == product.id;
                  
                  return Card(
                    color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : null,
                    child: ListTile(
                      leading: product.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ImageUrlHelper.getSafeImageUrl(product.imageUrl),
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.image_not_supported),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.shopping_bag),
                            ),
                      title: Text(product.name),
                      subtitle: Text('${product.category} • ₹${product.price.toStringAsFixed(2)}/${product.unit}'),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Color(0xFF4CAF50))
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedProduct = product;
                          _quantity = 1.0;
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            
            if (_selectedProduct != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Builder(builder: (context) {
                final nameAndPrice = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedProduct!.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '₹${_selectedProduct!.price.toStringAsFixed(2)} per ${_selectedProduct!.unit}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                );

                final quantityStepper = Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          setState(() {
                            if (_quantity > 0.25) _quantity -= 0.25;
                          });
                        },
                      ),
                      Text(
                        _quantity.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          setState(() {
                            _quantity += 0.25;
                          });
                        },
                      ),
                    ],
                  ),
                );

                final addButton = ElevatedButton(
                  onPressed: () {
                    widget.onProductAdded(_selectedProduct!, _quantity);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Add to Order'),
                );

                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      nameAndPrice,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          quantityStepper,
                          const Spacer(),
                          addButton,
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: nameAndPrice),
                    const SizedBox(width: 16),
                    quantityStepper,
                    const SizedBox(width: 16),
                    addButton,
                  ],
                );
              },
              ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
