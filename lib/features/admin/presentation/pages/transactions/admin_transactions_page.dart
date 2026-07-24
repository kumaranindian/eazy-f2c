import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminTransactionsPage extends ConsumerStatefulWidget {
  const AdminTransactionsPage({super.key});

  @override
  ConsumerState<AdminTransactionsPage> createState() => _AdminTransactionsPageState();
}

class _AdminTransactionsPageState extends ConsumerState<AdminTransactionsPage> {
  String _selectedFilter = 'all';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        children: [
          Row(
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('GPay', 'gpay'),
              const SizedBox(width: 8),
              _buildFilterChip('Cash', 'cash'),
              const SizedBox(width: 8),
              _buildFilterChip('Pending', 'pending'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _selectDateRange,
                tooltip: 'Select Date Range',
              ),
            ],
          ),
          if (_startDate != null && _endDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(Icons.date_range, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                    child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: Colors.green[100],
      checkmarkColor: Colors.green[700],
      labelStyle: TextStyle(
        color: isSelected ? Colors.green[700] : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Widget _buildTransactionsList() {
    Query query = FirebaseFirestore.instance.collection('orders');

    // Apply date filter
    if (_startDate != null && _endDate != null) {
      query = query
          .where('deliveryDate', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate!))
          .where('deliveryDate', isLessThanOrEqualTo: Timestamp.fromDate(_endDate!));
    }

    // Apply payment method filter
    if (_selectedFilter == 'gpay') {
      query = query.where('paymentMethod', isEqualTo: 'gpay');
    } else if (_selectedFilter == 'cash') {
      query = query.where('paymentMethod', isEqualTo: 'cash');
    } else if (_selectedFilter == 'pending') {
      query = query.where('paymentStatus', isEqualTo: 'pending');
    }

    // Only show delivered orders with payment info
    query = query.where('status', isEqualTo: 'delivered');

    return StreamBuilder<QuerySnapshot>(
      stream: query.orderBy('deliveryDate', descending: true).snapshots(),
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

        final orders = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            return _buildTransactionCard(order);
          },
        );
      },
    );
  }

  Widget _buildTransactionCard(DocumentSnapshot orderDoc) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final orderId = orderDoc.id;
    final customerName = data['customerName'] ?? 'Unknown';
    final customerEmail = data['customerEmail'] ?? '';
    final apartmentName = data['apartmentName'] ?? 'Unknown';
    final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = data['paymentMethod'] ?? 'unknown';
    final paymentStatus = data['paymentStatus'] ?? 'pending';
    final deliveryDate = data['deliveryDate'] as Timestamp?;
    final scheduleName = data['scheduleName'] ?? 'Unknown Schedule';
    final hubName = data['hubName'] ?? 'Unknown Hub';
    final deliveryAddress = data['deliveryAddress'] ?? '';

    // Transaction details
    final transactionId = data['transactionId'];
    final transactionReference = data['transactionReference'];
    final transactionScreenshot = data['transactionScreenshot'];
    final transactionVerifiedAt = data['transactionVerifiedAt'] as Timestamp?;
    final transactionVerifiedBy = data['transactionVerifiedBy'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        apartmentName,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildPaymentStatusBadge(paymentStatus),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Delivery Date',
                deliveryDate != null ? DateFormat('MMM dd, yyyy').format(deliveryDate.toDate()) : 'N/A'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.schedule, 'Schedule', scheduleName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.location_on, 'Hub', hubName),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.payment, 'Payment Method', _formatPaymentMethod(paymentMethod)),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.account_balance_wallet, 'Amount', '₹${totalAmount.toStringAsFixed(2)}'),
            if (deliveryAddress.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.location_on, 'Delivery Address', deliveryAddress),
            ],
            const Divider(height: 24),
            // Transaction Details Section
            const Text(
              'Transaction Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (transactionId != null)
              _buildInfoRow(Icons.receipt_long, 'Transaction ID', transactionId),
            if (transactionReference != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.confirmation_number, 'Reference', transactionReference),
            ],
            if (transactionScreenshot != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.image, 'Screenshot', 'Available'),
            ],
            if (transactionVerifiedAt != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.verified, 'Verified At',
                  DateFormat('MMM dd, yyyy HH:mm').format(transactionVerifiedAt.toDate())),
              if (transactionVerifiedBy != null) ...[
                const SizedBox(height: 8),
                _buildInfoRow(Icons.person, 'Verified By', transactionVerifiedBy),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewOrderDetails(orderDoc),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text('View Order'),
                  ),
                ),
                const SizedBox(width: 12),
                if (paymentStatus == 'pending' && paymentMethod == 'gpay')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _verifyTransaction(orderDoc),
                      icon: const Icon(Icons.verified, size: 18),
                      label: const Text('Verify'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = Colors.green[100]!;
        textColor = Colors.green[700]!;
        displayText = 'Paid';
        break;
      case 'pending':
        backgroundColor = Colors.orange[100]!;
        textColor = Colors.orange[700]!;
        displayText = 'Pending';
        break;
      case 'failed':
        backgroundColor = Colors.red[100]!;
        textColor = Colors.red[700]!;
        displayText = 'Failed';
        break;
      default:
        backgroundColor = Colors.grey[100]!;
        textColor = Colors.grey[700]!;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'gpay':
        return 'GPay';
      case 'cash':
        return 'Cash';
      case 'card':
        return 'Card';
      default:
        return method;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting the filters',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  void _viewOrderDetails(DocumentSnapshot orderDoc) {
    // TODO: Navigate to order details page
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order details view coming soon')),
    );
  }

  Future<void> _verifyTransaction(DocumentSnapshot orderDoc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Transaction'),
        content: const Text('Are you sure you want to mark this transaction as verified?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await orderDoc.reference.update({
          'paymentStatus': 'completed',
          'transactionVerifiedAt': FieldValue.serverTimestamp(),
          'transactionVerifiedBy': 'Admin', // TODO: Use actual admin name
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction verified successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error verifying transaction: $e')),
          );
        }
      }
    }
  }
}
