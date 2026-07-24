import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/admin/providers/product_providers.dart';
import 'package:f2c/features/admin/providers/operational_schedule_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

class ProductPricing {
  final double price;
  final double profitMargin;

  ProductPricing({required this.price, required this.profitMargin});
}

class UpdateOperationalScheduleDialog extends ConsumerStatefulWidget {
  const UpdateOperationalScheduleDialog({
    super.key,
    required this.schedule,
  });

  final OperationalScheduleModel schedule;

  @override
  ConsumerState<UpdateOperationalScheduleDialog> createState() =>
      _UpdateOperationalScheduleDialogState();
}

class _UpdateOperationalScheduleDialogState
    extends ConsumerState<UpdateOperationalScheduleDialog> {
  final List<ScheduleProductItem> _pendingProducts = [];
  String? _selectedFarmerId;
  final Map<String, ProductPricing> _productPricing = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _profitControllers = {};
  bool _isUpdating = false;

  @override
  void dispose() {
    _priceControllers.forEach((_, controller) => controller.dispose());
    _profitControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farmersAsync = ref.watch(farmersStreamProvider);
    final productsAsync = ref.watch(productsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Update Schedule - Add Farmers & Products',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.schedule.scheduleName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.schedule.branchName} - ${widget.schedule.hubName}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Existing products
                  Expanded(
                    child: _buildExistingProductsSection(),
                  ),
                  const SizedBox(width: 24),
                  // Right: Add new products
                  Expanded(
                    child: _buildAddProductsSection(farmersAsync, productsAsync),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isUpdating || _pendingProducts.isEmpty ? null : _updateSchedule,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add to Schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingProductsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.grey[700]),
            const SizedBox(width: 8),
            const Text(
              'Existing Farmers & Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Existing items cannot be removed. Add new items on the right.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _buildExistingProductsList(),
        ),
      ],
    );
  }

  Widget _buildExistingProductsList() {
    final products = widget.schedule.products;
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No existing products in this schedule',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final grouped = <String, List<ScheduleProductItem>>{};
    for (final product in products) {
      final farmerName = product.farmerName ?? 'Unknown Farmer';
      grouped.putIfAbsent(farmerName, () => []).add(product);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final entry = grouped.entries.elementAt(index);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.agriculture, size: 18, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...entry.value.map((product) => Padding(
                    padding: const EdgeInsets.only(left: 26, bottom: 4),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: Colors.grey[500]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            product.productName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                        Text(
                          '₹${product.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )),
              if (index < grouped.length - 1) const Divider(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddProductsSection(
    AsyncValue<List<FarmerModel>> farmersAsync,
    AsyncValue<List<ProductModel>> productsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.add_circle_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text(
              'Add New Farmers & Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        farmersAsync.when(
          data: (farmers) {
            final activeFarmers = farmers
                .where((f) => f.isActive && !f.isDeleted)
                .toList();
            return DropdownButtonFormField<String?>(
              value: _selectedFarmerId,
              decoration: const InputDecoration(
                labelText: 'Select Farmer',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.agriculture),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Choose a farmer'),
                ),
                ...activeFarmers.map((farmer) => DropdownMenuItem(
                  value: farmer.id,
                  child: Text(farmer.name),
                )),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedFarmerId = value;
                  _productPricing.clear();
                });
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error: $error'),
        ),
        const SizedBox(height: 16),
        if (_selectedFarmerId != null)
          productsAsync.when(
            data: (products) {
              final farmerProducts = products
                  .where((p) =>
                      p.farmerId == _selectedFarmerId &&
                      p.isActive &&
                      !p.isDeleted)
                  .toList();

              if (farmerProducts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No active products for this farmer',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select products and set pricing to add:',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: farmerProducts.length,
                          itemBuilder: (context, index) {
                            final product = farmerProducts[index];
                            final pricing = _productPricing[product.id] ??
                                ProductPricing(
                                  price: product.price,
                                  profitMargin: product.profitMargin,
                                );
                            final isAlreadyAdded = widget.schedule.products
                                .any((p) => p.productId == product.id);
                            final isPendingAdded = _pendingProducts
                                .any((p) => p.productId == product.id);
                            final isAdded = isAlreadyAdded || isPendingAdded;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: isAdded
                                                ? Colors.grey
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          '${product.category} - Base: ₹${product.price.toStringAsFixed(0)}/${product.unit}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        if (isAdded)
                                          Text(
                                            isPendingAdded
                                                ? 'Already added to pending list'
                                                : 'Already in schedule',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.orange[700],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!isAdded) ...[
                                    SizedBox(
                                      width: 70,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Price',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        controller: _priceControllers.putIfAbsent(
                                          product.id,
                                          () => TextEditingController(
                                            text: pricing.price > 0
                                                ? pricing.price.toStringAsFixed(0)
                                                : '',
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final price = double.tryParse(value) ?? 0;
                                          setState(() {
                                            _productPricing[product.id] =
                                                ProductPricing(
                                              price: price,
                                              profitMargin: pricing.profitMargin,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    SizedBox(
                                      width: 70,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Profit',
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        controller: _profitControllers.putIfAbsent(
                                          product.id,
                                          () => TextEditingController(
                                            text: pricing.profitMargin > 0
                                                ? pricing.profitMargin
                                                    .toStringAsFixed(0)
                                                : '',
                                          ),
                                        ),
                                        onChanged: (value) {
                                          final profit =
                                              double.tryParse(value) ?? 0;
                                          setState(() {
                                            _productPricing[product.id] =
                                                ProductPricing(
                                              price: pricing.price,
                                              profitMargin: profit,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  IconButton(
                                    icon: Icon(Icons.add_circle,
                                        color: isAdded
                                            ? Colors.grey
                                            : Colors.blue[700]),
                                    onPressed: isAdded
                                        ? null
                                        : () => _addProductToPending(product),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('Error: $error'),
          ),
        if (_pendingProducts.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Pending Additions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            height: 120,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendingProducts.length,
              itemBuilder: (context, index) {
                final product = _pendingProducts[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    product.productName,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${product.farmerName} - ₹${product.price.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () => _removePendingProduct(index),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _addProductToPending(ProductModel product) {
    final pricing = _productPricing[product.id];
    if (pricing == null || pricing.price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a price greater than 0'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final farmersAsync = ref.read(farmersStreamProvider);
    final farmers = farmersAsync.value ?? [];
    final farmer = farmers.firstWhere(
      (f) => f.id == product.farmerId,
      orElse: () => FarmerModel(
        id: '',
        name: 'Unknown Farmer',
        phone: '',
        email: '',
        address: '',
        location: '',
        isActive: true,
        isDeleted: false,
        createdAt: DateTime.now(),
        createdBy: '',
      ),
    );

    final newItem = ScheduleProductItem(
      productId: product.id,
      productName: product.name,
      productCategory: product.category,
      quantity: 1,
      price: pricing.price,
      profitMargin: pricing.profitMargin,
      farmerId: product.farmerId,
      farmerName: farmer.name,
    );

    setState(() {
      _pendingProducts.add(newItem);
      _productPricing.remove(product.id);
      _priceControllers.remove(product.id)?.dispose();
      _profitControllers.remove(product.id)?.dispose();
    });
  }

  void _removePendingProduct(int index) {
    setState(() {
      _pendingProducts.removeAt(index);
    });
  }

  Future<void> _updateSchedule() async {
    setState(() => _isUpdating = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        setState(() => _isUpdating = false);
        return;
      }

      final updatedProducts = [
        ...widget.schedule.products,
        ..._pendingProducts,
      ];

      final updatedSchedule = widget.schedule.copyWith(
        products: updatedProducts,
        updatedAt: DateTime.now(),
        updatedBy: user.id,
      );

      final repository = ref.read(operationalScheduleRepositoryProvider);
      await repository.updateSchedule(
        widget.schedule.id,
        updatedSchedule,
        user.id,
        user.role,
      );

      ref.invalidate(scheduleStatsProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUpdating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
