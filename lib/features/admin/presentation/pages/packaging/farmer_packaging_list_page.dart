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
          .where('status', whereIn: ['confirmed', 'preparing', 'ready', 'in_transit', 'delivered'])
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

        // Group orders by farmer
        final Map<String, List<OrderModel>> ordersByFarmer = {};
        for (final order in orders) {
          for (final item in order.items) {
            final farmerId = item.farmerId ?? 'unknown';
            if (!ordersByFarmer.containsKey(farmerId)) {
              ordersByFarmer[farmerId] = [];
            }
            ordersByFarmer[farmerId]!.add(order);
          }
        }

        // Group by delivery date for each farmer
        final Map<String, Map<String, List<OrderModel>>> farmerDeliveryDateMap = {};
        for (final farmerId in ordersByFarmer.keys) {
          final farmerOrders = ordersByFarmer[farmerId]!;
          final Map<String, List<OrderModel>> deliveryDateMap = {};
          
          for (final order in farmerOrders) {
            final deliveryDate = order.deliveryDate ?? order.createdAt;
            final dateKey = '${deliveryDate.year}-${deliveryDate.month}-${deliveryDate.day}';
            if (!deliveryDateMap.containsKey(dateKey)) {
              deliveryDateMap[dateKey] = [];
            }
            deliveryDateMap[dateKey]!.add(order);
          }
          
          farmerDeliveryDateMap[farmerId] = deliveryDateMap;
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: farmerDeliveryDateMap.length,
          itemBuilder: (context, index) {
            final farmerId = farmerDeliveryDateMap.keys.elementAt(index);
            final deliveryDateMap = farmerDeliveryDateMap[farmerId]!;
            
            return _buildFarmerCard(farmerId, deliveryDateMap);
          },
        );
      },
    );
  }

  Widget _buildFarmerCard(String farmerId, Map<String, List<OrderModel>> deliveryDateMap) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('farmers').doc(farmerId).get(),
      builder: (context, farmerSnapshot) {
        final farmerName = farmerSnapshot.data?.get('name') ?? 'Unknown Farmer';
        final farmerLocation = farmerSnapshot.data?.get('location') ?? '';

        // Aggregate products per delivery date
        final Map<String, Map<String, double>> deliveryDateProductQuantities = {};
        final Map<String, Map<String, String>> deliveryDateProductUnits = {};
        final Map<String, Map<String, String>> deliveryDateProductNames = {};
        final Map<String, Map<String, String>> deliveryDateProductCategories = {};
        final List<String> deliveryDateLabels = [];
        final Map<String, int> deliveryDateOrderCounts = {};
        final Map<String, List<String>> deliveryDateScheduleNames = {};

        for (final dateKey in deliveryDateMap.keys) {
          final orders = deliveryDateMap[dateKey]!;
          
          // Parse date key to get delivery date
          final parts = dateKey.split('-');
          final deliveryDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          deliveryDateLabels.add(DateFormat('MMM dd, yyyy').format(deliveryDate));

          // Count orders for this delivery date
          deliveryDateOrderCounts[dateKey] = orders.length;

          // Collect schedule names for this delivery date
          final scheduleNames = <String>{};
          for (final order in orders) {
            if (order.scheduleName != null) {
              scheduleNames.add(order.scheduleName!);
            }
          }
          deliveryDateScheduleNames[dateKey] = scheduleNames.toList();

          // Initialize product maps for this delivery date
          deliveryDateProductQuantities[dateKey] = {};
          deliveryDateProductUnits[dateKey] = {};
          deliveryDateProductNames[dateKey] = {};
          deliveryDateProductCategories[dateKey] = {};

          for (final order in orders) {
            for (final item in order.items) {
              final key = '${item.productName}_${item.unit}_${item.productCategory}';
              if (!deliveryDateProductQuantities[dateKey]!.containsKey(key)) {
                deliveryDateProductQuantities[dateKey]![key] = 0;
                deliveryDateProductUnits[dateKey]![key] = item.unit;
                deliveryDateProductNames[dateKey]![key] = item.productName;
                deliveryDateProductCategories[dateKey]![key] = item.productCategory;
              }
              deliveryDateProductQuantities[dateKey]![key] = (deliveryDateProductQuantities[dateKey]![key] ?? 0) + item.quantity;
            }
          }
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
                    '${deliveryDateMap.length} Delivery Dates',
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
                children: deliveryDateLabels.take(3).map((dateLabel) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      dateLabel,
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
                    const Text(
                      'Delivery Dates',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...deliveryDateMap.keys.map((dateKey) {
                      final dateLabel = deliveryDateLabels[deliveryDateMap.keys.toList().indexOf(dateKey)] ?? 'Unknown Date';
                      final orderCount = deliveryDateOrderCounts[dateKey] ?? 0;
                      final schedules = deliveryDateScheduleNames[dateKey] ?? [];
                      final productQuantities = deliveryDateProductQuantities[dateKey] ?? {};
                      final productUnits = deliveryDateProductUnits[dateKey] ?? {};
                      final productNames = deliveryDateProductNames[dateKey] ?? {};
                      final productCategories = deliveryDateProductCategories[dateKey] ?? {};
                      
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
                                Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.blue[700],
                                    ),
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
                              ],
                            ),
                            if (schedules.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.schedule, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Schedules: ${schedules.join(', ')}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (productQuantities.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              const Text(
                                'Products for this delivery',
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
