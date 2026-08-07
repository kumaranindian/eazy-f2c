import 'package:flutter/material.dart';
import 'package:f2c/core/utils/image_url_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/admin/models/unit_model.dart';
import 'package:f2c/features/admin/providers/product_providers.dart';
import 'package:f2c/features/admin/providers/category_providers.dart';
import 'package:f2c/features/admin/providers/farmer_providers.dart';
import 'package:f2c/features/admin/providers/unit_providers.dart';
import 'package:f2c/features/admin/presentation/widgets/firebase_image_picker.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

class EditProductDialog extends ConsumerStatefulWidget {
  final ProductModel product;

  const EditProductDialog({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends ConsumerState<EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _displayNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _profitMarginController;
  late TextEditingController _newUnitController;
  late TextEditingController _newCategoryController;
  late TextEditingController _stockController;
  String? _selectedCategoryId;
  String? _selectedFarmerId;
  String? _selectedUnitId;
  String? _imageUrl;
  late bool _isActive;
  bool _isLoading = false;
  bool _isCreatingNewCategory = false;
  bool _isCreatingNewUnit = false;
  int _currentStep = 0;
  final int _totalSteps = 5;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _displayNameController = TextEditingController(text: widget.product.displayName);
    _descriptionController = TextEditingController(text: widget.product.description);
    _priceController = TextEditingController(text: widget.product.price.toString());
    _profitMarginController = TextEditingController(text: widget.product.profitMargin.toString());
    _newUnitController = TextEditingController();
    _newCategoryController = TextEditingController();
    _stockController = TextEditingController(text: widget.product.stockQuantity.toString());
    _selectedFarmerId = widget.product.farmerId;
    _imageUrl = widget.product.imageUrl;
    _isActive = widget.product.isActive;
    
    // Initialize category and unit IDs after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeCategoryAndUnitIds();
    });
  }
  
  void _initializeCategoryAndUnitIds() {
    final categories = ref.read(categoriesStreamProvider).value ?? [];
    final units = ref.read(unitsStreamProvider).value ?? [];
    final product = widget.product;

    if (categories.isEmpty && units.isEmpty) return;

    // Find category ID matching product's category name
    if (_selectedCategoryId == null && categories.isNotEmpty) {
      final matchingCategory = categories.firstWhere(
        (cat) => cat.name == product.category,
        orElse: () => categories.first,
      );
      _selectedCategoryId = matchingCategory.id;
    }

    // Find unit ID matching product's unit symbol or name
    if (_selectedUnitId == null && units.isNotEmpty) {
      final matchingUnit = units.firstWhere(
        (unit) =>
            unit.symbol == product.unit ||
            unit.name.toLowerCase() == product.unit.toLowerCase(),
        orElse: () => units.first,
      );
      _selectedUnitId = matchingUnit.id;
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _displayNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _profitMarginController.dispose();
    _newUnitController.dispose();
    _newCategoryController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_imageUrl == null || _imageUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a product image'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isCreatingNewCategory && (_selectedCategoryId == null || _selectedCategoryId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isCreatingNewCategory && _newCategoryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a category name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isCreatingNewUnit && (_selectedUnitId == null || _selectedUnitId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a unit'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_isCreatingNewUnit && _newUnitController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a unit name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedFarmerId == null || _selectedFarmerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a farmer'),
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

      String categoryName = '';
      
      // Create new category if needed
      if (_isCreatingNewCategory) {
        final category = CategoryModel(
          id: '',
          name: _newCategoryController.text.trim(),
          description: '',
          isActive: true,
          isDeleted: false,
          createdAt: DateTime.now(),
          createdBy: user.id,
        );
        
        final categoryRepository = ref.read(categoryRepositoryProvider);
        final categoryId = await categoryRepository.createCategory(
          category,
          user.id,
          user.role,
        );
        categoryName = _newCategoryController.text.trim();
        _selectedCategoryId = categoryId;
      } else {
        // Get category name from selected category
        final categories = ref.read(categoriesStreamProvider).value ?? [];
        final selectedCategory = categories.firstWhere(
          (cat) => cat.id == _selectedCategoryId,
          orElse: () => throw Exception('Category not found'),
        );
        categoryName = selectedCategory.name;
      }

      String unitSymbol = '';
      
      // Create new unit if needed
      if (_isCreatingNewUnit) {
        final unit = UnitModel(
          id: '',
          name: _newUnitController.text.trim(),
          symbol: _newUnitController.text.trim().toLowerCase(),
          category: categoryName == 'Meat' ? 'meat' : 'grocery',
          isActive: true,
          isDeleted: false,
          createdAt: DateTime.now(),
          createdBy: user.id,
        );
        
        final unitRepository = ref.read(unitRepositoryProvider);
        final createdUnit = await unitRepository.createUnit(unit);
        unitSymbol = createdUnit.symbol;
        _selectedUnitId = createdUnit.id;
      } else {
        // Get unit symbol from selected unit
        final units = ref.read(unitsStreamProvider).value ?? [];
        final selectedUnit = units.firstWhere(
          (unit) => unit.id == _selectedUnitId,
          orElse: () => throw Exception('Unit not found'),
        );
        unitSymbol = selectedUnit.symbol;
      }

      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        displayName: _displayNameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrl!,
        price: double.parse(_priceController.text.trim()),
        profitMargin: double.tryParse(_profitMarginController.text.trim()) ?? 0.0,
        unit: unitSymbol,
        category: categoryName,
        farmerId: _selectedFarmerId,
        isActive: _isActive,
        updatedAt: DateTime.now(),
        updatedBy: user.id,
        stockQuantity: int.tryParse(_stockController.text.trim()) ?? 0,
      );

      final repository = ref.read(productRepositoryProvider);
      await repository.updateProduct(
        widget.product.id,
        updatedProduct,
        user.id,
        user.role,
      );

      // Refresh stats to update metrics
      ref.invalidate(productStatsProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Product updated successfully'),
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
    // Re-initialize unit and category IDs whenever the underlying streams update
    ref.listen(categoriesStreamProvider, (_, __) => _initializeCategoryAndUnitIds());
    ref.listen(unitsStreamProvider, (_, __) => _initializeCategoryAndUnitIds());

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side - Form steps
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Product',
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
                    
                    // Step indicator
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    
                    // Step content
                    Expanded(
                      child: _buildStepContent(),
                    ),
                    
                    // Navigation buttons
                    _buildNavigationButtons(),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              
              // Right side - Summary panel
              Expanded(
                flex: 1,
                child: _buildSummaryPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: List.generate(_totalSteps, (index) {
        final isCompleted = index < _currentStep;
        final isCurrent = index == _currentStep;
        
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : isCurrent
                          ? Colors.blue
                          : Colors.grey[300],
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (index < _totalSteps - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? Colors.green : Colors.grey[300],
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
        return _buildStep1BasicInfo();
      case 1:
        return _buildStep2ImageSelection();
      case 2:
        return _buildStep3Pricing();
      case 3:
        return _buildStep4CategoryUnit();
      case 4:
        return _buildStep5FarmerStatus();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1BasicInfo() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Basic Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Product Name (Farmer) *',
              hintText: 'Enter product name for farmers',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory_2),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Product name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final displayNamesAsync = ref.watch(displayNamesProvider);
              
              return Autocomplete<String>(
                initialValue: TextEditingValue(text: _displayNameController.text),
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.length < 4) {
                    return const Iterable<String>.empty();
                  }
                  
                  final displayNames = displayNamesAsync.value ?? [];
                  return displayNames.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  _displayNameController.text = textEditingController.text;
                  textEditingController.addListener(() {
                    _displayNameController.text = textEditingController.text;
                  });
                  
                  return TextFormField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Display Name (Customer) *',
                      hintText: 'Enter display name for customers',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront),
                      helperText: 'Type 4+ characters for suggestions',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name is required';
                      }
                      return null;
                    },
                  );
                },
                onSelected: (String selection) {
                  _displayNameController.text = selection;
                },
              );
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description *',
              hintText: 'Enter product description',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.description),
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2ImageSelection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Image',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload a high-quality image of your product',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Firebase Image Picker
          Center(
            child: FirebaseImagePicker(
              initialImageUrl: _imageUrl,
              onImageSelected: (url) {
                setState(() {
                  _imageUrl = url;
                });
              },
              folder: 'product_images',
              width: 400,
              height: 400,
            ),
          ),
          
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
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Supported formats: JPG, PNG, GIF, WebP. Maximum size: 5MB',
                    style: TextStyle(color: Colors.blue[900], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Pricing() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pricing & Stock',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price *',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                    helperText: 'Includes profit margin',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Price is required';
                    }
                    if (double.tryParse(value.trim()) == null) {
                      return 'Invalid price';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _profitMarginController,
                  decoration: const InputDecoration(
                    labelText: 'Profit Margin',
                    hintText: '0.00',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.trending_up),
                    helperText: 'Profit amount per unit',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stockController,
            decoration: const InputDecoration(
              labelText: 'Stock Quantity',
              hintText: '0',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.inventory),
            ),
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildStep4CategoryUnit() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Category & Unit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final categoriesAsync = ref.watch(categoriesStreamProvider);
              
              return categoriesAsync.when(
                data: (categories) {
                  final activeCategories = categories
                      .where((cat) => !cat.isDeleted && cat.isActive)
                      .toList();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      hintText: 'Select category',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: activeCategories.isEmpty
                        ? [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('No categories available'),
                            ),
                          ]
                        : activeCategories
                            .map((cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ))
                            .toList(),
                    onChanged: _isCreatingNewCategory
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCategoryId = value;
                            });
                          },
                    validator: (value) {
                      if (!_isCreatingNewCategory &&
                          (value == null || value.isEmpty)) {
                        return 'Category is required';
                      }
                      return null;
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => 
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [],
                      onChanged: null,
                    ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _isCreatingNewCategory,
                onChanged: (value) {
                  setState(() {
                    _isCreatingNewCategory = value ?? false;
                    if (_isCreatingNewCategory) {
                      _selectedCategoryId = null;
                    }
                  });
                },
              ),
              const Text('Add New'),
              const SizedBox(width: 8),
              if (_isCreatingNewCategory)
                Expanded(
                  child: TextFormField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(
                      labelText: 'New Category Name *',
                      hintText: 'Enter category name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_isCreatingNewCategory && (value == null || value.trim().isEmpty)) {
                        return 'Category name is required';
                      }
                      return null;
                    },
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final unitsAsync = ref.watch(unitsStreamProvider);
                    
                    return unitsAsync.when(
                      data: (units) {
                        final activeUnits = units
                            .where((unit) => !unit.isDeleted && unit.isActive)
                            .toList();
                        
                        return DropdownButtonFormField<String>(
                          value: _selectedUnitId,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            hintText: 'Select unit',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: activeUnits.isEmpty
                              ? [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('No units available'),
                                  ),
                                ]
                              : activeUnits
                                  .map((unit) => DropdownMenuItem(
                                        value: unit.id,
                                        child: Text('${unit.name} (${unit.symbol})'),
                                      ))
                                  .toList(),
                          onChanged: _isCreatingNewUnit
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedUnitId = value;
                                  });
                                },
                          validator: (value) {
                            if (!_isCreatingNewUnit &&
                                (value == null || value.isEmpty)) {
                              return 'Unit is required';
                            }
                            return null;
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => 
                          DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Unit *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.straighten),
                            ),
                            items: const [],
                            onChanged: null,
                          ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: _isCreatingNewUnit,
                onChanged: (value) {
                  setState(() {
                    _isCreatingNewUnit = value ?? false;
                    if (_isCreatingNewUnit) {
                      _selectedUnitId = null;
                    }
                  });
                },
              ),
              const Text('Add New'),
            ],
          ),
          const SizedBox(height: 8),
          if (_isCreatingNewUnit)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: TextFormField(
                controller: _newUnitController,
                decoration: const InputDecoration(
                  labelText: 'New Unit Name *',
                  hintText: 'Enter unit name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (_isCreatingNewUnit && (value == null || value.trim().isEmpty)) {
                    return 'Unit name is required';
                  }
                  return null;
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep5FarmerStatus() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Farmer & Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, child) {
              final farmersAsync = ref.watch(farmersStreamProvider);
              
              return farmersAsync.when(
                data: (farmers) {
                  final activeFarmers = farmers
                      .where((farmer) => !farmer.isDeleted && farmer.isActive)
                      .toList();
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedFarmerId,
                    decoration: const InputDecoration(
                      labelText: 'Farmer',
                      hintText: 'Select farmer (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.agriculture),
                    ),
                    items: activeFarmers.isEmpty
                        ? [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('No farmers available'),
                            ),
                          ]
                        : activeFarmers
                            .map((farmer) => DropdownMenuItem(
                                  value: farmer.id,
                                  child: Text(farmer.name),
                                ))
                            .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedFarmerId = value;
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => 
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Farmer',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.agriculture),
                      ),
                      items: const [],
                      onChanged: null,
                    ),
              );
            },
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Active Status'),
            subtitle: const Text('Enable this product for customers'),
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentStep--;
                });
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[600],
                foregroundColor: Colors.white,
              ),
            )
          else
            const SizedBox.shrink(),
          if (_currentStep < _totalSteps - 1)
            ElevatedButton.icon(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  setState(() {
                    _currentStep++;
                  });
                }
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
            )
          else
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
              label: Text(_isLoading ? 'Updating...' : 'Update Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Product Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSummaryItem('Product Name', _nameController.text),
                  _buildSummaryItem('Display Name', _displayNameController.text),
                  _buildSummaryItem('Description', _descriptionController.text, maxLines: 2),
                  _buildSummaryItem('Price', _priceController.text),
                  _buildSummaryItem('Profit Margin', _profitMarginController.text),
                  _buildSummaryItem('Stock', _stockController.text),
                  if (_imageUrl != null)
                    _buildSummaryItem('Image', 'Uploaded', maxLines: 2),
                  _buildSummaryItem('Category', _isCreatingNewCategory ? _newCategoryController.text : _selectedCategoryId ?? 'Not selected'),
                  _buildSummaryItem('Unit', _isCreatingNewUnit ? _newUnitController.text : _selectedUnitId ?? 'Not selected'),
                  _buildSummaryItem('Farmer', _selectedFarmerId ?? 'Not selected'),
                  _buildSummaryItem('Status', _isActive ? 'Active' : 'Inactive'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? 'Not filled' : value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
