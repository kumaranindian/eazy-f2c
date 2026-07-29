import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:f2c/features/customer/models/order_model.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';

class ProfitReportPage extends ConsumerStatefulWidget {
  const ProfitReportPage({super.key});

  @override
  ConsumerState<ProfitReportPage> createState() => _ProfitReportPageState();
}

class _ProfitReportPageState extends ConsumerState<ProfitReportPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedHub = 'All HUBs';
  bool _isLoading = false;
  List<ProfitData> _profitData = [];

  @override
  void initState() {
    super.initState();
    _applyDateFilter('This Month');
  }

  void _applyDateFilter(String filter) {
    final now = DateTime.now();
    setState(() {
      switch (filter) {
        case 'This Week':
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now.add(Duration(days: 7 - now.weekday));
          break;
        case 'This Month':
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case 'This Quarter':
          final quarter = ((now.month - 1) ~/ 3) + 1;
          final startMonth = (quarter - 1) * 3 + 1;
          _startDate = DateTime(now.year, startMonth, 1);
          _endDate = DateTime(now.year, startMonth + 3, 0);
          break;
        case 'This Year':
          _startDate = DateTime(now.year, 1, 1);
          _endDate = DateTime(now.year, 12, 31);
          break;
        case 'Custom':
          break;
      }
    });
    _loadProfitData();
  }

  Future<void> _loadProfitData() async {
    if (_startDate == null || _endDate == null) return;

    setState(() => _isLoading = true);

    try {
      // Fetch orders within date range
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('isDeleted', isEqualTo: false)
          .where('deliveryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('deliveryDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!))
          .get();

      final orders = ordersSnapshot.docs.map((doc) => OrderModel.fromFirestore(doc)).toList();

      // Group by schedule and delivery date
      final Map<String, ProfitData> profitMap = {};

      for (final order in orders) {
        final scheduleId = order.scheduleId ?? 'no-schedule';
        final scheduleName = order.scheduleName ?? 'No Schedule';
        final deliveryDate = order.deliveryDate ?? order.createdAt;
        final dateKey = DateFormat('yyyy-MM-dd').format(deliveryDate);
        final key = '$scheduleId|$dateKey';

        if (!profitMap.containsKey(key)) {
          profitMap[key] = ProfitData(
            scheduleId: scheduleId,
            scheduleName: scheduleName,
            deliveryDate: deliveryDate,
            revenue: 0.0,
            cost: 0.0,
            profit: 0.0,
            orderCount: 0,
            itemCount: 0,
          );
        }

        final data = profitMap[key]!;
        data.revenue += order.grandTotal;
        data.orderCount += 1;
        data.itemCount += order.items.length;

        // Calculate cost (assuming 70% of revenue as cost - this should be adjusted based on actual cost data)
        // In a real implementation, you would fetch actual product costs from the schedule
        final cost = order.subtotal * 0.7; // 70% cost assumption
        data.cost += cost;
        data.profit = data.revenue - data.cost;
      }

      setState(() {
        _profitData = profitMap.values.toList()
          ..sort((a, b) => b.deliveryDate.compareTo(a.deliveryDate));
      });
    } catch (e) {
      print('Error loading profit data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Profit Report'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfitData,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportToCSV,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltersRow(),
          _buildSummaryCards(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildProfitTable(),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(6),
              color: Colors.grey[50],
            ),
            child: DropdownButton<String>(
              value: _selectedDateFilter(),
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(fontSize: 13),
              items: ['This Week', 'This Month', 'This Quarter', 'This Year', 'Custom'].map((filter) {
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
          const SizedBox(width: 12),
          if (_startDate != null && _endDate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF2196F3)),
                borderRadius: BorderRadius.circular(6),
                color: const Color(0xFF2196F3).withOpacity(0.05),
              ),
              child: Row(
                children: [
                  const Icon(Icons.date_range, size: 16, color: Color(0xFF2196F3)),
                  const SizedBox(width: 6),
                  Text(
                    '${DateFormat('dd MMM').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2196F3)),
                  ),
                ],
              ),
            ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loadProfitData,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Generate Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _selectedDateFilter() {
    if (_startDate == null || _endDate == null) return 'Custom';
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month, 1);
    final thisQuarter = DateTime(now.year, ((now.month - 1) ~/ 3) * 3 + 1, 1);
    
    if (_startDate!.isAtSameMomentAs(thisMonth)) return 'This Month';
    if (_startDate!.isAtSameMomentAs(thisQuarter)) return 'This Quarter';
    return 'Custom';
  }

  Widget _buildSummaryCards() {
    if (_profitData.isEmpty) return const SizedBox();

    final totalRevenue = _profitData.fold(0.0, (sum, data) => sum + data.revenue);
    final totalCost = _profitData.fold(0.0, (sum, data) => sum + data.cost);
    final totalProfit = _profitData.fold(0.0, (sum, data) => sum + data.profit);
    final totalOrders = _profitData.fold(0, (sum, data) => sum + data.orderCount);
    final profitMargin = totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard('Total Revenue', '₹${totalRevenue.toStringAsFixed(2)}', Icons.trending_up, Colors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Total Cost', '₹${totalCost.toStringAsFixed(2)}', Icons.trending_down, Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Total Profit', '₹${totalProfit.toStringAsFixed(2)}', Icons.account_balance_wallet, Colors.blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Profit Margin', '${profitMargin.toStringAsFixed(1)}%', Icons.percent, Colors.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSummaryCard('Total Orders', totalOrders.toString(), Icons.receipt_long, Colors.orange),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfitTable() {
    if (_profitData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No profit data available',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.grey[700]),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: _profitData.length,
              itemBuilder: (context, index) {
                return _buildProfitRow(_profitData[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: _HeaderCell('Schedule')),
          Expanded(flex: 1, child: _HeaderCell('Delivery Date')),
          Expanded(flex: 1, child: _HeaderCell('Orders')),
          Expanded(flex: 1, child: _HeaderCell('Revenue (₹)')),
          Expanded(flex: 1, child: _HeaderCell('Cost (₹)')),
          Expanded(flex: 1, child: _HeaderCell('Profit (₹)')),
          Expanded(flex: 1, child: _HeaderCell('Margin %')),
        ],
      ),
    );
  }

  Widget _buildProfitRow(ProfitData data) {
    final margin = data.revenue > 0 ? (data.profit / data.revenue * 100) : 0.0;
    final marginColor = margin >= 20 ? Colors.green : margin >= 10 ? Colors.orange : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              data.scheduleName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              DateFormat('dd MMM yyyy').format(data.deliveryDate),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              data.orderCount.toString(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₹${data.revenue.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₹${data.cost.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '₹${data.profit.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: data.profit >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${margin.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: marginColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadProfitData();
    }
  }

  void _exportToCSV() {
    if (_profitData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }

    final csvBuffer = StringBuffer();
    csvBuffer.writeln('Schedule Name,Delivery Date,Orders,Revenue,Cost,Profit,Margin %');

    for (final data in _profitData) {
      final margin = data.revenue > 0 ? (data.profit / data.revenue * 100) : 0.0;
      csvBuffer.writeln(
        '"${data.scheduleName}",'
        '"${DateFormat('dd MMM yyyy').format(data.deliveryDate)}",'
        '${data.orderCount},'
        '${data.revenue.toStringAsFixed(2)},'
        '${data.cost.toStringAsFixed(2)},'
        '${data.profit.toStringAsFixed(2)},'
        '${margin.toStringAsFixed(1)}%'
      );
    }

    // Download CSV (web implementation)
    // In a real app, you'd use a proper CSV export library
    print('CSV Export:\n${csvBuffer.toString()}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV export ready (check console for now)')),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String title;

  const _HeaderCell(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }
}

class ProfitData {
  final String scheduleId;
  final String scheduleName;
  final DateTime deliveryDate;
  double revenue;
  double cost;
  double profit;
  int orderCount;
  int itemCount;

  ProfitData({
    required this.scheduleId,
    required this.scheduleName,
    required this.deliveryDate,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.orderCount,
    required this.itemCount,
  });
}
