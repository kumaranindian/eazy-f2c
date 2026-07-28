import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/core/widgets/f2c_logo.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/features/admin/presentation/pages/users/users_list_page.dart';
import 'package:f2c/features/admin/presentation/pages/orders/admin_orders_page.dart';
import 'package:f2c/features/admin/presentation/pages/packaging/admin_packaging_page.dart';
import 'package:f2c/features/admin/presentation/pages/delivery/admin_delivery_page.dart';
import 'package:f2c/features/admin/presentation/pages/packaging/farmer_packaging_list_page.dart';
import 'package:f2c/features/admin/presentation/pages/settings/admin_settings_page.dart';
import 'package:f2c/features/admin/presentation/pages/transactions/admin_transactions_page.dart';
import 'package:f2c/features/admin/providers/branch_providers.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';
import 'package:f2c/features/admin/providers/apartment_providers.dart';
import 'package:f2c/features/admin/providers/customer_providers.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/admin/providers/product_providers.dart';
import 'package:f2c/features/admin/providers/category_providers.dart';
import 'package:f2c/features/admin/providers/operational_schedule_providers.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';
import 'package:f2c/features/admin/presentation/widgets/create_operational_schedule_wizard.dart';
import 'package:f2c/features/admin/presentation/widgets/update_operational_schedule_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_branch_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_branch_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_branch_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_hub_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_hub_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_hub_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_apartment_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_apartment_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_apartment_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_customer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_customer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_customer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_farmer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_farmer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_farmer_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/add_product_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/edit_product_dialog.dart';
import 'package:f2c/features/admin/presentation/widgets/delete_product_dialog.dart';
import 'package:intl/intl.dart';

enum DateFilterType {
  all,
  currentDay,
  currentWeek,
  thisMonth,
  custom,
}

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  String _selectedMenu = 'Dashboard';

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1200;
    final isTablet = size.width > 768 && size.width <= 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          // Set initial menu for super admin
          if (user.role.canManageUsers && _selectedMenu == 'Dashboard') {
            _selectedMenu = 'Users & Roles';
          }

          return Row(
            children: [
              if (isDesktop || isTablet)
                _buildSidebar(context, user),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(context, user, isDesktop),
                    Expanded(
                      child: _buildDashboardContent(context, isDesktop, isTablet),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      drawer: (!isDesktop && !isTablet) ? _buildDrawer(context, userAsync.value!) : null,
    );
  }

  Widget _buildSidebar(BuildContext context, user) {
    final isSuperAdmin = user.role == UserRole.superAdmin;
    final isAdmin = user.role == UserRole.admin;
    
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const F2CLogo(size: 32),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'F2C',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      'FARM2COMMUNITY',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Super Admin sees only Users & Roles
                if (isSuperAdmin) ...[
                  _buildMenuItem(Icons.people_outline, 'Users & Roles', _selectedMenu == 'Users & Roles'),
                ] else ...[
                  // Regular Admin sees all menus
                  _buildMenuItem(Icons.dashboard_outlined, 'Dashboard', _selectedMenu == 'Dashboard'),
                  _buildMenuItem(Icons.business_outlined, 'Branch Management', _selectedMenu == 'Branch Management'),
                  _buildMenuItem(Icons.hub_outlined, 'HUB Management', _selectedMenu == 'HUB Management'),
                  _buildMenuItem(Icons.apartment_outlined, 'Apartment Management', _selectedMenu == 'Apartment Management'),
                  _buildMenuItem(Icons.person_outline, 'Customer Management', _selectedMenu == 'Customer Management'),
                  _buildMenuItem(Icons.agriculture_outlined, 'Farmer Management', _selectedMenu == 'Farmer Management'),
                  _buildMenuItem(Icons.inventory_2_outlined, 'Product Management', _selectedMenu == 'Product Management'),
                  _buildMenuItem(Icons.calendar_today_outlined, 'Operational Schedule', _selectedMenu == 'Operational Schedule'),
                  _buildMenuItem(Icons.shopping_cart_outlined, 'Orders', _selectedMenu == 'Orders'),
                  _buildMenuItem(Icons.local_shipping_outlined, 'Packaging', _selectedMenu == 'Packaging'),
                  _buildMenuItem(Icons.inventory_2_outlined, 'Farmer Packaging List', _selectedMenu == 'Farmer Packaging List'),
                  _buildMenuItem(Icons.local_shipping_outlined, 'Deliveries', _selectedMenu == 'Deliveries'),
                  _buildMenuItem(Icons.assessment_outlined, 'Reports', _selectedMenu == 'Reports'),
                  _buildMenuItem(Icons.notifications_outlined, 'Notifications', _selectedMenu == 'Notifications', badge: 3),
                  _buildMenuItem(Icons.people_outline, 'Users & Roles', _selectedMenu == 'Users & Roles'),
                  _buildMenuItem(Icons.settings_outlined, 'Settings', _selectedMenu == 'Settings'),
                  _buildMenuItem(Icons.account_balance_wallet_outlined, 'Transactions', _selectedMenu == 'Transactions'),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          // Logout Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  print('Logout button pressed');
                  try {
                    final authRepo = ref.read(authRepositoryProvider);
                    await authRepo.logout();
                    print('Logout completed, invalidating session');
                    ref.invalidate(currentSessionProvider);
                    print('Session invalidated, navigating to login');
                    if (context.mounted) {
                      context.go(RouteNames.login);
                    }
                  } catch (e) {
                    print('Logout error: $e');
                  }
                },
                icon: Icon(Icons.logout_outlined, size: 18),
                label: Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[50],
                  foregroundColor: Colors.red[700],
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, user) {
    return Drawer(
      child: _buildSidebar(context, user),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, bool isSelected, {int? badge}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green[50] : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.green[700] : Colors.grey[600],
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.green[700] : Colors.grey[700],
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              )
            : null,
        dense: true,
        onTap: () {
          setState(() {
            _selectedMenu = title;
          });
          _navigateToMenu(context, title);
        },
      ),
    );
  }

  void _navigateToMenu(BuildContext context, String menuTitle) {
    // All menu items are handled inline in the dashboard
    // No navigation needed - content changes based on _selectedMenu
  }

  Widget _buildTopBar(BuildContext context, user, bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isDesktop)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
          if (!isDesktop) const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '02. Admin Dashboard',
                style: TextStyle(
                  fontSize: isDesktop ? 20 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
              Text(
                'Welcome back, ${user.name}! 👋',
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () {},
              tooltip: DateFormat('dd MMM yyyy').format(DateTime.now()),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.green[700],
                  child: Text(
                    user.initials,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  user.name.split(' ').first,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              print('Top bar logout button pressed');
              try {
                final authRepo = ref.read(authRepositoryProvider);
                await authRepo.logout();
                print('Top bar logout completed, invalidating session');
                ref.invalidate(currentSessionProvider);
                print('Session invalidated, navigating to login');
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              } catch (e) {
                print('Top bar logout error: $e');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, bool isDesktop, bool isTablet) {
    // Show Users & Roles content inline
    if (_selectedMenu == 'Users & Roles') {
      return _buildUsersAndRolesContent();
    }
    
    // Show Branch Management content inline
    if (_selectedMenu == 'Branch Management') {
      return _buildBranchManagementContent();
    }
    
    // Show HUB Management content inline
    if (_selectedMenu == 'HUB Management') {
      return _buildHubManagementContent();
    }
    
    // Show Apartment Management content inline
    if (_selectedMenu == 'Apartment Management') {
      return _buildApartmentManagementContent();
    }
    
    // Show Customer Management content inline
    if (_selectedMenu == 'Customer Management') {
      return _buildCustomerManagementContent();
    }
    
    // Show Farmer Management content inline
    if (_selectedMenu == 'Farmer Management') {
      return _buildFarmerManagementContent();
    }
    
    // Show Product Management content inline
    if (_selectedMenu == 'Product Management') {
      return _buildProductManagementContent();
    }
    
    // Show Operational Schedule content inline
    if (_selectedMenu == 'Operational Schedule') {
      return _buildOperationalScheduleContent();
    }
    
    // Show Orders page
    if (_selectedMenu == 'Orders') {
      return const AdminOrdersPage();
    }
    
    // Show Packaging page
    if (_selectedMenu == 'Packaging') {
      return const AdminPackagingPage();
    }

    // Show Farmer Packaging List page
    if (_selectedMenu == 'Farmer Packaging List') {
      return const FarmerPackagingListPage();
    }

    // Show Deliveries page
    if (_selectedMenu == 'Deliveries') {
      return const AdminDeliveryPage();
    }

    // Show Settings page
    if (_selectedMenu == 'Settings') {
      return const AdminSettingsPage();
    }

    // Show Transactions page
    if (_selectedMenu == 'Transactions') {
      return const AdminTransactionsPage();
    }

    // Dashboard content for other menus
    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(isDesktop, isTablet),
          const SizedBox(height: 24),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: _buildOrdersOverview(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildTopHubPerformance(),
                ),
              ],
            )
          else ...[
            _buildOrdersOverview(),
            const SizedBox(height: 24),
            _buildTopHubPerformance(),
          ],
        ],
      ),
    );
  }

  Widget _buildUsersAndRolesContent() {
    return Stack(
      children: [
        const UsersListPage(embedded: true),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showCreateUserDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Create User'),
            backgroundColor: Colors.green[700],
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: const CreateUserDialogContent(),
        ),
      ),
    ).then((result) {
      if (result == true) {
        ref.invalidate(usersListProvider);
      }
    });
  }

  Widget _buildStatsCards(bool isDesktop, bool isTablet) {
    final stats = [
      {'title': 'Total Orders', 'value': '128', 'change': '+12% vs yesterday', 'icon': Icons.shopping_bag_outlined, 'color': Colors.blue},
      {'title': 'Pending Deliveries', 'value': '32', 'change': '+6% vs yesterday', 'icon': Icons.local_shipping_outlined, 'color': Colors.orange},
      {'title': 'Delivered Orders', 'value': '96', 'change': '+19% vs yesterday', 'icon': Icons.check_circle_outline, 'color': Colors.green},
      {'title': 'Total Revenue', 'value': '₹45,860', 'change': '+10% vs yesterday', 'icon': Icons.currency_rupee, 'color': Colors.purple},
    ];

    if (!isDesktop && !isTablet) {
      return Column(
        children: stats.map((stat) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildDashboardStatCard(stat),
        )).toList(),
      );
    }

    return Row(
      children: stats.map((stat) => Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _buildDashboardStatCard(stat),
        ),
      )).toList(),
    );
  }

  Widget _buildDashboardStatCard(Map<String, dynamic> stat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: (stat['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              stat['icon'] as IconData,
              color: stat['color'] as Color,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${stat['title']}: ${stat['value']}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersOverview() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Orders Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text('Last 7 Days', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey[600]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildLegend(Colors.green, 'Placed'),
              const SizedBox(width: 16),
              _buildLegend(Colors.orange, 'Packed'),
              const SizedBox(width: 16),
              _buildLegend(Colors.blue, 'Delivered'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildBar('08 May', 40, 30, 20),
                _buildBar('09 May', 50, 35, 25),
                _buildBar('10 May', 60, 45, 30),
                _buildBar('11 May', 70, 50, 35),
                _buildBar('12 May', 80, 60, 40),
                _buildBar('13 May', 90, 70, 45),
                _buildBar('14 May', 100, 75, 50),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOrderStat('128', 'Placed\nTotal Orders', Colors.blue),
              _buildOrderStat('64', 'Packed\nTotal Orders', Colors.orange),
              _buildOrderStat('96', 'Delivered\nTotal Orders', Colors.green),
              _buildOrderStat('12', 'Canceled\nTotal Orders', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey[700]),
        ),
      ],
    );
  }

  Widget _buildBar(String label, double green, double orange, double blue) {
    return Expanded(
      child: SizedBox(
        height: 140,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: green * 0.35,
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
            Container(
              width: 16,
              height: orange * 0.35,
              color: Colors.orange,
            ),
            Container(
              width: 16,
              height: blue * 0.35,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderStat(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTopHubPerformance() {
    final hubs = [
      {'name': 'Polachery HUB', 'orders': 48, 'revenue': '₹16,650'},
      {'name': 'Velachery HUB', 'orders': 36, 'revenue': '₹12,240'},
      {'name': 'Tambaram HUB', 'orders': 28, 'revenue': '₹8,230'},
      {'name': 'Medavakkam HUB', 'orders': 16, 'revenue': '₹6,540'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top HUB Performance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'View All',
                  style: TextStyle(color: Colors.green[700]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'HUB Name',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  'Orders',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'Revenue',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...hubs.map((hub) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        hub['name'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hub['orders'].toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple[700],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        hub['revenue'] as String,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          Text(
            '📊 Performance based on delivered orders',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchManagementContent() {
    final statsAsync = ref.watch(branchStatsProvider);
    final branchesAsync = ref.watch(branchesStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Branch Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Branch Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddBranchDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Branch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards - Real Data
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Branches',
                    stats['totalBranches'].toString(),
                    'All Locations',
                    Icons.business_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active Branches',
                    stats['activeBranches'].toString(),
                    'Currently Active',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive Branches',
                    stats['inactiveBranches'].toString(),
                    'Not Active',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Deleted Branches',
                    stats['deletedBranches'].toString(),
                    'Soft Deleted',
                    Icons.delete_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total HUBs',
                    stats['totalHubs'].toString(),
                    'Across All Branches',
                    Icons.hub_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // Branch List - Real Data
          Expanded(
            child: branchesAsync.when(
              data: (branches) {
                if (branches.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Branches Yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add Branch" to create your first branch',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Branches (${branches.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: branches.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final branch = branches[index];
                            final isDeleted = branch.isDeleted;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isDeleted ? Colors.grey[100] : Colors.white,
                                border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDeleted
                                        ? Colors.grey.withOpacity(0.2)
                                        : (branch.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDeleted ? Icons.delete_forever : Icons.business,
                                    color: isDeleted
                                        ? Colors.grey[600]
                                        : (branch.isActive ? Colors.green : Colors.red),
                                  ),
                                ),
                                title: Text(
                                  branch.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    color: isDeleted ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${branch.code} • ${branch.location}\n${branch.manager} • ${branch.phone}',
                                  style: TextStyle(
                                    color: isDeleted ? Colors.grey[500] : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isDeleted) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final user = ref.read(currentUserProvider).value;
                                            if (user == null) return;
                                            
                                            final repository = ref.read(branchRepositoryProvider);
                                            await repository.restoreBranch(
                                              branch.id,
                                              user.id,
                                              user.role,
                                            );
                                            
                                            // Refresh stats to update metrics
                                            ref.invalidate(branchStatsProvider);
                                            
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Branch restored successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore, size: 18),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: branch.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          branch.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: branch.isActive
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditBranchDialog(
                                              branch: branch,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DeleteBranchDialog(
                                              branch: branch,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading branches: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHubManagementContent() {
    final statsAsync = ref.watch(hubStatsProvider);
    final hubsAsync = ref.watch(hubsStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'HUB Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > HUB Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddHubDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add HUB'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total HUBs',
                    stats['totalHubs'].toString(),
                    'All Locations',
                    Icons.hub_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active HUBs',
                    stats['activeHubs'].toString(),
                    'Currently Active',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive HUBs',
                    stats['inactiveHubs'].toString(),
                    'Not Active',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Deleted HUBs',
                    stats['deletedHubs'].toString(),
                    'Soft Deleted',
                    Icons.delete_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Branches',
                    stats['totalBranches'].toString(),
                    'Across All HUBs',
                    Icons.business_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // HUB List
          Expanded(
            child: hubsAsync.when(
              data: (hubs) {
                if (hubs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.hub_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No HUBs Yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add HUB" to create your first HUB',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HUBs (${hubs.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: hubs.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final hub = hubs[index];
                            final isDeleted = hub.isDeleted;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isDeleted ? Colors.grey[100] : Colors.white,
                                border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDeleted
                                        ? Colors.grey.withOpacity(0.2)
                                        : (hub.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDeleted ? Icons.delete_forever : Icons.hub,
                                    color: isDeleted
                                        ? Colors.grey[600]
                                        : (hub.isActive ? Colors.green : Colors.red),
                                  ),
                                ),
                                title: Text(
                                  hub.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    color: isDeleted ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${hub.branchName}\nApartments: ${hub.apartmentCount}',
                                  style: TextStyle(
                                    color: isDeleted ? Colors.grey[500] : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isDeleted) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final user = ref.read(currentUserProvider).value;
                                            if (user == null) return;
                                            
                                            final repository = ref.read(hubRepositoryProvider);
                                            await repository.restoreHub(
                                              hub.id,
                                              user.id,
                                              user.role,
                                            );
                                            
                                            ref.invalidate(hubStatsProvider);
                                            
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('HUB restored successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore, size: 18),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: hub.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          hub.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: hub.isActive
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditHubDialog(
                                              hub: hub,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DeleteHubDialog(
                                              hub: hub,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading HUBs: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApartmentManagementContent() {
    final statsAsync = ref.watch(apartmentStatsProvider);
    final apartmentsAsync = ref.watch(apartmentsStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Apartment Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Apartment Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddApartmentDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Apartment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Apartments',
                    stats['totalApartments'].toString(),
                    'All Locations',
                    Icons.apartment_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active Apartments',
                    stats['activeApartments'].toString(),
                    'Currently Active',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive Apartments',
                    stats['inactiveApartments'].toString(),
                    'Not Active',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Deleted Apartments',
                    stats['deletedApartments'].toString(),
                    'Soft Deleted',
                    Icons.delete_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total HUBs',
                    stats['totalHubs'].toString(),
                    'Across All Apartments',
                    Icons.hub_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // Apartment List
          Expanded(
            child: apartmentsAsync.when(
              data: (apartments) {
                if (apartments.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.apartment_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Apartments Yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add Apartment" to create your first apartment',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apartments (${apartments.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: apartments.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final apartment = apartments[index];
                            final isDeleted = apartment.isDeleted;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isDeleted ? Colors.grey[100] : Colors.white,
                                border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDeleted
                                        ? Colors.grey.withOpacity(0.2)
                                        : (apartment.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDeleted ? Icons.delete_forever : Icons.apartment,
                                    color: isDeleted
                                        ? Colors.grey[600]
                                        : (apartment.isActive ? Colors.green : Colors.red),
                                  ),
                                ),
                                title: Text(
                                  apartment.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    color: isDeleted ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${apartment.hubName} • ${apartment.location}\n${apartment.deliveryDay} @ ${apartment.deliveryTime}\nCustomers: ${apartment.totalCustomers}',
                                  style: TextStyle(
                                    color: isDeleted ? Colors.grey[500] : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isDeleted) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final user = ref.read(currentUserProvider).value;
                                            if (user == null) return;
                                            
                                            final repository = ref.read(apartmentRepositoryProvider);
                                            await repository.restoreApartment(
                                              apartment.id,
                                              user.id,
                                              user.role,
                                            );
                                            
                                            ref.invalidate(apartmentStatsProvider);
                                            
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Apartment restored successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore, size: 18),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: apartment.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          apartment.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: apartment.isActive
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditApartmentDialog(
                                              apartment: apartment,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DeleteApartmentDialog(
                                              apartment: apartment,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading apartments: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerManagementContent() {
    final statsAsync = ref.watch(customerStatsProvider);
    final customersAsync = ref.watch(customersStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Customer Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Customer Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddCustomerDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Customers',
                    stats['totalCustomers'].toString(),
                    'All Locations',
                    Icons.people_outline,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active Customers',
                    stats['activeCustomers'].toString(),
                    'Currently Active',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive Customers',
                    stats['inactiveCustomers'].toString(),
                    'Not Active',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Deleted Customers',
                    stats['deletedCustomers'].toString(),
                    'Soft Deleted',
                    Icons.delete_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Orders',
                    stats['totalOrders'].toString(),
                    'All Time',
                    Icons.shopping_cart_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // Customer List
          Expanded(
            child: customersAsync.when(
              data: (customers) {
                if (customers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Customers Yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add Customer" to create your first customer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customers (${customers.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: customers.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final customer = customers[index];
                            final isDeleted = customer.isDeleted;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isDeleted ? Colors.grey[100] : Colors.white,
                                border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDeleted
                                        ? Colors.grey.withOpacity(0.2)
                                        : (customer.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDeleted ? Icons.delete_forever : Icons.person,
                                    color: isDeleted
                                        ? Colors.grey[600]
                                        : (customer.isActive ? Colors.green : Colors.red),
                                  ),
                                ),
                                title: Text(
                                  customer.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    color: isDeleted ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${customer.phone} • ${customer.email}\n${customer.apartmentName} • ${customer.address}\nOrders: ${customer.totalOrders}',
                                  style: TextStyle(
                                    color: isDeleted ? Colors.grey[500] : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isDeleted) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final user = ref.read(currentUserProvider).value;
                                            if (user == null) return;
                                            
                                            final repository = ref.read(customerRepositoryProvider);
                                            await repository.restoreCustomer(
                                              customer.id,
                                              user.id,
                                              user.role,
                                            );
                                            
                                            ref.invalidate(customerStatsProvider);
                                            
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Customer restored successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore, size: 18),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: customer.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          customer.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: customer.isActive
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditCustomerDialog(
                                              customer: customer,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DeleteCustomerDialog(
                                              customer: customer,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading customers: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmerManagementContent() {
    final statsAsync = ref.watch(farmerStatsProvider);
    final farmersAsync = ref.watch(farmersStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Farmer Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Farmer Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddFarmerDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Farmer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Farmers',
                    stats['totalFarmers'].toString(),
                    'All Locations',
                    Icons.agriculture,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active Farmers',
                    stats['activeFarmers'].toString(),
                    'Currently Active',
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive Farmers',
                    stats['inactiveFarmers'].toString(),
                    'Not Active',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Deleted Farmers',
                    stats['deletedFarmers'].toString(),
                    'Soft Deleted',
                    Icons.delete_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Total Deliveries',
                    stats['totalDeliveries'].toString(),
                    'All Time',
                    Icons.local_shipping_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // Farmer List
          Expanded(
            child: farmersAsync.when(
              data: (farmers) {
                if (farmers.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.agriculture,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Farmers Yet',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click "Add Farmer" to create your first farmer',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Farmers (${farmers.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: farmers.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final farmer = farmers[index];
                            final isDeleted = farmer.isDeleted;
                            
                            return Container(
                              decoration: BoxDecoration(
                                color: isDeleted ? Colors.grey[100] : Colors.white,
                                border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDeleted
                                        ? Colors.grey.withOpacity(0.2)
                                        : (farmer.isActive
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isDeleted ? Icons.delete_forever : Icons.agriculture,
                                    color: isDeleted
                                        ? Colors.grey[600]
                                        : (farmer.isActive ? Colors.green : Colors.red),
                                  ),
                                ),
                                title: Text(
                                  farmer.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: isDeleted ? TextDecoration.lineThrough : null,
                                    color: isDeleted ? Colors.grey[600] : null,
                                  ),
                                ),
                                subtitle: Text(
                                  '${farmer.phone} • ${farmer.email}\n${farmer.location}\nDeliveries: ${farmer.totalDeliveries}',
                                  style: TextStyle(
                                    color: isDeleted ? Colors.grey[500] : null,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isDeleted) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Deleted',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () async {
                                          try {
                                            final user = ref.read(currentUserProvider).value;
                                            if (user == null) return;
                                            
                                            final repository = ref.read(farmerRepositoryProvider);
                                            await repository.restoreFarmer(
                                              farmer.id,
                                              user.id,
                                              user.role,
                                            );
                                            
                                            ref.invalidate(farmerStatsProvider);
                                            
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Farmer restored successfully'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                        icon: const Icon(Icons.restore, size: 18),
                                        label: const Text('Restore'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green[700],
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: farmer.isActive
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          farmer.isActive ? 'Active' : 'Inactive',
                                          style: TextStyle(
                                            color: farmer.isActive
                                                ? Colors.green[700]
                                                : Colors.red[700],
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => EditFarmerDialog(
                                              farmer: farmer,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: Colors.red,
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => DeleteFarmerDialog(
                                              farmer: farmer,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading farmers: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductManagementContent() {
    return const _ProductManagementContent();
  }

  Widget _buildOperationalScheduleContent() {
    return const _OperationalScheduleContent();
  }
}

class _OperationalScheduleContent extends ConsumerStatefulWidget {
  const _OperationalScheduleContent();

  @override
  ConsumerState<_OperationalScheduleContent> createState() => _OperationalScheduleContentState();
}

class _OperationalScheduleContentState extends ConsumerState<_OperationalScheduleContent> {
  String? _selectedStatusFilter;
  DateFilterType _dateFilterType = DateFilterType.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  final Set<String> _expandedScheduleIds = {};
  final Map<String, List<OperationalScheduleModel>> _childSchedulesCache = {};

  Future<void> _fetchChildSchedules(String parentId) async {
    if (_childSchedulesCache.containsKey(parentId)) return;

    try {
      final repository = ref.read(operationalScheduleRepositoryProvider);
      final allSchedules = await repository.getSchedules();
      final childSchedules = allSchedules
          .where((s) => s.parentScheduleId == parentId && !s.isDeleted)
          .toList();
      setState(() {
        _childSchedulesCache[parentId] = childSchedules;
      });
    } catch (e) {
      print('Error fetching child schedules: $e');
    }
  }

  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_dateFilterType) {
      case DateFilterType.all:
        // Return a very wide range to include all schedules (past 10 years to future 10 years)
        return DateTimeRange(
          start: DateTime(now.year - 10, 1, 1),
          end: DateTime(now.year + 10, 12, 31),
        );
      case DateFilterType.currentDay:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
      case DateFilterType.currentWeek:
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        return DateTimeRange(start: startOfWeek, end: endOfWeek);
      case DateFilterType.thisMonth:
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);
        return DateTimeRange(start: startOfMonth, end: endOfMonth);
      case DateFilterType.custom:
        if (_customStartDate != null && _customEndDate != null) {
          return DateTimeRange(
            start: DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day),
            end: DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day).add(const Duration(days: 1)),
          );
        }
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
    }
  }

  Widget _buildTodayStatCard(String totalValue, String activeValue, String inactiveValue, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalValue,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          const Text(
            'Today',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(
                        activeValue,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      Text(
                        inactiveValue,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Text(
                        'Inactive',
                        style: TextStyle(
                          fontSize: 8,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(schedulesStreamProvider);
    final statsAsync = ref.watch(scheduleStatsProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operational Schedule',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Operational Schedule',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const CreateOperationalScheduleWizard(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Stats Cards
          statsAsync.when(
            data: (stats) => Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Schedules',
                    stats['totalSchedules'].toString(),
                    'All Time',
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Active',
                    stats['activeSchedules'].toString(),
                    'Pending & In Progress',
                    Icons.play_circle_outline,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Inactive',
                    stats['inactiveSchedules'].toString(),
                    'Completed & Cancelled',
                    Icons.pause_circle_outline,
                    Colors.grey,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTodayStatCard(
                    stats['todaySchedules'].toString(),
                    stats['todayActiveSchedules'].toString(),
                    stats['todayInactiveSchedules'].toString(),
                    Icons.today,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('Error loading stats: $error')),
          ),
          const SizedBox(height: 32),
          
          // Filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by Status',
                    hintText: 'All Statuses',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.filter_list),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<DateFilterType>(
                  value: _dateFilterType,
                  decoration: const InputDecoration(
                    labelText: 'Date Filter',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: DateFilterType.all, child: Text('All Schedules')),
                    DropdownMenuItem(value: DateFilterType.currentDay, child: Text('Current Day')),
                    DropdownMenuItem(value: DateFilterType.currentWeek, child: Text('Current Week')),
                    DropdownMenuItem(value: DateFilterType.thisMonth, child: Text('This Month')),
                    DropdownMenuItem(value: DateFilterType.custom, child: Text('Custom Range')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _dateFilterType = value!;
                      if (value != DateFilterType.custom) {
                        _customStartDate = null;
                        _customEndDate = null;
                      }
                    });
                  },
                ),
              ),
              if (_dateFilterType == DateFilterType.custom) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customStartDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customStartDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _customStartDate != null
                                ? '${_customStartDate!.day}/${_customStartDate!.month}/${_customStartDate!.year}'
                                : 'From',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _customEndDate ?? DateTime.now(),
                        firstDate: _customStartDate ?? DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _customEndDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _customEndDate != null
                                ? '${_customEndDate!.day}/${_customEndDate!.month}/${_customEndDate!.year}'
                                : 'To',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedStatusFilter = null;
                    _dateFilterType = DateFilterType.all;
                    _customStartDate = null;
                    _customEndDate = null;
                  });
                },
                icon: const Icon(Icons.clear),
                tooltip: 'Clear Filters',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Schedule List
          Expanded(
            child: schedulesAsync.when(
              data: (schedules) {
                print('DEBUG: Total schedules fetched: ${schedules.length}');
                print('DEBUG: Selected status filter: $_selectedStatusFilter');
                print('DEBUG: Selected date filter type: $_dateFilterType');

                // Apply filters
                List<OperationalScheduleModel> filteredSchedules = schedules
                    .where((s) => !s.isDeleted)
                    .where((s) => s.parentScheduleId == null || s.parentScheduleId!.isEmpty)
                    .toList();

                print('DEBUG: Total schedules fetched: ${schedules.length}');
                print('DEBUG: After deleted and parent filter: ${filteredSchedules.length}');

                if (_selectedStatusFilter != null) {
                  if (_selectedStatusFilter == 'active') {
                    // Active: pending or inProgress
                    filteredSchedules = filteredSchedules
                        .where((s) => s.status == ScheduleStatus.pending || s.status == ScheduleStatus.inProgress)
                        .toList();
                  } else if (_selectedStatusFilter == 'inactive') {
                    // Inactive: completed or cancelled
                    filteredSchedules = filteredSchedules
                        .where((s) => s.status == ScheduleStatus.completed || s.status == ScheduleStatus.cancelled)
                        .toList();
                  } else {
                    // Specific status filter
                    filteredSchedules = filteredSchedules
                        .where((s) => s.status.toString().split('.').last == _selectedStatusFilter)
                        .toList();
                  }
                  print('DEBUG: After status filter: ${filteredSchedules.length}');
                }

                // Apply date filter based on selected type
                final dateRange = _getDateRange();
                print('DEBUG: Date range - Start: ${dateRange.start}, End: ${dateRange.end}');
                
                filteredSchedules = filteredSchedules
                    .where((s) {
                      final scheduleDate = DateTime(
                        s.scheduledDate.year,
                        s.scheduledDate.month,
                        s.scheduledDate.day,
                      );
                      
                      print('DEBUG: Schedule - Type: ${s.recurrenceType}, Date: $scheduleDate, Branch: ${s.branchName}');
                      
                      // For recurring schedules (daily/weekly), check if the recurrence period overlaps with the date range
                      if (s.recurrenceType != ScheduleRecurrenceType.oneTime) {
                        final recurrenceEndDate = s.recurrenceEndDate != null
                            ? DateTime(s.recurrenceEndDate!.year, s.recurrenceEndDate!.month, s.recurrenceEndDate!.day)
                            : null;
                        
                        final passes = scheduleDate.isBefore(dateRange.end) &&
                            (recurrenceEndDate == null || recurrenceEndDate.isAfter(dateRange.start) || recurrenceEndDate.isAtSameMomentAs(dateRange.start));
                        print('DEBUG: Recurring schedule passes filter: $passes');
                        return passes;
                      }
                      
                      // For one-time schedules, check if the date is within the range
                      final passes = (scheduleDate.isAtSameMomentAs(dateRange.start) || scheduleDate.isAfter(dateRange.start)) &&
                          scheduleDate.isBefore(dateRange.end);
                      print('DEBUG: One-time schedule passes filter: $passes');
                      return passes;
                    })
                    .toList();
                print('DEBUG: After date filter: ${filteredSchedules.length}');

                // Calculate pagination
                final totalPages = (filteredSchedules.length / _itemsPerPage).ceil();
                final startIndex = (_currentPage - 1) * _itemsPerPage;
                final endIndex = startIndex + _itemsPerPage;
                final paginatedSchedules = filteredSchedules.skip(startIndex).take(_itemsPerPage).toList();

                print('DEBUG: Final filtered count: ${filteredSchedules.length}');
                print('DEBUG: Total pages: $totalPages, Current page: $_currentPage');

                if (filteredSchedules.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Schedules Found',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters or create a new schedule',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedules (${filteredSchedules.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: paginatedSchedules.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final schedule = paginatedSchedules[index];
                            final isDeleted = schedule.isDeleted;
                            
                            return ExpansionTile(
                                onExpansionChanged: (isExpanded) {
                                  if (isExpanded && schedule.recurrenceType != ScheduleRecurrenceType.oneTime) {
                                    _fetchChildSchedules(schedule.id);
                                    setState(() {
                                      _expandedScheduleIds.add(schedule.id);
                                    });
                                  } else if (!isExpanded) {
                                    setState(() {
                                      _expandedScheduleIds.remove(schedule.id);
                                    });
                                  }
                                },
                                leading: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(schedule.status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    _getStatusIcon(schedule.status),
                                    color: _getStatusColor(schedule.status),
                                    size: 32,
                                  ),
                                ),
                                title: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      schedule.scheduleName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        decoration: isDeleted ? TextDecoration.lineThrough : null,
                                        color: isDeleted ? Colors.grey[600] : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${schedule.branchName} - ${schedule.hubName}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDeleted ? Colors.grey[500] : Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      schedule.recurrenceType == ScheduleRecurrenceType.oneTime
                                          ? '${DateFormat('dd/MM/yyyy').format(schedule.scheduledDate)} • ${schedule.startTime} - ${schedule.endTime}'
                                          : schedule.recurrenceEndDate != null
                                              ? '${DateFormat('dd/MM/yyyy').format(schedule.scheduledDate)} - ${DateFormat('dd/MM/yyyy').format(schedule.recurrenceEndDate!)} • ${schedule.startTime} - ${schedule.endTime}'
                                              : '${DateFormat('dd/MM/yyyy').format(schedule.scheduledDate)} - Ongoing • ${schedule.startTime} - ${schedule.endTime}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDeleted ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${schedule.visibilityScopeDisplay} • ${schedule.totalProducts} products',
                                      style: TextStyle(
                                        color: isDeleted ? Colors.grey[500] : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.blue[200]!),
                                          ),
                                          child: Text(
                                            _getRecurrenceDisplay(schedule),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.green[200]!),
                                          ),
                                          child: Text(
                                            _getTimeDisplay(schedule),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        if (schedule.recurrenceType != ScheduleRecurrenceType.oneTime && schedule.recurrenceEndDate != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Until ${DateFormat('dd/MM/yyyy').format(schedule.recurrenceEndDate!)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(schedule.status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        schedule.statusCategoryDisplay,
                                        style: TextStyle(
                                          color: _getStatusColor(schedule.status),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: 'Update Schedule',
                                      onPressed: schedule.isActive ? () {
                                        _showUpdateScheduleDialog(schedule);
                                      } : null,
                                    ),
                                    Switch(
                                      value: schedule.isActive,
                                      activeColor: Colors.green,
                                      onChanged: (value) {
                                        _showToggleConfirmation(schedule, value);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      color: Colors.red,
                                      onPressed: () {
                                        _showDeleteScheduleDialog(schedule);
                                      },
                                    ),
                                  ],
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (schedule.visibilityScope == ScheduleVisibilityScope.selectedApartments &&
                                            schedule.selectedApartmentNames.isNotEmpty)
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Apartments:',
                                                  style: TextStyle(fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 8,
                                                children: schedule.selectedApartmentNames
                                                    .map((name) => Chip(label: Text(name)))
                                                    .toList(),
                                              ),
                                              const SizedBox(height: 12),
                                            ],
                                          ),
                                        const Text('Products:',
                                            style: TextStyle(fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        ...schedule.products.map((product) => Card(
                                              child: Padding(
                                                padding: const EdgeInsets.all(12),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(product.productName,
                                                              style: const TextStyle(fontWeight: FontWeight.bold)),
                                                          Text(product.productCategory,
                                                              style: TextStyle(color: Colors.grey[600])),
                                                          if (product.farmerName != null)
                                                            Text('Farmer: ${product.farmerName}',
                                                                style: TextStyle(color: Colors.grey[600])),
                                                        ],
                                                      ),
                                                    ),
                                                    Text('₹${product.price.toStringAsFixed(0)}',
                                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                              ),
                                            )),
                                        if (schedule.recurrenceType != ScheduleRecurrenceType.oneTime &&
                                            _expandedScheduleIds.contains(schedule.id)) ...[
                                          const Divider(),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Child Schedules (${_childSchedulesCache[schedule.id]?.length ?? 0})',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          if (_childSchedulesCache[schedule.id] == null)
                                            const Center(child: CircularProgressIndicator())
                                          else if (_childSchedulesCache[schedule.id]!.isEmpty)
                                            const Text('No child schedules found')
                                          else
                                            ...(_childSchedulesCache[schedule.id]!.map((child) {
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 8),
                                                child: Container(
                                                  padding: const EdgeInsets.all(12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[50],
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey[200]!),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(Icons.event, size: 16, color: Colors.grey[600]),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        DateFormat('dd/MM/yyyy').format(child.scheduledDate),
                                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Text(
                                                        '${child.startTime} - ${child.endTime}',
                                                        style: TextStyle(color: Colors.grey[600]),
                                                      ),
                                                      const Spacer(),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: _getStatusColor(child.status).withOpacity(0.1),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Text(
                                                          child.statusCategoryDisplay,
                                                          style: TextStyle(
                                                            color: _getStatusColor(child.status),
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }).toList()),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                            ),
                            Text(
                              'Page $_currentPage of $totalPages',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _currentPage < totalPages
                                  ? () => setState(() => _currentPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading schedules: $error')),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.pending:
        return Colors.orange;
      case ScheduleStatus.inProgress:
        return Colors.blue;
      case ScheduleStatus.completed:
        return Colors.green;
      case ScheduleStatus.cancelled:
        return Colors.red;
    }
  }

  String _getRecurrenceDisplay(OperationalScheduleModel schedule) {
    switch (schedule.recurrenceType) {
      case ScheduleRecurrenceType.oneTime:
        return 'One Time';
      case ScheduleRecurrenceType.daily:
        return 'Daily';
      case ScheduleRecurrenceType.weekly:
        if (schedule.recurrenceDaysOfWeek.isNotEmpty) {
          final days = schedule.recurrenceDaysOfWeek.map((d) {
            switch (d) {
              case 1: return 'Mon';
              case 2: return 'Tue';
              case 3: return 'Wed';
              case 4: return 'Thu';
              case 5: return 'Fri';
              case 6: return 'Sat';
              case 7: return 'Sun';
              default: return '';
            }
          }).join(', ');
          return 'Weekly ($days)';
        }
        return 'Weekly';
      case ScheduleRecurrenceType.customDays:
        return 'Custom';
    }
  }

  String _getTimeDisplay(OperationalScheduleModel schedule) {
    // Check if it's full day (00:00 - 23:59)
    if (schedule.startTime == '00:00' && schedule.endTime == '23:59') {
      return 'Full Day';
    }
    return '${schedule.startTime} - ${schedule.endTime}';
  }

  IconData _getStatusIcon(ScheduleStatus status) {
    switch (status) {
      case ScheduleStatus.pending:
        return Icons.pending;
      case ScheduleStatus.inProgress:
        return Icons.play_circle_outline;
      case ScheduleStatus.completed:
        return Icons.check_circle_outline;
      case ScheduleStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 8,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showToggleConfirmation(OperationalScheduleModel schedule, bool newValue) {
    final isActivating = newValue;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isActivating ? 'Activate Schedule' : 'Deactivate Schedule',
          style: TextStyle(
            color: isActivating ? Colors.green[700] : Colors.red[700],
          ),
        ),
        content: Text(
          isActivating
              ? 'Are you sure you want to activate this schedule? Products will become visible to customers.'
              : 'Are you sure you want to deactivate this schedule? Products will be hidden from customers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final user = ref.read(currentUserProvider).value;
                if (user == null) return;

                final repository = ref.read(operationalScheduleRepositoryProvider);
                final updatedSchedule = schedule.copyWith(
                  isActive: newValue,
                  updatedAt: DateTime.now(),
                  updatedBy: user.id,
                );
                await repository.updateSchedule(
                  schedule.id,
                  updatedSchedule,
                  user.id,
                  user.role,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isActivating
                            ? 'Schedule activated successfully'
                            : 'Schedule deactivated successfully',
                      ),
                      backgroundColor: isActivating ? Colors.green : Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isActivating ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(isActivating ? 'Confirm' : 'Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteScheduleDialog(OperationalScheduleModel schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text('Are you sure you want to delete the schedule for ${schedule.branchName} - ${schedule.hubName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = ref.read(currentUserProvider).value;
                if (user == null) return;
                
                final repository = ref.read(operationalScheduleRepositoryProvider);
                await repository.deleteSchedule(schedule.id, user.id, user.role);
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Schedule deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUpdateScheduleDialog(OperationalScheduleModel schedule) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => UpdateOperationalScheduleDialog(schedule: schedule),
    ).then((result) {
      if (result == true) {
        ref.invalidate(scheduleStatsProvider);
      }
    });
  }

}

class _ProductManagementContent extends ConsumerStatefulWidget {
  const _ProductManagementContent();

  @override
  ConsumerState<_ProductManagementContent> createState() => _ProductManagementContentState();
}

class _ProductManagementContentState extends ConsumerState<_ProductManagementContent> {
  String? selectedCategoryFilter;
  String? selectedFarmerFilter;

  Widget _buildStatCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey[500],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final farmersAsync = ref.watch(farmersStreamProvider);

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product Management',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dashboard > Product Management',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => const AddProductDialog(),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // Filters
          Row(
            children: [
              Expanded(
                child: categoriesAsync.when(
                  data: (categories) {
                    final activeCategories = categories
                        .where((cat) => !cat.isDeleted && cat.isActive)
                        .toList();
                    
                    return DropdownButtonFormField<String>(
                      value: selectedCategoryFilter,
                      decoration: InputDecoration(
                        labelText: 'Filter by Category',
                        hintText: 'All Categories',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.category),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...activeCategories.map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedCategoryFilter = value;
                        });
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading categories'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: farmersAsync.when(
                  data: (farmers) {
                    final activeFarmers = farmers
                        .where((farmer) => !farmer.isDeleted && farmer.isActive)
                        .toList();
                    
                    return DropdownButtonFormField<String>(
                      value: selectedFarmerFilter,
                      decoration: InputDecoration(
                        labelText: 'Filter by Farmer',
                        hintText: 'All Farmers',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: const Icon(Icons.agriculture),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Farmers'),
                        ),
                        ...activeFarmers.map((farmer) => DropdownMenuItem(
                          value: farmer.id,
                          child: Text(farmer.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedFarmerFilter = value;
                        });
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading farmers'),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  setState(() {
                    selectedCategoryFilter = null;
                    selectedFarmerFilter = null;
                  });
                },
                icon: const Icon(Icons.clear),
                tooltip: 'Clear Filters',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Product List
          Expanded(
            child: productsAsync.when(
              data: (products) {
                // Apply filters
                final List<ProductModel> filteredProducts = List<ProductModel>.from(products);
                
                // Get category name from selected category ID
                String? selectedCategoryName;
                if (selectedCategoryFilter != null) {
                  final categories = categoriesAsync.value ?? [];
                  final selectedCategory = categories.firstWhere(
                    (cat) => cat.id == selectedCategoryFilter,
                    orElse: () => CategoryModel(
                      id: '',
                      name: '',
                      description: '',
                      isActive: true,
                      isDeleted: false,
                      createdAt: DateTime.now(),
                      createdBy: '',
                    ),
                  );
                  selectedCategoryName = selectedCategory.name;
                }
                
                if (selectedCategoryName != null && selectedCategoryName.isNotEmpty) {
                  filteredProducts.clear();
                  filteredProducts.addAll(
                    products.where((p) => p.category == selectedCategoryName).toList()
                  );
                }
                if (selectedFarmerFilter != null) {
                  final currentProducts = List<ProductModel>.from(filteredProducts);
                  filteredProducts.clear();
                  filteredProducts.addAll(
                    currentProducts.where((p) => p.farmerId == selectedFarmerFilter).toList()
                  );
                }
                
                // Calculate stats from filtered products
                final totalProducts = filteredProducts.length;
                final activeProducts = filteredProducts.where((p) => p.isActive).length;
                final inactiveProducts = filteredProducts.where((p) => !p.isActive).length;
                final deletedProducts = filteredProducts.where((p) => p.isDeleted).length;
                final totalStock = filteredProducts.fold<int>(0, (sum, p) => sum + p.stockQuantity);
                
                // Stats Cards
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total Products',
                            totalProducts.toString(),
                            'Filtered Results',
                            Icons.inventory_2,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Active Products',
                            activeProducts.toString(),
                            'Currently Active',
                            Icons.check_circle_outline,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Inactive Products',
                            inactiveProducts.toString(),
                            'Not Active',
                            Icons.cancel_outlined,
                            Colors.red,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Deleted Products',
                            deletedProducts.toString(),
                            'Soft Deleted',
                            Icons.delete_outline,
                            Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Total Stock',
                            totalStock.toString(),
                            'All Products',
                            Icons.warehouse,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Product List
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          if (filteredProducts.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Products Found',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Try adjusting your filters or add a new product',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Products (${filteredProducts.length})',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: filteredProducts.length,
                                    separatorBuilder: (context, index) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final product = filteredProducts[index];
                                      final isDeleted = product.isDeleted;
                                
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: isDeleted ? Colors.grey[100] : Colors.white,
                                          border: isDeleted ? Border.all(color: Colors.grey[300]!, width: 2) : null,
                                          borderRadius: isDeleted ? BorderRadius.circular(8) : null,
                                        ),
                                        child: ListTile(
                                          leading: Container(
                                            width: 60,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: isDeleted
                                                  ? Colors.grey.withOpacity(0.2)
                                                  : (product.isActive
                                                      ? Colors.green.withOpacity(0.1)
                                                      : Colors.red.withOpacity(0.1)),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(7),
                                              child: Image.network(
                                                product.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return const Icon(Icons.broken_image);
                                                },
                                              ),
                                            ),
                                          ),
                                          title: Text(
                                            product.displayName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                                              color: isDeleted ? Colors.grey[600] : null,
                                            ),
                                          ),
                                          subtitle: Consumer(
                                            builder: (context, ref, child) {
                                              final farmersAsync = ref.watch(farmersStreamProvider);
                                              return farmersAsync.when(
                                                data: (farmers) {
                                                  String farmerName = 'Not Assigned';
                                                  if (product.farmerId != null && product.farmerId!.isNotEmpty) {
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
                                                    farmerName = farmer.name;
                                                  }
                                                  return Text(
                                                    '${product.name} • ${product.category} • ₹${product.price}/${product.unit}\nFarmer: $farmerName • Stock: ${product.stockQuantity}',
                                                    style: TextStyle(
                                                      color: isDeleted ? Colors.grey[500] : null,
                                                    ),
                                                  );
                                                },
                                                loading: () => Text(
                                                  '${product.name} • ${product.category} • ₹${product.price}/${product.unit}\nStock: ${product.stockQuantity}',
                                                  style: TextStyle(
                                                    color: isDeleted ? Colors.grey[500] : null,
                                                  ),
                                                ),
                                                error: (_, __) => Text(
                                                  '${product.name} • ${product.category} • ₹${product.price}/${product.unit}\nStock: ${product.stockQuantity}',
                                                  style: TextStyle(
                                                    color: isDeleted ? Colors.grey[500] : null,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isDeleted) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.withOpacity(0.2),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    'Deleted',
                                                    style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: () async {
                                                    try {
                                                      final user = ref.read(currentUserProvider).value;
                                                      if (user == null) return;
                                                      
                                                      final repository = ref.read(productRepositoryProvider);
                                                      await repository.restoreProduct(
                                                        product.id,
                                                        user.id,
                                                        user.role,
                                                      );
                                                      
                                                      ref.invalidate(productStatsProvider);
                                                      
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Product restored successfully'),
                                                            backgroundColor: Colors.green,
                                                          ),
                                                        );
                                                      }
                                                    } catch (e) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('Error: $e'),
                                                            backgroundColor: Colors.red,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  },
                                                  icon: const Icon(Icons.restore, size: 18),
                                                  label: const Text('Restore'),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green[700],
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 8,
                                                    ),
                                                  ),
                                                ),
                                              ] else ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: product.isActive
                                                        ? Colors.green.withOpacity(0.1)
                                                        : Colors.red.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    product.isActive ? 'Active' : 'Inactive',
                                                    style: TextStyle(
                                                      color: product.isActive
                                                          ? Colors.green[700]
                                                          : Colors.red[700],
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => EditProductDialog(
                                                        product: product,
                                                      ),
                                                    );
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline),
                                                  color: Colors.red,
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (context) => DeleteProductDialog(
                                                        product: product,
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error loading products: $error')),
            ),
          ),
        ],
      ),
    );
  }

}
