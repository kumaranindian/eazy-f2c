import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/customer/providers/customer_providers.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CustomerDashboardPage extends ConsumerStatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  ConsumerState<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends ConsumerState<CustomerDashboardPage> {
  String _selectedCategory = 'All';
  String? _selectedFarmer;
  bool _showCart = false;

  int _getCrossAxisCount(double width) {
    if (width < 600) return 1; // Mobile
    if (width < 900) return 2; // Tablet
    if (width < 1200) return 3; // Small desktop
    return 4; // Large desktop
  }

  bool _isMobile(double width) => width < 600;
  bool _isTablet(double width) => width >= 600 && width < 900;
  bool _isDesktop(double width) => width >= 900;

  void _showMobileCart() {
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
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(child: _buildCartSummary()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(currentCustomerProvider);
    final schedulesAsync = ref.watch(activeSchedulesProvider);
    final productsAsync = ref.watch(availableProductsProvider);
    final cart = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer profile not found. Please contact admin.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = _isMobile(constraints.maxWidth);
              
              return Column(
                children: [
                  // Green Header
                  Container(
                    color: const Color(0xFF00C853),
                    child: SafeArea(
                      bottom: false,
                      child: Column(
                        children: [
                          // Top bar with logo and actions
                          Padding(
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            child: Row(
                              children: [
                                Container(
                                  width: isMobile ? 40 : 48,
                                  height: isMobile ? 40 : 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'F2C',
                                      style: TextStyle(
                                        color: const Color(0xFF00C853),
                                        fontWeight: FontWeight.bold,
                                        fontSize: isMobile ? 14 : 16,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'F2C',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMobile ? 16 : 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        customer.apartmentName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isMobile ? 11 : 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isMobile)
                                  TextButton.icon(
                                    onPressed: () {},
                                    icon: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                                    label: const Text(
                                      'Orders',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                IconButton(
                                  icon: Stack(
                                    children: [
                                      const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
                                      if (cart.isNotEmpty)
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.red,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            constraints: const BoxConstraints(
                                              minWidth: 18,
                                              minHeight: 18,
                                            ),
                                            child: Text(
                                              '${cart.length}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  onPressed: () {
                                    if (isMobile) {
                                      _showMobileCart();
                                    } else {
                                      setState(() {
                                        _showCart = !_showCart;
                                      });
                                    }
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                                  onPressed: () async {
                                    final authRepo = ref.read(authRepositoryProvider);
                                    await authRepo.logout();
                                    if (context.mounted) {
                                      context.go(RouteNames.login);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                      // Location and delivery info
                      schedulesAsync.when(
                        data: (schedules) {
                          print('DEBUG UI: Schedules count in header: ${schedules.length}');
                          if (schedules.isEmpty) {
                            return Container(
                              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange, width: 2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'No active delivery schedules for today. Please check back later.',
                                      style: TextStyle(
                                        color: Colors.white, 
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final schedule = schedules.first;
                          return Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${schedule.branchName} - ${schedule.hubName}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'Pickup: Community Center, 5th Block | Next delivery: ${schedule.scheduledDate.day}/${schedule.scheduledDate.month}, ${schedule.startTime}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.white, size: 16),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Delivery closes in ${_getTimeRemaining(schedule)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Row(
                  children: [
                    // Main content
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isMobile = _isMobile(constraints.maxWidth);
                          final showCartSidebar = !isMobile && _showCart;

                          return Row(
                            children: [
                              Expanded(
                                child: productsAsync.when(
                                  data: (products) => _buildProductList(products, constraints.maxWidth),
                                  loading: () => const Center(child: CircularProgressIndicator()),
                                  error: (error, stack) => Center(child: Text('Error: $error')),
                                ),
                              ),
                              // Cart sidebar (desktop/tablet only)
                              if (showCartSidebar)
                                Container(
                                  width: 350,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                        offset: const Offset(-2, 0),
                                      ),
                                    ],
                                  ),
                                  child: _buildCartSummary(),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = _isMobile(constraints.maxWidth);
          final cart = ref.watch(cartProvider);
          
          if (!isMobile || cart.isEmpty) return const SizedBox.shrink();
          
          return FloatingActionButton.extended(
            onPressed: _showMobileCart,
            backgroundColor: const Color(0xFF00C853),
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (cart.isNotEmpty)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${cart.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text('View Cart (\u20b9${ref.read(cartProvider.notifier).totalAmount.toStringAsFixed(0)})'),
          );
        },
      ),
    );
  }

  String _getTimeRemaining(schedule) {
    // Simple placeholder - calculate actual time remaining
    return '5d 0h';
  }

  Widget _buildProductList(List<ProductWithSchedule> products, double screenWidth) {
    print('DEBUG UI: Products count in list: ${products.length}');
    final isMobile = _isMobile(screenWidth);
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_basket_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products available',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'No active delivery schedules for today',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    // Get unique categories
    final categories = ['All', ...products.map((p) => p.product.category).toSet().toList()];

    // Get unique farmers
    final farmers = products
        .where((p) => p.farmerName != null)
        .map((p) => p.farmerName!)
        .toSet()
        .toList();

    // Filter products
    var filteredProducts = products;
    if (_selectedCategory != 'All') {
      filteredProducts = filteredProducts.where((p) => p.product.category == _selectedCategory).toList();
    }
    if (_selectedFarmer != null) {
      filteredProducts = filteredProducts.where((p) => p.farmerName == _selectedFarmer).toList();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.local_florist, color: Color(0xFF00C853)),
                SizedBox(width: 8),
                Text(
                  'Available This Week',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Category tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((category) {
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF00C853),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Farmer filter chips
          if (farmers.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: const Text('All'),
                      selected: _selectedFarmer == null,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFarmer = null;
                        });
                      },
                      backgroundColor: const Color(0xFFFF6F00),
                      selectedColor: const Color(0xFFFF6F00),
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ...farmers.map((farmer) {
                    final isSelected = _selectedFarmer == farmer;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(farmer),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFarmer = selected ? farmer : null;
                          });
                        },
                        backgroundColor: Colors.grey[300],
                        selectedColor: Colors.grey[600],
                        labelStyle: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // Products grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                childAspectRatio: isMobile ? 0.85 : 0.75,
                crossAxisSpacing: isMobile ? 8 : 16,
                mainAxisSpacing: isMobile ? 8 : 16,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                return _buildProductCard(filteredProducts[index], isMobile);
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductWithSchedule productWithSchedule, bool isMobile) {
    final product = productWithSchedule.product;
    final cart = ref.watch(cartProvider);
    final cartItem = cart[product.id];
    final quantity = cartItem?.quantity ?? 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product image
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(
                    width: double.infinity,
                    height: isMobile ? 180 : 150,
                    color: Colors.grey[200],
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 16 : 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (productWithSchedule.farmerName != null)
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          productWithSchedule.farmerName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  '₹${product.price.toStringAsFixed(0)}/${product.unit}',
                  style: TextStyle(
                    color: const Color(0xFF00C853),
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 18 : 16,
                  ),
                ),
                const SizedBox(height: 8),
                // Quick select
                if (!isMobile)
                  const Text(
                    'Quick Select',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                if (!isMobile) const SizedBox(height: 4),
                if (!isMobile)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [0.25, 0.5, 1.0, 2.0].map((qty) {
                    final isSelected = quantity == qty;
                    return InkWell(
                      onTap: () {
                        if (isSelected) {
                          ref.read(cartProvider.notifier).removeItem(product.id);
                        } else {
                          ref.read(cartProvider.notifier).addItem(
                            CartItemModel(
                              productId: product.id,
                              productName: product.displayName,
                              productCategory: product.category,
                              price: product.price,
                              unit: product.unit,
                              imageUrl: product.imageUrl,
                              quantity: qty,
                              farmerId: productWithSchedule.farmerId,
                              farmerName: productWithSchedule.farmerName,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF00C853) : Colors.white,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00C853) : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${qty}kg',
                          style: TextStyle(
                            fontSize: 10,
                            color: isSelected ? Colors.white : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  ),
                SizedBox(height: isMobile ? 12 : 8),
                // Quantity stepper and add to cart
                if (quantity > 0)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () {
                          ref.read(cartProvider.notifier).updateQuantity(
                            product.id,
                            quantity - 0.25,
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Expanded(
                        child: Text(
                          quantity.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () {
                          ref.read(cartProvider.notifier).updateQuantity(
                            product.id,
                            quantity + 0.25,
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (quantity == 0) {
                        ref.read(cartProvider.notifier).addItem(
                          CartItemModel(
                            productId: product.id,
                            productName: product.displayName,
                            productCategory: product.category,
                            price: product.price,
                            unit: product.unit,
                            imageUrl: product.imageUrl,
                            quantity: 1.0,
                            farmerId: productWithSchedule.farmerId,
                            farmerName: productWithSchedule.farmerName,
                          ),
                        );
                      } else if (isMobile) {
                        // On mobile, show cart when item added
                        setState(() {
                          _showCart = true;
                        });
                        _showMobileCart();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart, size: isMobile ? 20 : 16),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            quantity > 0 ? 'Total: ₹${(product.price * quantity).toStringAsFixed(0)}' : 'Add to Cart',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: isMobile ? 14 : 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    final cart = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    if (cart.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF00C853),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: 8),
              const Text(
                'Cart Summary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cart.length} items',
                  style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: cart.length,
            itemBuilder: (context, index) {
              final item = cart.values.elementAt(index);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
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
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${item.quantity}kg × ₹${item.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Text(
                              '₹${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF00C853),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          cartNotifier.removeItem(item.productId);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '₹${cartNotifier.totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C853),
                    ),
                  ),
                ],
              ),
              Text(
                '${cart.length} items • ${cartNotifier.totalWeight.toStringAsFixed(2)}kg total',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement checkout
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag),
                      SizedBox(width: 8),
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Free delivery to Community Center',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
