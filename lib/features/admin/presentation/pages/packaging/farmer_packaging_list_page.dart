import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'dart:html' as html;

enum DateFilterType {
  thisWeek,
  thisMonth,
  thisQuarter,
  fiscalYear,
  calendarYear,
  custom,
}

class FarmerPackagingListPage extends ConsumerStatefulWidget {
  const FarmerPackagingListPage({super.key});

  @override
  ConsumerState<FarmerPackagingListPage> createState() => _FarmerPackagingListPageState();
}

class _FarmerPackagingListPageState extends ConsumerState<FarmerPackagingListPage> {
  String _selectedDateFilter = 'This Week';
  DateFilterType _dateFilterType = DateFilterType.thisWeek;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    _applyDateFilter('This Week');
  }

  void _applyDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      _selectedDateFilter = filter;
      
      switch (filter) {
        case 'This Week':
          _dateFilterType = DateFilterType.thisWeek;
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now.add(Duration(days: 7 - now.weekday));
          break;
        case 'This Month':
          _dateFilterType = DateFilterType.thisMonth;
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Quarter':
          _dateFilterType = DateFilterType.thisQuarter;
          final quarter = ((now.month - 1) ~/ 3) + 1;
          final startMonth = (quarter - 1) * 3 + 1;
          _startDate = DateTime(now.year, startMonth, 1);
          _endDate = DateTime(now.year, startMonth + 3, 0);
          break;
        case 'Fiscal Year':
          _dateFilterType = DateFilterType.fiscalYear;
          // Assuming fiscal year starts in April
          if (now.month >= 4) {
            _startDate = DateTime(now.year, 4, 1);
            _endDate = DateTime(now.year + 1, 3, 31);
          } else {
            _startDate = DateTime(now.year - 1, 4, 1);
            _endDate = DateTime(now.year, 3, 31);
          }
          break;
        case 'Calendar Year':
          _dateFilterType = DateFilterType.calendarYear;
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
        case 'Custom':
          _dateFilterType = DateFilterType.custom;
          // Will be set by date picker
          break;
      }
    });
  }

  Future<void> _showDateRangePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now(),
        end: _endDate ?? DateTime.now(),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateFilter = 'Custom';
        _dateFilterType = DateFilterType.custom;
      });
    }
  }

  Future<void> _exportToCSV() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing CSV files...'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Fetch only confirmed orders (before packaging starts)
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('isDeleted', isEqualTo: false)
          .where('status', isEqualTo: 'confirmed')
          .get();

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromFirestore(doc))
          .where((order) {
            if (_startDate == null || _endDate == null) return true;
            final deliveryDate = order.deliveryDate ?? order.createdAt;
            final dateOnly = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
            final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
            final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            return dateOnly.isAfter(start.subtract(const Duration(days: 1))) && 
                   dateOnly.isBefore(end.add(const Duration(days: 1)));
          })
          .toList();

      if (orders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No orders found for the selected date range')),
        );
        return;
      }

      // Group orders by farmer and schedule
      final Map<String, Map<String, Set<String>>> farmerScheduleOrders = {};
      
      for (final order in orders) {
        for (final item in order.items) {
          final farmerId = item.farmerId ?? 'unknown';
          // Use scheduleId if available, otherwise use scheduleName + deliveryDate as key
          final scheduleKey = order.scheduleId ?? 
              '${order.scheduleName ?? "No Schedule"}_${DateFormat('yyyy-MM-dd').format(order.deliveryDate ?? order.createdAt)}';
          
          if (!farmerScheduleOrders.containsKey(farmerId)) {
            farmerScheduleOrders[farmerId] = {};
          }
          if (!farmerScheduleOrders[farmerId]!.containsKey(scheduleKey)) {
            farmerScheduleOrders[farmerId]![scheduleKey] = {};
          }
          farmerScheduleOrders[farmerId]![scheduleKey]!.add(order.id);
        }
      }

      // Build CSV content
      final StringBuffer csvBuffer = StringBuffer();
      
      // Add BOM for Excel compatibility
      csvBuffer.write('\uFEFF');
      
      // CSV Header
      csvBuffer.writeln('Farmer Name,Farmer Location,Delivery Date,Schedule Name,Product Name,Product Category,Unit Quantity,Unit,Total Quantity,Total Orders,Total Items');

      // Process each farmer
      for (final farmerId in farmerScheduleOrders.keys) {
        // Fetch farmer details
        final farmerDoc = await FirebaseFirestore.instance.collection('farmers').doc(farmerId).get();
        final farmerName = farmerDoc.data()?['name'] ?? 'Unknown Farmer';
        final farmerLocation = farmerDoc.data()?['location'] ?? '';

        // Process each schedule for this farmer
        for (final scheduleKey in farmerScheduleOrders[farmerId]!.keys) {
          final orderIds = farmerScheduleOrders[farmerId]![scheduleKey]!;
          
          // Get schedule details from first order
          final firstOrder = orders.firstWhere((o) => o.id == orderIds.first);
          final scheduleName = firstOrder.scheduleName ?? 'Unknown Schedule';
          final deliveryDate = firstOrder.deliveryDate ?? firstOrder.createdAt;
          final deliveryDateStr = DateFormat('dd/MM/yyyy').format(deliveryDate);

          // Count unique orders for this farmer in this schedule
          final orderCount = orderIds.length;

          // Aggregate products for this farmer in this schedule
          // NOTE: This report uses ORIGINAL ORDERED quantities from confirmed orders
          // Packaging variations (actual weights/quantities) do NOT affect this report
          final Map<String, double> productQuantities = {};
          final Map<String, String> productUnits = {};
          final Map<String, String> productNames = {};
          final Map<String, String> productCategories = {};

          // Process only orders for this schedule
          for (final orderId in orderIds) {
            final order = orders.firstWhere((o) => o.id == orderId);
            
            // Only process items from this specific farmer
            // Using item.quantity (original ordered quantity, not actual packaging quantity)
            for (final item in order.items) {
              if (item.farmerId == farmerId) {
                final key = '${item.productName}_${item.unit}_${item.productCategory}';
                if (!productQuantities.containsKey(key)) {
                  productQuantities[key] = 0;
                  productUnits[key] = item.unit;
                  productNames[key] = item.productName;
                  productCategories[key] = item.productCategory;
                }
                // Add original ordered quantity (not affected by packaging variations)
                productQuantities[key] = (productQuantities[key] ?? 0) + item.quantity;
              }
            }
          }

          final itemCount = productQuantities.length;

          // Write each product as a row
          for (final productKey in productQuantities.keys) {
            final productName = productNames[productKey] ?? '';
            final productCategory = productCategories[productKey] ?? '';
            final aggregatedQuantity = productQuantities[productKey] ?? 0;
            final unit = productUnits[productKey] ?? '';
            
            // Unit Quantity: aggregated quantity value
            // Total Quantity: aggregated quantity with unit (e.g., "5.5 kg")
            final unitQuantity = aggregatedQuantity;
            final totalQuantity = '$aggregatedQuantity $unit';

            csvBuffer.writeln(
              '"$farmerName","$farmerLocation","$deliveryDateStr","$scheduleName","$productName","$productCategory",$unitQuantity,"$unit","$totalQuantity",$orderCount,$itemCount'
            );
          }
        }
      }

      // Create and download Schedule Details CSV file
      final scheduleDetailsCSV = csvBuffer.toString();
      
      final blob1 = html.Blob([scheduleDetailsCSV], 'text/csv;charset=utf-8');
      final url1 = html.Url.createObjectUrlFromBlob(blob1);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final anchor1 = html.AnchorElement(href: url1)
        ..setAttribute('download', 'packaging_schedule_details_$timestamp.csv')
        ..click();
      html.Url.revokeObjectUrl(url1);

      // Now create Delivery Date Summary CSV
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay between downloads
      
      final StringBuffer summaryBuffer = StringBuffer();
      summaryBuffer.write('\uFEFF'); // BOM
      summaryBuffer.writeln('Farmer Name,Farmer Location,Delivery Date,Schedules,Product Name,Product Category,Unit Quantity,Unit,Total Quantity,Total Orders,Total Items');
      
      // Group by farmer and delivery date
      final Map<String, Map<String, Map<String, dynamic>>> farmerDateSummary = {};
      
      for (final farmerId in farmerScheduleOrders.keys) {
        final farmerDoc = await FirebaseFirestore.instance.collection('farmers').doc(farmerId).get();
        final farmerName = farmerDoc.data()?['name'] ?? 'Unknown Farmer';
        final farmerLocation = farmerDoc.data()?['location'] ?? '';
        
        for (final scheduleKey in farmerScheduleOrders[farmerId]!.keys) {
          final orderIds = farmerScheduleOrders[farmerId]![scheduleKey]!;
          final firstOrder = orders.firstWhere((o) => o.id == orderIds.first);
          final deliveryDate = firstOrder.deliveryDate ?? firstOrder.createdAt;
          final dateKey = '${deliveryDate.year}-${deliveryDate.month}-${deliveryDate.day}';
          final scheduleName = firstOrder.scheduleName ?? 'Unknown Schedule';
          
          if (!farmerDateSummary.containsKey(farmerId)) {
            farmerDateSummary[farmerId] = {};
          }
          if (!farmerDateSummary[farmerId]!.containsKey(dateKey)) {
            farmerDateSummary[farmerId]![dateKey] = {
              'farmerName': farmerName,
              'farmerLocation': farmerLocation,
              'deliveryDate': deliveryDate,
              'scheduleNames': <String>{},
              'orderIds': <String>{},
              'products': <String, double>{},
              'productUnits': <String, String>{},
              'productNames': <String, String>{},
              'productCategories': <String, String>{},
            };
          }
          
          // Add schedule name
          farmerDateSummary[farmerId]![dateKey]!['scheduleNames'].add(scheduleName);
          
          // Add order IDs
          for (final orderId in orderIds) {
            farmerDateSummary[farmerId]![dateKey]!['orderIds'].add(orderId);
          }
          
          // Aggregate products for this date
          for (final orderId in orderIds) {
            final order = orders.firstWhere((o) => o.id == orderId);
            for (final item in order.items) {
              if (item.farmerId == farmerId) {
                final key = '${item.productName}_${item.unit}_${item.productCategory}';
                final products = farmerDateSummary[farmerId]![dateKey]!['products'] as Map<String, double>;
                final productUnits = farmerDateSummary[farmerId]![dateKey]!['productUnits'] as Map<String, String>;
                final productNames = farmerDateSummary[farmerId]![dateKey]!['productNames'] as Map<String, String>;
                final productCategories = farmerDateSummary[farmerId]![dateKey]!['productCategories'] as Map<String, String>;
                
                if (!products.containsKey(key)) {
                  products[key] = 0;
                  productUnits[key] = item.unit;
                  productNames[key] = item.productName;
                  productCategories[key] = item.productCategory;
                }
                products[key] = (products[key] ?? 0) + item.quantity;
              }
            }
          }
        }
      }
      
      // Write summary CSV
      for (final farmerId in farmerDateSummary.keys) {
        for (final dateKey in farmerDateSummary[farmerId]!.keys) {
          final summary = farmerDateSummary[farmerId]![dateKey]!;
          final farmerName = summary['farmerName'];
          final farmerLocation = summary['farmerLocation'];
          final deliveryDate = summary['deliveryDate'] as DateTime;
          final deliveryDateStr = DateFormat('dd/MM/yyyy').format(deliveryDate);
          final scheduleNames = (summary['scheduleNames'] as Set<String>).join(', ');
          final orderIds = summary['orderIds'] as Set<String>;
          final products = summary['products'] as Map<String, double>;
          final productUnits = summary['productUnits'] as Map<String, String>;
          final productNames = summary['productNames'] as Map<String, String>;
          final productCategories = summary['productCategories'] as Map<String, String>;
          
          final totalOrders = orderIds.length;
          final totalItems = products.length;
          
          for (final productKey in products.keys) {
            final productName = productNames[productKey] ?? '';
            final productCategory = productCategories[productKey] ?? '';
            final aggregatedQuantity = products[productKey] ?? 0;
            final unit = productUnits[productKey] ?? '';
            
            // Unit Quantity: aggregated quantity value
            // Total Quantity: aggregated quantity with unit (e.g., "5.5 kg")
            final unitQuantity = aggregatedQuantity;
            final totalQuantity = '$aggregatedQuantity $unit';
            
            summaryBuffer.writeln(
              '"$farmerName","$farmerLocation","$deliveryDateStr","$scheduleNames","$productName","$productCategory",$unitQuantity,"$unit","$totalQuantity",$totalOrders,$totalItems'
            );
          }
        }
      }
      
      // Download summary CSV
      final summaryCSV = summaryBuffer.toString();
      
      final blob2 = html.Blob([summaryCSV], 'text/csv;charset=utf-8');
      final url2 = html.Url.createObjectUrlFromBlob(blob2);
      final anchor2 = html.AnchorElement(href: url2)
        ..setAttribute('download', 'packaging_delivery_summary_$timestamp.csv')
        ..click();
      html.Url.revokeObjectUrl(url2);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('2 CSV files exported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting CSV: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Farmer Packaging List'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export to CSV',
            onPressed: _exportToCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFiltersRow(),
          Expanded(
            child: _buildFarmerPackagingList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(6),
                color: Colors.grey[50],
              ),
              child: DropdownButton<String>(
                value: _selectedDateFilter,
                underline: const SizedBox(),
                isDense: true,
                isExpanded: true,
                style: const TextStyle(fontSize: 13),
                items: ['This Week', 'This Month', 'This Quarter', 'Fiscal Year', 'Calendar Year', 'Custom'].map((filter) {
                  return DropdownMenuItem(value: filter, child: Text(filter, style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (value) {
                  if (value == 'Custom') {
                    _showDateRangePicker();
                  } else {
                    _applyDateFilter(value!);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_selectedDateFilter == 'Custom' && _startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF4CAF50)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF4CAF50).withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4CAF50)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFarmerPackagingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('isDeleted', isEqualTo: false)
          .where('status', isEqualTo: 'confirmed')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final orders = snapshot.data!.docs
            .map((doc) => OrderModel.fromFirestore(doc))
            .where((order) {
              if (_startDate == null || _endDate == null) return true;
              final deliveryDate = order.deliveryDate ?? order.createdAt;
              final dateOnly = DateTime(deliveryDate.year, deliveryDate.month, deliveryDate.day);
              final start = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
              final end = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
              return dateOnly.isAfter(start.subtract(const Duration(days: 1))) && 
                     dateOnly.isBefore(end.add(const Duration(days: 1)));
            })
            .toList();

        if (orders.isEmpty) {
          return _buildEmptyState();
        }

        // Group orders by farmer and schedule
        final Map<String, Map<String, Set<String>>> farmerScheduleOrders = {};
        
        for (final order in orders) {
          for (final item in order.items) {
            final farmerId = item.farmerId ?? 'unknown';
            // Use scheduleId if available, otherwise use scheduleName + deliveryDate as key
            final scheduleKey = order.scheduleId ?? 
                '${order.scheduleName ?? "No Schedule"}_${DateFormat('yyyy-MM-dd').format(order.deliveryDate ?? order.createdAt)}';
            
            if (!farmerScheduleOrders.containsKey(farmerId)) {
              farmerScheduleOrders[farmerId] = {};
            }
            if (!farmerScheduleOrders[farmerId]!.containsKey(scheduleKey)) {
              farmerScheduleOrders[farmerId]![scheduleKey] = {};
            }
            farmerScheduleOrders[farmerId]![scheduleKey]!.add(order.id);
          }
        }

        // Convert to map with actual orders for UI rendering
        final Map<String, Map<String, List<OrderModel>>> farmerScheduleMap = {};
        for (final farmerId in farmerScheduleOrders.keys) {
          farmerScheduleMap[farmerId] = {};
          for (final scheduleKey in farmerScheduleOrders[farmerId]!.keys) {
            final orderIds = farmerScheduleOrders[farmerId]![scheduleKey]!;
            farmerScheduleMap[farmerId]![scheduleKey] = orders.where((o) => orderIds.contains(o.id)).toList();
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: farmerScheduleMap.length,
          itemBuilder: (context, index) {
            final farmerId = farmerScheduleMap.keys.elementAt(index);
            final scheduleMap = farmerScheduleMap[farmerId]!;
            
            return _buildFarmerCard(farmerId, scheduleMap);
          },
        );
      },
    );
  }

  Widget _buildFarmerCard(String farmerId, Map<String, List<OrderModel>> scheduleMap) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('farmers').doc(farmerId).get(),
      builder: (context, farmerSnapshot) {
        final farmerName = farmerSnapshot.data?.get('name') ?? 'Unknown Farmer';
        final farmerLocation = farmerSnapshot.data?.get('location') ?? '';

        // Aggregate products per schedule
        final Map<String, Map<String, double>> scheduleProductQuantities = {};
        final Map<String, Map<String, String>> scheduleProductUnits = {};
        final Map<String, Map<String, String>> scheduleProductNames = {};
        final Map<String, Map<String, String>> scheduleProductCategories = {};
        final List<String> scheduleLabels = [];
        final Map<String, int> scheduleOrderCounts = {};
        final Map<String, int> scheduleItemCounts = {};
        final Map<String, DateTime> scheduleDeliveryDates = {};

        for (final scheduleKey in scheduleMap.keys) {
          final orders = scheduleMap[scheduleKey]!;
          
          // Get schedule name and delivery date from first order
          final firstOrder = orders.first;
          final scheduleName = firstOrder.scheduleName ?? 'Unknown Schedule';
          final deliveryDate = firstOrder.deliveryDate ?? firstOrder.createdAt;
          
          scheduleLabels.add(scheduleName);
          scheduleDeliveryDates[scheduleKey] = deliveryDate;

          // Count unique orders for this schedule
          final uniqueOrderIds = orders.map((o) => o.id).toSet();
          scheduleOrderCounts[scheduleKey] = uniqueOrderIds.length;

          // Initialize product maps for this schedule
          scheduleProductQuantities[scheduleKey] = {};
          scheduleProductUnits[scheduleKey] = {};
          scheduleProductNames[scheduleKey] = {};
          scheduleProductCategories[scheduleKey] = {};

          for (final order in orders) {
            // Only process items from this specific farmer
            // Using original ordered quantities (not affected by packaging variations)
            for (final item in order.items) {
              if (item.farmerId == farmerId) {
                final key = '${item.productName}_${item.unit}_${item.productCategory}';
                if (!scheduleProductQuantities[scheduleKey]!.containsKey(key)) {
                  scheduleProductQuantities[scheduleKey]![key] = 0;
                  scheduleProductUnits[scheduleKey]![key] = item.unit;
                  scheduleProductNames[scheduleKey]![key] = item.productName;
                  scheduleProductCategories[scheduleKey]![key] = item.productCategory;
                }
                // Add original ordered quantity
                scheduleProductQuantities[scheduleKey]![key] = (scheduleProductQuantities[scheduleKey]![key] ?? 0) + item.quantity;
              }
            }
          }
          
          // Count items (unique products) for this schedule
          scheduleItemCounts[scheduleKey] = scheduleProductQuantities[scheduleKey]!.length;
        }

        // Create delivery date summaries (aggregate all schedules by delivery date)
        final Map<String, List<String>> deliveryDateSchedules = {};
        final Map<String, Map<String, double>> deliveryDateProductQuantities = {};
        final Map<String, Map<String, String>> deliveryDateProductUnits = {};
        final Map<String, Map<String, String>> deliveryDateProductNames = {};
        final Map<String, int> deliveryDateTotalOrders = {};
        final Map<String, int> deliveryDateTotalItems = {};
        
        for (final scheduleKey in scheduleMap.keys) {
          final deliveryDate = scheduleDeliveryDates[scheduleKey];
          if (deliveryDate == null) continue;
          
          final dateKey = '${deliveryDate.year}-${deliveryDate.month}-${deliveryDate.day}';
          final scheduleName = scheduleLabels[scheduleMap.keys.toList().indexOf(scheduleKey)];
          
          // Track schedules for this date
          if (!deliveryDateSchedules.containsKey(dateKey)) {
            deliveryDateSchedules[dateKey] = [];
            deliveryDateProductQuantities[dateKey] = {};
            deliveryDateProductUnits[dateKey] = {};
            deliveryDateProductNames[dateKey] = {};
            deliveryDateTotalOrders[dateKey] = 0;
            deliveryDateTotalItems[dateKey] = 0;
          }
          deliveryDateSchedules[dateKey]!.add(scheduleName);
          
          // Aggregate products for this date
          final scheduleProducts = scheduleProductQuantities[scheduleKey] ?? {};
          for (final productKey in scheduleProducts.keys) {
            if (!deliveryDateProductQuantities[dateKey]!.containsKey(productKey)) {
              deliveryDateProductQuantities[dateKey]![productKey] = 0;
              deliveryDateProductUnits[dateKey]![productKey] = scheduleProductUnits[scheduleKey]![productKey]!;
              deliveryDateProductNames[dateKey]![productKey] = scheduleProductNames[scheduleKey]![productKey]!;
            }
            deliveryDateProductQuantities[dateKey]![productKey] = 
                (deliveryDateProductQuantities[dateKey]![productKey] ?? 0) + scheduleProducts[productKey]!;
          }
          
          // Sum orders and items
          deliveryDateTotalOrders[dateKey] = (deliveryDateTotalOrders[dateKey] ?? 0) + (scheduleOrderCounts[scheduleKey] ?? 0);
        }
        
        // Calculate total items per date
        for (final dateKey in deliveryDateProductQuantities.keys) {
          deliveryDateTotalItems[dateKey] = deliveryDateProductQuantities[dateKey]!.length;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          child: ExpansionTile(
            title: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Icon(Icons.agriculture, color: Colors.green[700], size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farmerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (farmerLocation.isNotEmpty)
                        Text(
                          farmerLocation,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${scheduleMap.length} Schedules',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: scheduleLabels.take(3).map((scheduleLabel) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      scheduleLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue[700],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delivery Date Summaries
                    if (deliveryDateSchedules.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[300]!, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.summarize, size: 18, color: Colors.green[700]),
                                const SizedBox(width: 8),
                                const Text(
                                  'Delivery Date Summary',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...deliveryDateSchedules.keys.map((dateKey) {
                              final parts = dateKey.split('-');
                              final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                              final schedules = deliveryDateSchedules[dateKey] ?? [];
                              final totalOrders = deliveryDateTotalOrders[dateKey] ?? 0;
                              final totalItems = deliveryDateTotalItems[dateKey] ?? 0;
                              final products = deliveryDateProductQuantities[dateKey] ?? {};
                              final productUnits = deliveryDateProductUnits[dateKey] ?? {};
                              final productNames = deliveryDateProductNames[dateKey] ?? {};
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 14, color: Colors.green[700]),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('MMM dd, yyyy').format(date),
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green[800],
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$totalOrders Orders',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.orange[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[100],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            '$totalItems Items',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.blue[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Schedules: ${schedules.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(height: 1),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Total Products:',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ...products.entries.map((entry) {
                                      final productName = productNames[entry.key] ?? 'Unknown';
                                      final unit = productUnits[entry.key] ?? '';
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 3),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                productName,
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ),
                                            Text(
                                              '${entry.value} $unit',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                    ],
                    const Text(
                      'Schedule Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...scheduleMap.keys.map((scheduleKey) {
                      final scheduleLabel = scheduleLabels[scheduleMap.keys.toList().indexOf(scheduleKey)] ?? 'Unknown Schedule';
                      final deliveryDate = scheduleDeliveryDates[scheduleKey];
                      final orderCount = scheduleOrderCounts[scheduleKey] ?? 0;
                      final itemCount = scheduleItemCounts[scheduleKey] ?? 0;
                      final productQuantities = scheduleProductQuantities[scheduleKey] ?? {};
                      final productUnits = scheduleProductUnits[scheduleKey] ?? {};
                      final productNames = scheduleProductNames[scheduleKey] ?? {};
                      final productCategories = scheduleProductCategories[scheduleKey] ?? {};
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.schedule, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        scheduleLabel,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                      if (deliveryDate != null)
                                        Text(
                                          'Delivery: ${DateFormat('MMM dd, yyyy').format(deliveryDate)}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$orderCount Orders',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$itemCount Items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (productQuantities.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Products for this schedule',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...productQuantities.entries.map((entry) {
                                final unit = productUnits[entry.key] ?? '';
                                final productName = productNames[entry.key] ?? 'Unknown Product';
                                final productCategory = productCategories[entry.key] ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (productCategory.isNotEmpty)
                                              Text(
                                                productCategory,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${entry.value.toStringAsFixed(2)} $unit',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No packaging data found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the date filter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}
