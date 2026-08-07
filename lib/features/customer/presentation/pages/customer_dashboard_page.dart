import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';
import 'package:f2c/features/customer/providers/customer_providers.dart';
import 'package:f2c/features/customer/providers/schedule_cart_provider.dart';
import 'package:f2c/features/customer/presentation/pages/cart_page.dart';
import 'package:f2c/features/customer/presentation/pages/order_history_page_new.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';

class CustomerDashboardPage extends ConsumerStatefulWidget {
  const CustomerDashboardPage({super.key});

  @override
  ConsumerState<CustomerDashboardPage> createState() => _CustomerDashboardPageState();
}

class _CustomerDashboardPageState extends ConsumerState<CustomerDashboardPage> {
  String _selectedCategory = 'All';
  String? _selectedFarmer;
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarShadow = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && !_showAppBarShadow) {
        setState(() => _showAppBarShadow = true);
      } else if (_scrollController.offset <= 10 && _showAppBarShadow) {
        setState(() => _showAppBarShadow = false);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // Get display string for delivery date based on schedule type
  String _getDeliveryDateDisplay(OperationalScheduleModel schedule) {
    // For one-time schedules, show the full date
    if (schedule.recurrenceType == ScheduleRecurrenceType.oneTime) {
      final date = schedule.deliveryDate ?? schedule.scheduledDate;
      return DateFormat('EEE, dd MMM yyyy').format(date);
    }
    
    // For recurring schedules (daily, weekly, custom days), show day(s) of week
    if (schedule.recurrenceType == ScheduleRecurrenceType.daily) {
      return 'Every Day';
    }
    
    if (schedule.recurrenceType == ScheduleRecurrenceType.weekly ||
        schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
      final daysOfWeek = schedule.deliveryDaysOfWeek.isNotEmpty 
          ? schedule.deliveryDaysOfWeek 
          : schedule.recurrenceDaysOfWeek;
      
      if (daysOfWeek.isEmpty) {
        return 'No delivery days set';
      }
      
      // Convert day numbers to day names
      // Note: deliveryDaysOfWeek uses 0-6 (Sun-Sat), but handle both 0-6 and 1-7 formats
      final dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
      final sortedDays = List<int>.from(daysOfWeek)..sort();
      final dayNamesList = sortedDays.where((day) => day >= 0 && day <= 7).map((day) {
        // Handle both 0-6 (Sun-Sat) and 1-7 (Mon-Sun) formats
        // 0 = Sunday, 1 = Monday, ..., 6 = Saturday
        // 7 = Sunday (alternative format)
        final index = day == 7 ? 0 : day.clamp(0, 6);
        return dayNames[index];
      }).toList();
      
      // Format based on number of days
      if (dayNamesList.length == 1) {
        return 'Every ${dayNamesList[0]}';
      } else if (dayNamesList.length == 7) {
        return 'Every Day';
      } else if (dayNamesList.length <= 3) {
        return dayNamesList.join(', ');
      } else {
        // Show first 2 days and count
        return '${dayNamesList[0]}, ${dayNamesList[1]} +${dayNamesList.length - 2} more';
      }
    }
    
    // Fallback to showing next occurrence date
    final date = _getNextOccurrenceDate(schedule);
    return DateFormat('EEE, dd MMM yyyy').format(date);
  }

  // Calculate the next occurrence date for a schedule based on its recurrence type
  DateTime _getNextOccurrenceDate(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    print('DEBUG _getNextOccurrenceDate: schedule=${schedule.scheduleName}, recurrenceType=${schedule.recurrenceType}, recurrenceDaysOfWeek=${schedule.recurrenceDaysOfWeek}, today.weekday=${today.weekday}');
    
    // For one-time schedules, return the scheduled date
    if (schedule.recurrenceType == ScheduleRecurrenceType.oneTime) {
      final result = schedule.deliveryDate ?? schedule.scheduledDate;
      print('DEBUG: One-time schedule, returning $result');
      return result;
    }
    
    // For daily schedules, return today if within range, otherwise start date
    if (schedule.recurrenceType == ScheduleRecurrenceType.daily) {
      final scheduleDate = DateTime(
        schedule.scheduledDate.year,
        schedule.scheduledDate.month,
        schedule.scheduledDate.day,
      );
      
      if (today.isBefore(scheduleDate)) {
        print('DEBUG: Daily schedule, today before start, returning $scheduleDate');
        return scheduleDate;
      }
      print('DEBUG: Daily schedule, returning today $today');
      return today;
    }
    
    // For weekly and custom days schedules, find the next matching day
    if (schedule.recurrenceType == ScheduleRecurrenceType.weekly ||
        schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
      final scheduleDate = DateTime(
        schedule.scheduledDate.year,
        schedule.scheduledDate.month,
        schedule.scheduledDate.day,
      );
      
      // Use deliveryDaysOfWeek if available, otherwise fall back to recurrenceDaysOfWeek
      final daysOfWeek = schedule.deliveryDaysOfWeek.isNotEmpty 
          ? schedule.deliveryDaysOfWeek 
          : schedule.recurrenceDaysOfWeek;
      
      // Start from today or schedule start date, whichever is later
      var checkDate = today.isBefore(scheduleDate) ? scheduleDate : today;
      print('DEBUG: Weekly/Custom schedule, starting check from $checkDate, deliveryDaysOfWeek=${schedule.deliveryDaysOfWeek}, using daysOfWeek=$daysOfWeek');
      
      // Look for the next occurrence within the next 14 days (2 weeks to ensure we find it)
      for (int i = 0; i < 14; i++) {
        // Convert weekday: DateTime uses 1-7 (Mon-Sun), but we store 0-6 (Sun-Sat) in deliveryDaysOfWeek
        final checkWeekday = checkDate.weekday == 7 ? 0 : checkDate.weekday; // Convert Sunday from 7 to 0
        print('DEBUG: Checking day $i: checkDate=$checkDate, weekday=${checkDate.weekday}, converted=$checkWeekday, contains=${daysOfWeek.contains(checkWeekday)}');
        if (daysOfWeek.contains(checkWeekday)) {
          print('DEBUG: Found matching day: $checkDate');
          return checkDate;
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }
      
      // Fallback to scheduled date
      print('DEBUG: No matching day found, returning scheduleDate $scheduleDate');
      return scheduleDate;
    }
    
    final fallback = schedule.deliveryDate ?? schedule.scheduledDate;
    print('DEBUG: Fallback, returning $fallback');
    return fallback;
  }

  // Calculate the last day when ordering is available (max day in recurrenceDaysOfWeek)
  DateTime _getLastOrderingDate(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // For one-time schedules, return the scheduled date
    if (schedule.recurrenceType == ScheduleRecurrenceType.oneTime) {
      return schedule.scheduledDate;
    }
    
    // For daily schedules, ordering is available every day, so return today
    if (schedule.recurrenceType == ScheduleRecurrenceType.daily) {
      final scheduleDate = DateTime(
        schedule.scheduledDate.year,
        schedule.scheduledDate.month,
        schedule.scheduledDate.day,
      );
      
      if (today.isBefore(scheduleDate)) {
        return scheduleDate;
      }
      return today;
    }
    
    // For weekly and custom days schedules, find the next occurrence of the max day
    if (schedule.recurrenceType == ScheduleRecurrenceType.weekly ||
        schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
      if (schedule.recurrenceDaysOfWeek.isEmpty) {
        return schedule.scheduledDate;
      }
      
      // Find the maximum day in recurrenceDaysOfWeek
      final maxDay = schedule.recurrenceDaysOfWeek.reduce((a, b) => a > b ? a : b);
      
      final scheduleDate = DateTime(
        schedule.scheduledDate.year,
        schedule.scheduledDate.month,
        schedule.scheduledDate.day,
      );
      
      // Start from today or schedule start date, whichever is later
      var checkDate = today.isBefore(scheduleDate) ? scheduleDate : today;
      
      // Look for the next occurrence of maxDay within the next 14 days
      for (int i = 0; i < 14; i++) {
        if (checkDate.weekday == maxDay) {
          return checkDate;
        }
        checkDate = checkDate.add(const Duration(days: 1));
      }
      
      // Fallback to scheduled date
      return scheduleDate;
    }
    
    return schedule.scheduledDate;
  }

  // Check if schedule is past cutoff time
  bool _isPastCutoff(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final cutoffDate = _getLastOrderingDate(schedule);
    
    // Parse end time
    try {
      final timeParts = schedule.endTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final cutoffDateTime = DateTime(
          cutoffDate.year,
          cutoffDate.month,
          cutoffDate.day,
          hour,
          minute,
        );
        return now.isAfter(cutoffDateTime);
      }
    } catch (e) {
      print('Error parsing time: $e');
    }
    
    return false;
  }

  // Get time remaining until cutoff
  String _getTimeRemaining(OperationalScheduleModel schedule) {
    final now = DateTime.now();
    final cutoffDate = _getLastOrderingDate(schedule);
    
    try {
      final timeParts = schedule.endTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final cutoffDateTime = DateTime(
          cutoffDate.year,
          cutoffDate.month,
          cutoffDate.day,
          hour,
          minute,
        );
        
        if (now.isAfter(cutoffDateTime)) {
          return 'Cutoff passed';
        }
        
        final duration = cutoffDateTime.difference(now);
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        
        if (hours > 24) {
          final days = hours ~/ 24;
          return '$days day${days > 1 ? 's' : ''} left';
        } else if (hours > 0) {
          return '$hours hr${hours > 1 ? 's' : ''} $minutes min left';
        } else {
          return '$minutes min left';
        }
      }
    } catch (e) {
      print('Error calculating time: $e');
    }
    
    return '';
  }

  int _getCrossAxisCount(double width) {
    if (width < 600) return 2; // Mobile - 2 columns
    if (width < 900) return 3; // Tablet
    if (width < 1200) return 4; // Small desktop
    return 5; // Large desktop
  }

  bool _isMobile(double width) => width < 600;

  bool _isDiscreteUnit(String unit) {
    final discreteUnits = ['box', 'piece', 'bunch', 'packet', 'dozen', 'unit'];
    final unitLower = unit.toLowerCase();
    
    // Check if it's a discrete unit
    if (discreteUnits.contains(unitLower)) return true;
    
    // Check for gram-based units (e.g., 50g, 100g, 250g)
    // These should be treated as discrete (increment by whole units)
    final gramMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*g(?:ram)?s?$').firstMatch(unitLower);
    if (gramMatch != null) return true;
    
    return false;
  }

  double _getQuantityIncrement(String unit) {
    final unitLower = unit.toLowerCase();
    
    // Discrete units increment by 1
    if (_isDiscreteUnit(unit)) return 1.0;
    
    // Kg and liter increment by 0.25
    if (unitLower == 'kg' || unitLower.contains('kilogram') || 
        unitLower == 'l' || unitLower.contains('liter')) {
      return 0.25;
    }
    
    // Default increment
    return 0.25;
  }

  String _formatQuantity(double quantity, String unit) {
    final unitLower = unit.toLowerCase();
    
    // Check for gram-based units (e.g., 50g, 100g, 250g)
    final gramMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*g(?:ram)?s?$').firstMatch(unitLower);
    if (gramMatch != null) {
      final baseGrams = double.parse(gramMatch.group(1)!);
      final totalGrams = (quantity * baseGrams).toInt();
      return '${totalGrams}g';
    }
    
    // For kg, show fractions or decimals
    if (unitLower == 'kg' || unitLower.contains('kilogram')) {
      if (quantity == 0.25) return '1/4 kg';
      if (quantity == 0.5) return '1/2 kg';
      if (quantity == 0.75) return '3/4 kg';
      if (quantity == quantity.roundToDouble()) {
        return '${quantity.toInt()} kg';
      }
      return '${quantity.toStringAsFixed(2)} kg';
    }
    
    // For discrete units, show whole numbers
    if (_isDiscreteUnit(unit)) {
      return quantity.toInt().toString();
    }
    
    // Default: show with 2 decimals
    return quantity.toStringAsFixed(2);
  }

  void _showMobileCart() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CartPage()),
    );
  }

  void _showMobileCartOld() {
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
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              Expanded(child: _buildCartSummary(scrollController)),
            ],
          ),
        ),
      ),
    );
  }

  void _showProductDescription(ProductModel product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                product.description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
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
    final cartCount = ref.watch(cartCountProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: customerAsync.when(
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer profile not found. Please contact admin.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = _isMobile(constraints.maxWidth);
              
              return Stack(
                children: [
                  CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // Modern App Bar
                      SliverAppBar(
                        expandedHeight: isMobile ? 180 : 200,
                        floating: false,
                        pinned: true,
                        elevation: _showAppBarShadow ? 4 : 0,
                        backgroundColor: const Color(0xFF00C853),
                        flexibleSpace: FlexibleSpaceBar(
                          background: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF00C853),
                                  Color(0xFF00E676),
                                ],
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 16 : 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Color(0xFF00C853),
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Delivering to',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Text(
                                                customer.apartmentName,
                                                style: const TextStyle(
                                                  color: Colors.white,
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
                                    const SizedBox(height: 16),
                                    schedulesAsync.when(
                                      data: (schedules) {
                                        if (schedules.isEmpty) {
                                          return Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(0.3),
                                              ),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.info_outline, color: Colors.white, size: 18),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'No deliveries scheduled for today',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.access_time, color: Colors.white, size: 18),
                                              const SizedBox(width: 8),
                                              const Expanded(
                                                child: Text(
                                                  'Next delivery in 5d 0h',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'Available',
                                                  style: TextStyle(
                                                    color: Color(0xFF00C853),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
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
                          ),
                        ),
                        actions: [
                          // Orders button (desktop)
                          if (!isMobile)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OrderHistoryPageNew()),
                                );
                              },
                              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 20),
                              label: const Text(
                                'Orders',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          // Orders button (mobile)
                          if (isMobile)
                            IconButton(
                              icon: const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const OrderHistoryPageNew()),
                                );
                              },
                            ),
                          // Cart button
                          IconButton(
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 26),
                                if (cartCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Text(
                                        '$cartCount',
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CartPage()),
                              );
                            },
                          ),
                          // Menu button (mobile) or Logout (desktop)
                          if (isMobile)
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onSelected: (value) {
                                switch (value) {
                                  case 'cart':
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => const CartPage()),
                                    );
                                    break;
                                  case 'logout':
                                    _handleLogout();
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'cart',
                                  child: Row(
                                    children: [
                                      Icon(Icons.shopping_bag),
                                      SizedBox(width: 12),
                                      Text('Cart'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'logout',
                                  child: Row(
                                    children: [
                                      Icon(Icons.logout, color: Colors.red),
                                      SizedBox(width: 12),
                                      Text('Logout', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.logout, color: Colors.white, size: 24),
                              onPressed: _handleLogout,
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),

                      // Products Content
                      SliverToBoxAdapter(
                        child: productsAsync.when(
                          data: (products) => _buildProductList(products, constraints.maxWidth),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stack) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text('Error: $error'),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Floating Cart Button (Mobile)
                  if (isMobile && cartCount > 0)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _showMobileCart,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00C853), Color(0xFF00E676)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$cartCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'View Cart',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${ref.read(cartTotalProvider).toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
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
    );
  }

  Widget _buildProductList(List<ProductWithSchedule> products, double screenWidth) {
    final isMobile = _isMobile(screenWidth);
    final schedulesAsync = ref.watch(activeSchedulesProvider);

    return schedulesAsync.when(
      data: (schedules) {
        if (schedules.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 24),
                  Text(
                    'No schedules available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for fresh products',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Padding(
              padding: EdgeInsets.fromLTRB(isMobile ? 16 : 24, 24, isMobile ? 16 : 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.local_grocery_store,
                      color: Color(0xFF00C853),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Available Schedules',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Schedule Accordions
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: schedules.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildScheduleAccordion(schedules[index], products, isMobile);
                },
              ),
            ),

            SizedBox(height: isMobile ? 100 : 48),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildScheduleAccordion(OperationalScheduleModel schedule, List<ProductWithSchedule> allProducts, bool isMobile) {
    // Check cutoff status
    final isPastCutoff = _isPastCutoff(schedule);
    final timeRemaining = _getTimeRemaining(schedule);

    // Get products for this schedule
    final scheduleProducts = schedule.products
        .map((sp) => allProducts.firstWhere(
              (p) => p.product.id == sp.productId,
              orElse: () => allProducts.first,
            ))
        .toList();

    // Filter by search query
    final filteredProducts = _searchQuery.isEmpty
        ? scheduleProducts
        : scheduleProducts.where((p) {
            final searchLower = _searchQuery.toLowerCase();
            final productName = p.product.displayName.toLowerCase();
            final category = p.product.category.toLowerCase();
            final farmerName = p.farmerName?.toLowerCase() ?? '';
            return productName.contains(searchLower) ||
                category.contains(searchLower) ||
                farmerName.contains(searchLower);
          }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isPastCutoff ? Colors.red.shade300 : Colors.grey.shade200,
          width: isPastCutoff ? 2 : 1,
        ),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPastCutoff 
                    ? Colors.red.shade50 
                    : const Color(0xFF00C853).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPastCutoff ? Icons.lock_clock : Icons.calendar_today,
                color: isPastCutoff ? Colors.red : const Color(0xFF00C853),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          schedule.scheduleName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isPastCutoff)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 12, color: Colors.red.shade700),
                              const SizedBox(width: 4),
                              Text(
                                'CUTOFF PASSED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (!isPastCutoff)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              timeRemaining,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag, 
                            size: 14, 
                            color: isPastCutoff ? Colors.red[700] : Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Order by: ${DateFormat('EEE, dd MMM').format(_getLastOrderingDate(schedule))} at ${schedule.endTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isPastCutoff ? Colors.red[700] : Colors.orange[700],
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${schedule.startTime} - ${schedule.endTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              schedule.hubName,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${filteredProducts.length} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
        children: [
          // Delivery Information
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.green[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery Information',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _getDeliveryDateDisplay(schedule),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                if (schedule.deliveryStartTime != null && schedule.deliveryEndTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${schedule.deliveryStartTime} - ${schedule.deliveryEndTime}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${schedule.startTime} - ${schedule.endTime}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (filteredProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No products available',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                separatorBuilder: (context, index) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  return _buildScheduleProductItem(filteredProducts[index], schedule, isMobile);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleProductItem(ProductWithSchedule productWithSchedule, OperationalScheduleModel schedule, bool isMobile) {
    final product = productWithSchedule.product;
    final scheduleProduct = schedule.products.firstWhere((sp) => sp.productId == product.id);
    final carts = ref.watch(scheduleCartsProvider);
    final scheduleCart = carts[schedule.id];
    final cartItem = scheduleCart?.items[product.id];
    final quantity = cartItem?.quantity ?? 0.0;
    final inCart = quantity > 0;
    final isDiscreteUnit = cartItem?.isDiscreteUnit ?? _isDiscreteUnit(product.unit);
    final quantityIncrement = cartItem?.quantityIncrement ?? _getQuantityIncrement(product.unit);
    final isPastCutoff = _isPastCutoff(schedule);

    return Row(
      children: [
        // Product Image
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: isMobile ? 60 : 80,
            height: isMobile ? 60 : 80,
            color: Colors.grey[100],
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Product Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '₹${scheduleProduct.price.toStringAsFixed(0)}/${product.unit}',
                    style: const TextStyle(
                      color: Color(0xFF00C853),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  if (productWithSchedule.farmerName != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        productWithSchedule.farmerName!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        // Add to Cart Button
        if (isPastCutoff)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 16, color: Colors.red.shade700),
                const SizedBox(width: 6),
                Text(
                  'Cutoff Passed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          )
        else if (!inCart)
          ElevatedButton(
            onPressed: () {
              try {
                ref.read(scheduleCartsProvider.notifier).addItem(
                  schedule,
                  CartItemModel(
                    productId: product.id,
                    productName: product.displayName,
                    productCategory: product.category,
                    price: scheduleProduct.price,
                    quantity: quantityIncrement,
                    unit: product.unit,
                    imageUrl: product.imageUrl,
                    farmerId: scheduleProduct.farmerId,
                    farmerName: productWithSchedule.farmerName,
                    scheduleId: schedule.id,
                    scheduleName: schedule.scheduleName,
                    isDiscreteUnit: isDiscreteUnit,
                    quantityIncrement: quantityIncrement,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceAll('Exception: ', '')),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C853),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Add', style: TextStyle(fontSize: 12)),
          )
        else
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.red,
                onPressed: () {
                  try {
                    ref.read(scheduleCartsProvider.notifier).decrementQuantity(schedule.id, product.id);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
              Text(
                _formatQuantity(quantity, product.unit),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFF00C853),
                onPressed: () {
                  try {
                    ref.read(scheduleCartsProvider.notifier).incrementQuantity(schedule.id, product.id);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(e.toString().replaceAll('Exception: ', '')),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
      ],
    );
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.logout();
      ref.invalidate(currentSessionProvider);
      if (context.mounted) {
        context.go(RouteNames.login);
      }
    }
  }

  Widget _buildCartSummary([ScrollController? scrollController]) {
    // This method is kept for backward compatibility with old modal bottom sheet
    // New implementation uses CartPage instead
    final cartCount = ref.watch(cartCountProvider);

    if (cartCount == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add items to get started',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    // Show message to navigate to cart page
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart, size: 80, color: Colors.green[700]),
            const SizedBox(height: 16),
            Text(
              'You have $cartCount item${cartCount > 1 ? 's' : ''} in cart',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "View Cart" to see your items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close modal if open
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CartPage()),
                );
              },
              icon: const Icon(Icons.shopping_cart),
              label: const Text('View Cart'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
