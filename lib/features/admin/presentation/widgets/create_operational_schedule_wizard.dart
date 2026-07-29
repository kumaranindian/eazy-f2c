import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/operational_schedule_model.dart';
import '../../models/branch_model.dart';
import '../../models/hub_model.dart';
import '../../models/product_model.dart';
import '../../providers/branch_providers.dart';
import '../../providers/hub_providers.dart';
import '../../providers/apartment_providers.dart';
import '../../providers/farmer_providers.dart';
import '../../providers/product_providers.dart';
import '../../providers/operational_schedule_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

class ProductPricing {
  final double price;
  final double profitMargin;

  ProductPricing({required this.price, required this.profitMargin});
}

class CreateOperationalScheduleWizard extends ConsumerStatefulWidget {
  const CreateOperationalScheduleWizard({super.key});

  @override
  ConsumerState<CreateOperationalScheduleWizard> createState() =>
      _CreateOperationalScheduleWizardState();
}

class _CreateOperationalScheduleWizardState
    extends ConsumerState<CreateOperationalScheduleWizard> {
  int _currentStep = 0;
  bool _isCreatingSchedule = false;

  // Schedule Name
  String _scheduleName = '';

  // Stage 1: Date, Branch, Hub, Visibility
  DateTime? _selectedDate;
  TimeOfDay? _startTime = const TimeOfDay(hour: 4, minute: 0);
  TimeOfDay? _endTime = const TimeOfDay(hour: 23, minute: 0);
  bool _isFullDay = false;
  String? _selectedBranchId;
  String? _selectedBranchName;
  String? _selectedHubId;
  String? _selectedHubName;
  ScheduleVisibilityScope _visibilityScope = ScheduleVisibilityScope.entireHub;
  List<String> _selectedApartmentIds = [];
  List<String> _selectedApartmentNames = [];
  
  // Recurrence
  ScheduleRecurrenceType _recurrenceType = ScheduleRecurrenceType.oneTime;
  DateTime? _recurrenceEndDate;
  List<int> _recurrenceDaysOfWeek = []; // 1=Monday, 2=Tuesday, etc.

  // Stage 2: Farmers
  List<String> _selectedFarmerIds = [];
  List<String> _selectedFarmerNames = [];

  // Stage 3: Products
  List<ScheduleProductItem> _selectedProducts = [];
  final Map<String, ProductPricing> _productPricing = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _profitControllers = {};

  // Stage 4: Delivery Slot
  ScheduleRecurrenceType _deliverySlotType = ScheduleRecurrenceType.oneTime;
  DateTime? _deliveryDate;
  TimeOfDay? _deliveryStartTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _deliveryEndTime = const TimeOfDay(hour: 18, minute: 0);
  List<int> _deliveryDaysOfWeek = [];
  
  // Stage 5: Charges
  double _deliveryCharges = 0.0;
  double _cleaningCharges = 0.0;
  final TextEditingController _deliveryChargesController = TextEditingController();
  final TextEditingController _cleaningChargesController = TextEditingController();

  void _resetFormFields() {
    setState(() {
      _scheduleName = '';
      _selectedDate = null;
      _startTime = null;
      _endTime = null;
      _isFullDay = false;
      _selectedBranchId = null;
      _selectedBranchName = null;
      _selectedHubId = null;
      _selectedHubName = null;
      _visibilityScope = ScheduleVisibilityScope.entireHub;
      _selectedApartmentIds.clear();
      _selectedApartmentNames.clear();
      _recurrenceEndDate = null;
      _recurrenceDaysOfWeek.clear();
      _selectedFarmerIds.clear();
      _selectedFarmerNames.clear();
      _selectedProducts.clear();
      _productPricing.clear();
      _priceControllers.forEach((_, controller) => controller.dispose());
      _priceControllers.clear();
      _profitControllers.forEach((_, controller) => controller.dispose());
      _profitControllers.clear();
      _deliverySlotType = ScheduleRecurrenceType.oneTime;
      _deliveryDate = null;
      _deliveryStartTime = const TimeOfDay(hour: 8, minute: 0);
      _deliveryEndTime = const TimeOfDay(hour: 18, minute: 0);
      _deliveryDaysOfWeek.clear();
      _deliveryCharges = 0.0;
      _cleaningCharges = 0.0;
      _deliveryChargesController.clear();
      _cleaningChargesController.clear();
      _currentStep = 0;
    });
  }

  void _updateProductPricing(String productId, double price, double profitMargin) {
    final index = _selectedProducts.indexWhere((p) => p.productId == productId);
    if (index >= 0) {
      setState(() {
        _selectedProducts[index] = _selectedProducts[index].copyWith(
          price: price,
          profitMargin: profitMargin,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 1200,
        height: 700,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Create Operational Schedule',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Progress Indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildProgressIndicator(),
            ),
            const SizedBox(height: 16),

            // Main Content Area with Two Columns
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    // Left Side - Step Content
                    Expanded(
                      flex: 2,
                      child: _buildStepContent(),
                    ),
                    const SizedBox(width: 24),
                    // Right Side - Summary Panel
                    Expanded(
                      flex: 1,
                      child: _buildSummaryPanel(),
                    ),
                  ],
                ),
              ),
            ),

            // Navigation Buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: _buildNavigationButtons(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Date & Time', 'Location', 'Farmers', 'Products', 'Delivery', 'Summary'];
    return Row(
      children: List.generate(6, (index) {
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;
        return Expanded(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green
                          : isCurrent
                              ? Colors.blue
                              : Colors.grey[300],
                      shape: BoxShape.circle,
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    steps[index],
                    style: TextStyle(
                      color: isCurrent ? Colors.blue : Colors.grey[600],
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (index < 5)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isCompleted ? Colors.green : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1DateAndTime();
      case 1:
        return _buildStep2Location();
      case 2:
        return _buildStep3Farmers();
      case 3:
        return _buildStep4Products();
      case 4:
        return _buildStep5DeliverySlot();
      case 5:
        return _buildStep6Charges();
      case 6:
        return _buildStep7Summary();
      default:
        return const SizedBox();
    }
  }

  Widget _buildFormField({
    required String label,
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.blue[700], size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: value.contains('Select') ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1DateAndTime() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 1: Date & Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Schedule Name
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.label, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text('Schedule Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                    const SizedBox(width: 4),
                    const Text('*',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This name will be displayed to customers',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Enter a name for this schedule (e.g., Morning Delivery)',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    errorText: _scheduleName.isEmpty && _currentStep > 0 
                        ? 'Schedule name is required' 
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _scheduleName = value.trim();
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recurrence Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.repeat, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Text('Recurrence',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        )),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Recurrence Type Selection
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: Text(
                        _recurrenceType == ScheduleRecurrenceType.oneTime && _selectedDate != null
                            ? 'One Time: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}'
                            : 'One Time',
                      ),
                      selected: _recurrenceType == ScheduleRecurrenceType.oneTime,
                      onSelected: (selected) {
                        if (selected) {
                          _resetFormFields();
                          setState(() {
                            _recurrenceType = ScheduleRecurrenceType.oneTime;
                          });
                        }
                      },
                    ),
                    FilterChip(
                      label: const Text('Daily'),
                      selected: _recurrenceType == ScheduleRecurrenceType.daily,
                      onSelected: (selected) {
                        if (selected) {
                          _resetFormFields();
                          setState(() {
                            _recurrenceType = ScheduleRecurrenceType.daily;
                          });
                        }
                      },
                    ),
                    FilterChip(
                      label: const Text('Weekly'),
                      selected: _recurrenceType == ScheduleRecurrenceType.weekly,
                      onSelected: (selected) {
                        if (selected) {
                          _resetFormFields();
                          setState(() {
                            _recurrenceType = ScheduleRecurrenceType.weekly;
                          });
                        }
                      },
                    ),
                  ],
                ),

                // Daily Panel with Date Selection
                if (_recurrenceType == ScheduleRecurrenceType.daily) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.green[700]),
                            const SizedBox(width: 12),
                            const Text('Daily Schedule',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.green[900]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Daily Schedule: Products will be available every day from start date to end date during the specified time range (e.g., 10:00 AM - 6:00 PM daily)',
                                  style: TextStyle(fontSize: 12, color: Colors.green[900], fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Start Date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.green[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate != null
                                      ? 'Start Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                      : 'Select Start Date',
                                  style: TextStyle(
                                    color: _selectedDate != null ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // End Date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _recurrenceEndDate ?? (_selectedDate ?? DateTime.now()),
                              firstDate: _selectedDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _recurrenceEndDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.green[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _recurrenceEndDate != null
                                      ? 'End Date: ${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}'
                                      : 'Select End Date',
                                  style: TextStyle(
                                    color: _recurrenceEndDate != null ? Colors.black87 : Colors.grey,
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

                // Weekly Panel with Date Selection
                if (_recurrenceType == ScheduleRecurrenceType.weekly) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today, color: Colors.orange[700]),
                            const SizedBox(width: 12),
                            const Text('Weekly Schedule',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Start Date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                                if (_recurrenceDaysOfWeek.isEmpty) {
                                  _recurrenceDaysOfWeek = [picked.weekday];
                                }
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _selectedDate != null
                                      ? 'Start Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                      : 'Select Start Date',
                                  style: TextStyle(
                                    color: _selectedDate != null ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // End Date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _recurrenceEndDate ?? (_selectedDate ?? DateTime.now()),
                              firstDate: _selectedDate ?? DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() => _recurrenceEndDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.event, color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _recurrenceEndDate != null
                                      ? 'End Date: ${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}'
                                      : 'Select End Date',
                                  style: TextStyle(
                                    color: _recurrenceEndDate != null ? Colors.black87 : Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.orange[900]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Weekly Schedule: Products will be available from start date + time to end date + time (e.g., Aug 2, 2026 10:00 AM to Aug 30, 2026 6:00 PM on selected days)',
                                  style: TextStyle(fontSize: 12, color: Colors.orange[900], fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Select Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildDayChip(1, 'Mon'),
                            _buildDayChip(2, 'Tue'),
                            _buildDayChip(3, 'Wed'),
                            _buildDayChip(4, 'Thu'),
                            _buildDayChip(5, 'Fri'),
                            _buildDayChip(6, 'Sat'),
                            _buildDayChip(7, 'Sun'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Date Selection for One Time
                if (_recurrenceType == ScheduleRecurrenceType.oneTime) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'One-Time Schedule: Products will be available on the selected date during the specified time range (e.g., 10:00 AM - 6:00 PM on that day only)',
                            style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            _selectedDate != null
                                ? 'Date: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Select Date',
                            style: TextStyle(
                              color: _selectedDate != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Full Day Toggle with Time Selection
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    const Text('Full Day (24 Hours)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Switch(
                      value: _isFullDay,
                      onChanged: (value) {
                        setState(() {
                          _isFullDay = value;
                          if (value) {
                            _startTime = const TimeOfDay(hour: 0, minute: 0);
                            _endTime = const TimeOfDay(hour: 23, minute: 59);
                          } else {
                            _startTime = null;
                            _endTime = null;
                          }
                        });
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
                if (!_isFullDay) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Time Range',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              _recurrenceType == ScheduleRecurrenceType.oneTime
                                  ? 'Products available during this time on selected date'
                                  : _recurrenceType == ScheduleRecurrenceType.daily
                                      ? 'Products available daily during this time range'
                                      : 'Start time on start date to end time on end date',
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Start Time
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            setState(() => _startTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Text(
                            _startTime != null
                                ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'
                                : 'Start',
                            style: TextStyle(
                              color: _startTime != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('-', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // End Time
                      InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _endTime ?? TimeOfDay.now(),
                          );
                          if (picked != null) {
                            // Validate that end time is after start time
                            if (_startTime != null) {
                              final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
                              final endMinutes = picked.hour * 60 + picked.minute;
                              
                              if (endMinutes <= startMinutes) {
                                // Show error message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('End time must be after start time'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }
                            setState(() => _endTime = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.white,
                          ),
                          child: Text(
                            _endTime != null
                                ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'
                                : 'End',
                            style: TextStyle(
                              color: _endTime != null ? Colors.black87 : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    final isSelected = _recurrenceDaysOfWeek.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _recurrenceDaysOfWeek.add(day);
          } else {
            _recurrenceDaysOfWeek.remove(day);
          }
        });
      },
      selectedColor: Colors.blue[100],
      checkmarkColor: Colors.blue[700],
    );
  }

  Widget _buildDeliveryDayChip(int day, String label) {
    final isSelected = _deliveryDaysOfWeek.contains(day);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _deliveryDaysOfWeek.add(day);
          } else {
            _deliveryDaysOfWeek.remove(day);
          }
        });
      },
      selectedColor: Colors.orange[100],
      checkmarkColor: Colors.orange[700],
    );
  }

  Widget _buildStep2Location() {
    final branchesAsync = ref.watch(branchesStreamProvider);
    final hubsAsync = ref.watch(hubsStreamProvider);
    final apartmentsAsync = ref.watch(apartmentsStreamProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: Colors.purple[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 2: Location',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Branch Selection
          branchesAsync.when(
            data: (branches) {
              return DropdownButtonFormField<String>(
                value: _selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Select Branch',
                  border: OutlineInputBorder(),
                ),
                items: branches
                    .map((branch) => DropdownMenuItem(
                          value: branch.id,
                          child: Text(branch.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedBranchId = value;
                    _selectedBranchName = branches.firstWhere((b) => b.id == value).name;
                    _selectedHubId = null;
                    _selectedHubName = null;
                    _selectedApartmentIds.clear();
                    _selectedApartmentNames.clear();
                  });
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (error, stack) => Text('Error: $error'),
          ),
          const SizedBox(height: 16),

          // Hub Selection
          if (_selectedBranchId != null)
            hubsAsync.when(
              data: (hubs) {
                final filteredHubs = hubs
                    .where((hub) => hub.branchId == _selectedBranchId)
                    .toList();
                return DropdownButtonFormField<String>(
                  value: _selectedHubId,
                  decoration: const InputDecoration(
                    labelText: 'Select Hub',
                    border: OutlineInputBorder(),
                  ),
                  items: filteredHubs
                      .map((hub) => DropdownMenuItem(
                            value: hub.id,
                            child: Text(hub.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedHubId = value;
                      _selectedHubName = filteredHubs.firstWhere((h) => h.id == value).name;
                      _selectedApartmentIds.clear();
                      _selectedApartmentNames.clear();
                    });
                  },
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
          const SizedBox(height: 16),

          // Visibility Scope
          if (_selectedHubId != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Visibility Scope',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                RadioListTile<ScheduleVisibilityScope>(
                  title: const Text('Entire Hub'),
                  subtitle: const Text('All apartments in this hub'),
                  value: ScheduleVisibilityScope.entireHub,
                  groupValue: _visibilityScope,
                  onChanged: (value) {
                    setState(() {
                      _visibilityScope = value!;
                      _selectedApartmentIds.clear();
                      _selectedApartmentNames.clear();
                    });
                  },
                ),
                RadioListTile<ScheduleVisibilityScope>(
                  title: const Text('Selected Apartments'),
                  subtitle: const Text('Choose specific apartments'),
                  value: ScheduleVisibilityScope.selectedApartments,
                  groupValue: _visibilityScope,
                  onChanged: (value) {
                    setState(() => _visibilityScope = value!);
                  },
                ),
              ],
            ),

          // Apartment Selection
          if (_selectedHubId != null &&
              _visibilityScope == ScheduleVisibilityScope.selectedApartments)
            apartmentsAsync.when(
              data: (apartments) {
                final filteredApartments = apartments
                    .where((apt) => apt.hubId == _selectedHubId)
                    .toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    const Text('Select Apartments',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: filteredApartments.map((apt) {
                        final isSelected = _selectedApartmentIds.contains(apt.id);
                        return FilterChip(
                          label: Text(apt.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedApartmentIds.add(apt.id);
                                _selectedApartmentNames.add(apt.name);
                              } else {
                                _selectedApartmentIds.remove(apt.id);
                                _selectedApartmentNames.remove(apt.name);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text('Error: $error'),
            ),
        ],
      ),
    );
  }

  Widget _buildStep3Farmers() {
    final farmersAsync = ref.watch(farmersStreamProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.agriculture, color: Colors.green[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 3: Select Farmers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          farmersAsync.when(
            data: (farmers) {
              final activeFarmers = farmers
                  .where((f) => f.isActive && !f.isDeleted)
                  .toList();
              if (activeFarmers.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.agriculture_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No active farmers available',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeFarmers.map((farmer) {
                  final isSelected = _selectedFarmerIds.contains(farmer.id);
                  return FilterChip(
                    label: Text(farmer.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedFarmerIds.add(farmer.id);
                          _selectedFarmerNames.add(farmer.name);
                        } else {
                          _selectedFarmerIds.remove(farmer.id);
                          _selectedFarmerNames.remove(farmer.name);
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Error loading farmers',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Products() {
    final productsAsync = ref.watch(productsStreamProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: Colors.orange[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 4: Select Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          productsAsync.when(
            data: (products) {
              final activeProducts = products
                  .where((p) => p.isActive && !p.isDeleted)
                  .toList();
              final filteredProducts = _selectedFarmerIds.isEmpty
                  ? activeProducts
                  : activeProducts.where((p) => _selectedFarmerIds.contains(p.farmerId)).toList();
              
              if (filteredProducts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _selectedFarmerIds.isEmpty 
                              ? 'No products available'
                              : 'No products from selected farmers',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              // Group products by farmer
              final groupedProducts = <String, List<ProductModel>>{};
              for (final product in filteredProducts) {
                final farmerId = product.farmerId ?? 'unknown';
                if (!groupedProducts.containsKey(farmerId)) {
                  groupedProducts[farmerId] = [];
                }
                groupedProducts[farmerId]!.add(product);
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: groupedProducts.entries.map((entry) {
                  final farmerId = entry.key;
                  final farmerProducts = entry.value as List<ProductModel>;
                  final farmerIndex = _selectedFarmerIds.indexOf(farmerId);
                  final farmerName = farmerIndex >= 0 ? _selectedFarmerNames[farmerIndex] : 'Unknown Farmer';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Farmer header
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, size: 20, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Text(
                                farmerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${farmerProducts.length} products',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Products list
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: farmerProducts.map((product) {
                              final existingItem = _selectedProducts
                                  .cast<ScheduleProductItem?>()
                                  .firstWhere(
                                    (p) => p?.productId == product.id,
                                    orElse: () => null,
                                  );
                              final isIncluded = existingItem != null;
                              final pricing = _productPricing[product.id] ??
                                  ProductPricing(
                                    price: product.price,
                                    profitMargin: product.profitMargin,
                                  );

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isIncluded ? Colors.orange : Colors.grey[300]!,
                                    width: isIncluded ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  color: isIncluded ? Colors.orange[50] : Colors.grey[50],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isIncluded ? Colors.orange : Colors.grey[300],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(
                                          Icons.shopping_bag,
                                          color: isIncluded ? Colors.white : Colors.grey[500],
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(product.name,
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isIncluded ? Colors.black87 : Colors.grey[600],
                                                    fontSize: 14)),
                                            const SizedBox(height: 2),
                                            Text(product.category,
                                                style: TextStyle(
                                                  color: isIncluded ? Colors.grey[600] : Colors.grey[500],
                                                  fontSize: 12,
                                                )),
                                            if (isIncluded)
                                              Text(
                                                'Base: ₹${product.price.toStringAsFixed(0)}/${product.unit}',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isIncluded) ...[
                                        SizedBox(
                                          width: 60,
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Price',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 6,
                                              ),
                                              isDense: true,
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
                                                _updateProductPricing(product.id, price, pricing.profitMargin);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        SizedBox(
                                          width: 60,
                                          child: TextField(
                                            keyboardType: TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Profit',
                                              border: OutlineInputBorder(),
                                              contentPadding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 6,
                                              ),
                                              isDense: true,
                                            ),
                                            controller: _profitControllers.putIfAbsent(
                                              product.id,
                                              () => TextEditingController(
                                                text: pricing.profitMargin > 0
                                                    ? pricing.profitMargin.toStringAsFixed(0)
                                                    : '',
                                              ),
                                            ),
                                            onChanged: (value) {
                                              final profit = double.tryParse(value) ?? 0;
                                              setState(() {
                                                _productPricing[product.id] =
                                                    ProductPricing(
                                                  price: pricing.price,
                                                  profitMargin: profit,
                                                );
                                                _updateProductPricing(product.id, pricing.price, profit);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                      Switch(
                                        value: isIncluded,
                                        activeColor: Colors.orange,
                                        onChanged: (value) {
                                          setState(() {
                                            if (value) {
                                              _selectedProducts.add(ScheduleProductItem(
                                                productId: product.id,
                                                productName: product.name,
                                                productCategory: product.category,
                                                quantity: 1,
                                                price: product.price,
                                                profitMargin: product.profitMargin,
                                                farmerId: product.farmerId,
                                                farmerName: farmerName,
                                              ));
                                              _productPricing[product.id] = ProductPricing(
                                                price: product.price,
                                                profitMargin: product.profitMargin,
                                              );
                                              _priceControllers[product.id] = TextEditingController(
                                                text: product.price > 0
                                                    ? product.price.toStringAsFixed(0)
                                                    : '',
                                              );
                                              _profitControllers[product.id] = TextEditingController(
                                                text: product.profitMargin > 0
                                                    ? product.profitMargin.toStringAsFixed(0)
                                                    : '',
                                              );
                                            } else {
                                              _selectedProducts.removeWhere(
                                                  (p) => p.productId == product.id);
                                              _productPricing.remove(product.id);
                                              _priceControllers.remove(product.id)?.dispose();
                                              _profitControllers.remove(product.id)?.dispose();
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading products',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep5DeliverySlot() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: Colors.teal[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 5: Delivery Slot',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'When should products be delivered?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // Delivery Slot Type Selection
          SegmentedButton<ScheduleRecurrenceType>(
            segments: const [
              ButtonSegment(
                value: ScheduleRecurrenceType.oneTime,
                label: Text('Once'),
                icon: Icon(Icons.event),
              ),
              ButtonSegment(
                value: ScheduleRecurrenceType.daily,
                label: Text('Daily'),
                icon: Icon(Icons.today),
              ),
              ButtonSegment(
                value: ScheduleRecurrenceType.weekly,
                label: Text('Weekly'),
                icon: Icon(Icons.calendar_view_week),
              ),
            ],
            selected: {_deliverySlotType},
            onSelectionChanged: (Set<ScheduleRecurrenceType> newSelection) {
              setState(() {
                _deliverySlotType = newSelection.first;
                _deliveryDate = null;
                _deliveryDaysOfWeek.clear();
              });
            },
          ),
          const SizedBox(height: 24),

          // One-Time Delivery
          if (_deliverySlotType == ScheduleRecurrenceType.oneTime) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.event, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      const Text('Select Delivery Date',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _deliveryDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _deliveryDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blue[300]!),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue[700]),
                          const SizedBox(width: 12),
                          Text(
                            _deliveryDate != null
                                ? 'Delivery Date: ${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}'
                                : 'Select Delivery Date',
                            style: TextStyle(
                              color: _deliveryDate != null ? Colors.black87 : Colors.grey,
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

          // Daily Delivery
          if (_deliverySlotType == ScheduleRecurrenceType.daily) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      const Text('Daily Delivery Time',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _deliveryStartTime ?? const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (picked != null) {
                              setState(() => _deliveryStartTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.green[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _deliveryStartTime != null
                                      ? 'Start: ${_deliveryStartTime!.format(context)}'
                                      : 'Start Time',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _deliveryEndTime ?? const TimeOfDay(hour: 18, minute: 0),
                            );
                            if (picked != null) {
                              setState(() => _deliveryEndTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.green[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.green[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _deliveryEndTime != null
                                      ? 'End: ${_deliveryEndTime!.format(context)}'
                                      : 'End Time',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Weekly Delivery
          if (_deliverySlotType == ScheduleRecurrenceType.weekly) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_view_week, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      const Text('Select Delivery Days',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildDeliveryDayChip(1, 'Mon'),
                      _buildDeliveryDayChip(2, 'Tue'),
                      _buildDeliveryDayChip(3, 'Wed'),
                      _buildDeliveryDayChip(4, 'Thu'),
                      _buildDeliveryDayChip(5, 'Fri'),
                      _buildDeliveryDayChip(6, 'Sat'),
                      _buildDeliveryDayChip(7, 'Sun'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _deliveryStartTime ?? const TimeOfDay(hour: 8, minute: 0),
                            );
                            if (picked != null) {
                              setState(() => _deliveryStartTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _deliveryStartTime != null
                                      ? 'Start: ${_deliveryStartTime!.format(context)}'
                                      : 'Start Time',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: _deliveryEndTime ?? const TimeOfDay(hour: 18, minute: 0),
                            );
                            if (picked != null) {
                              setState(() => _deliveryEndTime = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange[300]!),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.orange[700]),
                                const SizedBox(width: 12),
                                Text(
                                  _deliveryEndTime != null
                                      ? 'End: ${_deliveryEndTime!.format(context)}'
                                      : 'End Time',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildStep6Charges() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: Colors.purple[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 6: Charges',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Additional Charges (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'These charges will be added to each order in this schedule',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),

          // Delivery Charges
          TextField(
            controller: _deliveryChargesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Delivery Charges',
              hintText: 'Enter delivery charges (₹)',
              prefixIcon: const Icon(Icons.local_shipping),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _deliveryCharges = double.tryParse(value) ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 16),

          // Cleaning Charges
          TextField(
            controller: _cleaningChargesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cleaning Charges',
              hintText: 'Enter cleaning charges (₹)',
              prefixIcon: const Icon(Icons.cleaning_services),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            onChanged: (value) {
              setState(() {
                _cleaningCharges = double.tryParse(value) ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 24),

          // Summary Card
          if (_deliveryCharges > 0 || _cleaningCharges > 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Charges Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  if (_deliveryCharges > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Delivery Charges:'),
                        Text(
                          '₹${_deliveryCharges.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  if (_cleaningCharges > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cleaning Charges:'),
                        Text(
                          '₹${_cleaningCharges.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Additional Charges:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₹${(_deliveryCharges + _cleaningCharges).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep7Summary() {
    final branchesAsync = ref.watch(branchesStreamProvider);
    final hubsAsync = ref.watch(hubsStreamProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.summarize, color: Colors.purple[700]),
                const SizedBox(width: 12),
                const Text(
                  'Stage 4: Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Date & Time Section
          _buildSummarySection(
            icon: Icons.calendar_today,
            title: 'Date & Time',
            children: [
              _buildSummaryItem('Date',
                  _selectedDate != null ? DateFormat('dd/MM/yyyy').format(_selectedDate!) : 'Not selected'),
              _buildSummaryItem('Start Time',
                  _startTime != null ? '${_startTime!.hour}:${_startTime!.minute}' : 'Not selected'),
              _buildSummaryItem('End Time',
                  _endTime != null ? '${_endTime!.hour}:${_endTime!.minute}' : 'Not selected'),
            ],
          ),

          // Location Section
          _buildSummarySection(
            icon: Icons.location_on,
            title: 'Location',
            children: [
              branchesAsync.when(
                data: (branches) {
                  final branch = branches.cast<BranchModel?>().firstWhere(
                    (b) => b?.id == _selectedBranchId,
                    orElse: () => null,
                  );
                  return _buildSummaryItem('Branch', branch?.name ?? 'Not selected');
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              hubsAsync.when(
                data: (hubs) {
                  final hub = hubs.cast<HubModel?>().firstWhere(
                    (h) => h?.id == _selectedHubId,
                    orElse: () => null,
                  );
                  return _buildSummaryItem('Hub', hub?.name ?? 'Not selected');
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              _buildSummaryItem('Visibility', _visibilityScope.display),
              if (_visibilityScope == ScheduleVisibilityScope.selectedApartments)
                _buildSummaryItem('Apartments',
                    _selectedApartmentNames.isEmpty ? 'None selected' : _selectedApartmentNames.join(', ')),
            ],
          ),

          // Farmers Section
          _buildSummarySection(
            icon: Icons.agriculture,
            title: 'Farmers',
            children: [
              _buildSummaryItem('Selected Farmers',
                  _selectedFarmerNames.isEmpty ? 'None selected' : _selectedFarmerNames.join(', ')),
            ],
          ),

          // Products Section
          _buildSummarySection(
            icon: Icons.inventory_2,
            title: 'Products',
            children: [
              if (_selectedProducts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No products selected', style: TextStyle(color: Colors.grey[600])),
                )
              else
                ...() {
                  // Group products by farmer
                  final groupedProducts = <String, List<ScheduleProductItem>>{};
                  for (final product in _selectedProducts) {
                    final farmerName = product.farmerName ?? 'Unknown Farmer';
                    if (!groupedProducts.containsKey(farmerName)) {
                      groupedProducts[farmerName] = [];
                    }
                    groupedProducts[farmerName]!.add(product);
                  }
                  
                  return groupedProducts.entries.map((entry) {
                    final farmerName = entry.key;
                    final farmerProducts = entry.value;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.orange[700]),
                                const SizedBox(width: 6),
                                Text(
                                  farmerName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '(${farmerProducts.length})',
                                  style: TextStyle(
                                    color: Colors.orange[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...farmerProducts.map((product) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                const SizedBox(width: 22),
                                Icon(Icons.circle, size: 6, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Text(
                                  product.productName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${product.productCategory})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹${product.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ),
                    );
                  }).toList();
                }(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Colors.grey[700]),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.summarize, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Schedule Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Date & Time
            _buildSummarySection(
              icon: Icons.calendar_today,
              title: 'Date & Time',
              children: [
                _buildSummaryItem('Date', _selectedDate != null 
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' 
                    : 'Not selected'),
                if (_isFullDay)
                  _buildSummaryItem('Duration', 'Full Day (24 Hours)')
                else ...[
                  _buildSummaryItem('Start Time', _startTime != null 
                      ? '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                  _buildSummaryItem('End Time', _endTime != null 
                      ? '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                ],
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Location
            _buildSummarySection(
              icon: Icons.location_on,
              title: 'Location',
              children: [
                _buildSummaryItem('Branch', _selectedBranchName ?? 'Not selected'),
                _buildSummaryItem('Hub', _selectedHubName ?? 'Not selected'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Visibility
            _buildSummarySection(
              icon: Icons.visibility,
              title: 'Visibility',
              children: [
                _buildSummaryItem('Scope', _visibilityScope == ScheduleVisibilityScope.entireHub 
                    ? 'Entire Hub' 
                    : 'Selected Apartments'),
                if (_visibilityScope == ScheduleVisibilityScope.selectedApartments)
                  _buildSummaryItem('Apartments', _selectedApartmentNames.isEmpty 
                      ? 'None selected' 
                      : _selectedApartmentNames.join(', ')),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Recurrence
            _buildSummarySection(
              icon: Icons.repeat,
              title: 'Recurrence',
              children: [
                _buildSummaryItem('Type', _recurrenceType.name),
                if (_recurrenceType != ScheduleRecurrenceType.oneTime)
                  _buildSummaryItem('End Date', _recurrenceEndDate != null 
                      ? '${_recurrenceEndDate!.day}/${_recurrenceEndDate!.month}/${_recurrenceEndDate!.year}' 
                      : 'Not set'),
                if (_recurrenceType == ScheduleRecurrenceType.customDays && _recurrenceDaysOfWeek.isNotEmpty)
                  _buildSummaryItem('Days', _recurrenceDaysOfWeek.map((d) {
                    final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                    return dayNames[d];
                  }).join(', ')),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Farmers
            _buildSummarySection(
              icon: Icons.agriculture,
              title: 'Farmers',
              children: [
                _buildSummaryItem('Selected', _selectedFarmerNames.isEmpty 
                    ? 'None selected' 
                    : '${_selectedFarmerNames.length} farmers'),
                if (_selectedFarmerNames.isNotEmpty)
                  ..._selectedFarmerNames.map((name) => Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 4, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Products
            _buildSummarySection(
              icon: Icons.inventory_2,
              title: 'Products',
              children: [
                _buildSummaryItem('Total', _selectedProducts.isEmpty 
                    ? 'None selected' 
                    : '${_selectedProducts.length} products'),
                if (_selectedProducts.isNotEmpty)
                  ...() {
                    final groupedProducts = <String, List<ScheduleProductItem>>{};
                    for (final product in _selectedProducts) {
                      final farmerName = product.farmerName ?? 'Unknown Farmer';
                      if (!groupedProducts.containsKey(farmerName)) {
                        groupedProducts[farmerName] = [];
                      }
                      groupedProducts[farmerName]!.add(product);
                    }
                    
                    return groupedProducts.entries.map((entry) {
                      final farmerName = entry.key;
                      final farmerProducts = entry.value;
                      
                      return Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.person, size: 12, color: Colors.orange[700]),
                                const SizedBox(width: 6),
                                Text(
                                  farmerName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '(${farmerProducts.length})',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            ...farmerProducts.map((product) => Padding(
                              padding: const EdgeInsets.only(left: 18, top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.circle, size: 4, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      product.productName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₹${product.price.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange[700],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    }).toList();
                  }(),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Delivery Slot
            _buildSummarySection(
              icon: Icons.local_shipping,
              title: 'Delivery Slot',
              children: [
                _buildSummaryItem('Type', _deliverySlotType.name),
                if (_deliverySlotType == ScheduleRecurrenceType.oneTime)
                  _buildSummaryItem('Delivery Date', _deliveryDate != null 
                      ? '${_deliveryDate!.day}/${_deliveryDate!.month}/${_deliveryDate!.year}' 
                      : 'Not selected'),
                if (_deliverySlotType == ScheduleRecurrenceType.daily) ...[
                  _buildSummaryItem('Start Time', _deliveryStartTime != null 
                      ? '${_deliveryStartTime!.hour.toString().padLeft(2, '0')}:${_deliveryStartTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                  _buildSummaryItem('End Time', _deliveryEndTime != null 
                      ? '${_deliveryEndTime!.hour.toString().padLeft(2, '0')}:${_deliveryEndTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                ],
                if (_deliverySlotType == ScheduleRecurrenceType.weekly) ...[
                  _buildSummaryItem('Delivery Days', _deliveryDaysOfWeek.isEmpty 
                      ? 'None selected' 
                      : _deliveryDaysOfWeek.map((d) {
                          final dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          return dayNames[d];
                        }).join(', ')),
                  _buildSummaryItem('Start Time', _deliveryStartTime != null 
                      ? '${_deliveryStartTime!.hour.toString().padLeft(2, '0')}:${_deliveryStartTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                  _buildSummaryItem('End Time', _deliveryEndTime != null 
                      ? '${_deliveryEndTime!.hour.toString().padLeft(2, '0')}:${_deliveryEndTime!.minute.toString().padLeft(2, '0')}' 
                      : 'Not selected'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text('$label:',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          ElevatedButton(
            onPressed: () {
              setState(() => _currentStep--);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Back'),
          ),
        if (_currentStep == 0) const SizedBox(),
        if (_currentStep < 6)
          ElevatedButton(
            onPressed: _canProceed() ? () => setState(() => _currentStep++) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canProceed() ? Colors.blue : Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Next'),
          ),
        if (_currentStep == 6)
          ElevatedButton(
            onPressed: (_canSubmit() && !_isCreatingSchedule) ? _submitSchedule : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSubmit() ? Colors.green : Colors.grey[300],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isCreatingSchedule
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Create Schedule'),
          ),
      ],
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Date & Time
        return _scheduleName.trim().isNotEmpty &&
            _selectedDate != null &&
            (_isFullDay || (_startTime != null && _endTime != null)) &&
            (_recurrenceType == ScheduleRecurrenceType.oneTime ||
                (_recurrenceType == ScheduleRecurrenceType.daily && _recurrenceEndDate != null) ||
                (_recurrenceType == ScheduleRecurrenceType.weekly && _recurrenceEndDate != null && _recurrenceDaysOfWeek.isNotEmpty));
      case 1: // Location
        return _selectedBranchId != null &&
            _selectedHubId != null &&
            (_visibilityScope == ScheduleVisibilityScope.entireHub ||
                _selectedApartmentIds.isNotEmpty);
      case 2: // Farmers
        return _selectedFarmerIds.isNotEmpty;
      case 3: // Products
        return _selectedProducts.isNotEmpty;
      case 4: // Delivery Slot
        return (_deliverySlotType == ScheduleRecurrenceType.oneTime && _deliveryDate != null) ||
            (_deliverySlotType == ScheduleRecurrenceType.daily && _deliveryStartTime != null && _deliveryEndTime != null) ||
            (_deliverySlotType == ScheduleRecurrenceType.weekly && _deliveryDaysOfWeek.isNotEmpty && _deliveryStartTime != null && _deliveryEndTime != null);
      case 5: // Charges
        return true; // Charges are optional
      case 6: // Summary
        return true;
      default:
        return false;
    }
  }

  bool _canSubmit() {
    return _canProceed();
  }

  void _submitSchedule() async {
    setState(() {
      _isCreatingSchedule = true;
    });

    try {
      final userAsync = ref.read(currentUserProvider);
      final user = userAsync.value;
      if (user == null) {
        setState(() {
          _isCreatingSchedule = false;
        });
        return;
      }

      final branchesAsync = ref.read(branchesStreamProvider);
      final hubsAsync = ref.read(hubsStreamProvider);

      final branches = branchesAsync.value ?? [];
      final hubs = hubsAsync.value ?? [];

      final branch = branches.cast<BranchModel?>().firstWhere(
        (b) => b?.id == _selectedBranchId,
        orElse: () => null,
      );
      final hub = hubs.cast<HubModel?>().firstWhere(
        (h) => h?.id == _selectedHubId,
        orElse: () => null,
      );

      final schedule = OperationalScheduleModel(
        id: '',
        scheduleName: _scheduleName,
        scheduledDate: _selectedDate!,
        startTime:
            '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
        endTime:
            '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}',
        branchId: _selectedBranchId!,
        branchName: branch?.name ?? '',
        hubId: _selectedHubId!,
        hubName: hub?.name ?? '',
        visibilityScope: _visibilityScope,
        selectedApartmentIds: _selectedApartmentIds,
        selectedApartmentNames: _selectedApartmentNames,
        products: _selectedProducts,
        isActive: true,
        isDeleted: false,
        createdAt: DateTime.now(),
        createdBy: user.id,
        recurrenceType: _recurrenceType,
        recurrenceEndDate: _recurrenceEndDate,
        recurrenceDaysOfWeek: _recurrenceDaysOfWeek,
        // Delivery slot fields
        deliverySlotType: _deliverySlotType,
        deliveryDate: _deliveryDate,
        deliveryStartTime: _deliveryStartTime != null
            ? '${_deliveryStartTime!.hour.toString().padLeft(2, '0')}:${_deliveryStartTime!.minute.toString().padLeft(2, '0')}'
            : null,
        deliveryEndTime: _deliveryEndTime != null
            ? '${_deliveryEndTime!.hour.toString().padLeft(2, '0')}:${_deliveryEndTime!.minute.toString().padLeft(2, '0')}'
            : null,
        deliveryDaysOfWeek: _deliveryDaysOfWeek,
        // Charges
        deliveryCharges: _deliveryCharges,
        cleaningCharges: _cleaningCharges,
      );

      final repository = ref.read(operationalScheduleRepositoryProvider);
      await repository.createSchedule(schedule, user.id, user.role);

      // Invalidate stats provider to trigger immediate update
      ref.invalidate(scheduleStatsProvider);

      if (mounted) {
        setState(() {
          _isCreatingSchedule = false;
        });
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule created successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreatingSchedule = false;
        });
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

extension on ScheduleVisibilityScope {
  String get display {
    switch (this) {
      case ScheduleVisibilityScope.entireHub:
        return 'Entire Hub';
      case ScheduleVisibilityScope.selectedApartments:
        return 'Selected Apartments';
    }
  }
}
