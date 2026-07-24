import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/models/customer_model.dart';
import 'package:f2c/features/admin/models/apartment_model.dart';
import 'package:f2c/features/admin/providers/customer_providers.dart';
import 'package:f2c/features/admin/providers/apartment_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

class EditCustomerDialog extends ConsumerStatefulWidget {
  final CustomerModel customer;

  const EditCustomerDialog({
    super.key,
    required this.customer,
  });

  @override
  ConsumerState<EditCustomerDialog> createState() => _EditCustomerDialogState();
}

class _EditCustomerDialogState extends ConsumerState<EditCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _alternativePhoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  String? _selectedApartmentId;
  String? _selectedApartmentName;
  String? _selectedHubId;
  String? _selectedHubName;
  String? _selectedBranchId;
  String? _selectedBranchName;
  late bool _isActive;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phone);
    _alternativePhoneController = TextEditingController(
      text: widget.customer.alternativePhone ?? '',
    );
    _emailController = TextEditingController(text: widget.customer.email);
    _addressController = TextEditingController(text: widget.customer.address);
    _selectedApartmentId = widget.customer.apartmentId;
    _selectedApartmentName = widget.customer.apartmentName;
    _selectedHubId = widget.customer.hubId;
    _selectedHubName = widget.customer.hubName;
    _selectedBranchId = widget.customer.branchId;
    _selectedBranchName = widget.customer.branchName;
    _isActive = widget.customer.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _alternativePhoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedApartmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an apartment'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) {
        throw Exception('User not found');
      }

      final updatedCustomer = widget.customer.copyWith(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        alternativePhone: _alternativePhoneController.text.trim().isEmpty
            ? null
            : _alternativePhoneController.text.trim(),
        email: _emailController.text.trim(),
        apartmentId: _selectedApartmentId!,
        apartmentName: _selectedApartmentName!,
        hubId: _selectedHubId!,
        hubName: _selectedHubName!,
        branchId: _selectedBranchId!,
        branchName: _selectedBranchName!,
        address: _addressController.text.trim(),
        isActive: _isActive,
        updatedAt: DateTime.now(),
        updatedBy: user.id,
      );

      final repository = ref.read(customerRepositoryProvider);
      await repository.updateCustomer(
        widget.customer.id,
        updatedCustomer,
        user.id,
        user.role,
      );

      // Refresh stats to update metrics
      ref.invalidate(customerStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Customer updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apartmentsAsync = ref.watch(apartmentsStreamProvider);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Customer',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  hintText: 'Enter customer name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Customer name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  hintText: '+91 98765 43210',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alternativePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Alternative Phone (Optional)',
                  hintText: '+91 98765 43211',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email *',
                  hintText: 'customer@example.com',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Invalid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              apartmentsAsync.when(
                data: (apartments) {
                  final activeApartments = apartments.where((a) => !a.isDeleted).toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedApartmentId,
                    decoration: const InputDecoration(
                      labelText: 'Apartment *',
                      hintText: 'Select apartment',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.apartment),
                    ),
                    items: activeApartments.map((apartment) {
                      return DropdownMenuItem<String>(
                        value: apartment.id,
                        child: Text('${apartment.name} - ${apartment.location}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final apartment = activeApartments.firstWhere((a) => a.id == value);
                        setState(() {
                          _selectedApartmentId = value;
                          _selectedApartmentName = apartment.name;
                          _selectedHubId = apartment.hubId;
                          _selectedHubName = apartment.hubName;
                          _selectedBranchId = apartment.hubId;
                          _selectedBranchName = apartment.hubName;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Apartment is required';
                      }
                      return null;
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error loading apartments: $error'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address *',
                  hintText: 'Enter address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Address is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                value: _isActive,
                decoration: const InputDecoration(
                  labelText: 'Status *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.toggle_on_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: true,
                    child: Text('Active'),
                  ),
                  DropdownMenuItem(
                    value: false,
                    child: Text('Inactive'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _isActive = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _handleSubmit,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Updating...' : 'Update Customer'),
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
            ],
          ),
        ),
      ),
    );
  }
}
