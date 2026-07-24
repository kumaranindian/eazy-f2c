import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/models/apartment_model.dart';
import 'package:f2c/features/admin/models/hub_model.dart';
import 'package:f2c/features/admin/providers/apartment_providers.dart';
import 'package:f2c/features/admin/providers/hub_providers.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

class EditApartmentDialog extends ConsumerStatefulWidget {
  final ApartmentModel apartment;

  const EditApartmentDialog({
    super.key,
    required this.apartment,
  });

  @override
  ConsumerState<EditApartmentDialog> createState() => _EditApartmentDialogState();
}

class _EditApartmentDialogState extends ConsumerState<EditApartmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  late TextEditingController _deliveryTimeController;
  late TextEditingController _pickupPointController;
  String? _selectedHubId;
  String? _selectedHubName;
  late String _deliveryDay;
  late bool _isActive;
  bool _isLoading = false;

  final List<String> _deliveryDays = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.apartment.name);
    _locationController = TextEditingController(text: widget.apartment.location);
    _deliveryTimeController = TextEditingController(text: widget.apartment.deliveryTime);
    _pickupPointController = TextEditingController(text: widget.apartment.pickupPoint);
    _selectedHubId = widget.apartment.hubId;
    _selectedHubName = widget.apartment.hubName;
    _deliveryDay = widget.apartment.deliveryDay;
    _isActive = widget.apartment.isActive;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _deliveryTimeController.dispose();
    _pickupPointController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedHubId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a HUB'),
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

      final updatedApartment = widget.apartment.copyWith(
        name: _nameController.text.trim(),
        hubId: _selectedHubId!,
        hubName: _selectedHubName!,
        location: _locationController.text.trim(),
        deliveryDay: _deliveryDay,
        deliveryTime: _deliveryTimeController.text.trim(),
        pickupPoint: _pickupPointController.text.trim(),
        isActive: _isActive,
        updatedAt: DateTime.now(),
        updatedBy: user.id,
      );

      final repository = ref.read(apartmentRepositoryProvider);
      await repository.updateApartment(
        widget.apartment.id,
        updatedApartment,
        user.id,
        user.role,
      );

      // Refresh stats to update metrics
      ref.invalidate(apartmentStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apartment updated successfully'),
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
    final hubsAsync = ref.watch(hubsStreamProvider);

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
                    'Edit Apartment',
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
                  labelText: 'Apartment Name *',
                  hintText: 'Enter apartment name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.apartment),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Apartment name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              hubsAsync.when(
                data: (hubs) {
                  final activeHubs = hubs.where((h) => !h.isDeleted).toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedHubId,
                    decoration: const InputDecoration(
                      labelText: 'HUB *',
                      hintText: 'Select HUB',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.hub),
                    ),
                    items: activeHubs.map((hub) {
                      return DropdownMenuItem<String>(
                        value: hub.id,
                        child: Text(hub.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        final hub = activeHubs.firstWhere((h) => h.id == value);
                        setState(() {
                          _selectedHubId = value;
                          _selectedHubName = hub.name;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'HUB is required';
                      }
                      return null;
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Text('Error loading HUBs: $error'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  hintText: 'Enter location',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _deliveryDay,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Day *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      items: _deliveryDays.map((day) {
                        return DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _deliveryDay = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _deliveryTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Delivery Time *',
                        hintText: 'e.g., 08:00 AM',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Delivery time is required';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pickupPointController,
                decoration: const InputDecoration(
                  labelText: 'Pickup Point *',
                  hintText: 'Enter pickup point',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.place),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pickup point is required';
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
                    label: Text(_isLoading ? 'Updating...' : 'Update Apartment'),
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
