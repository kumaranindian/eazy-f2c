import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/admin/models/customer_model.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/customer/models/cart_item_model.dart';

// Provider for current customer data
final currentCustomerProvider = StreamProvider.autoDispose<CustomerModel?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  
  return userAsync.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }

      return FirebaseFirestore.instance
          .collection('customers')
          .where('email', isEqualTo: user.email)
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .snapshots()
          .map((snapshot) {
            if (snapshot.docs.isEmpty) {
              return null;
            }
            return CustomerModel.fromFirestore(snapshot.docs.first);
          });
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

// Provider for active operational schedules for the customer's apartment
final activeSchedulesProvider = StreamProvider.autoDispose<List<OperationalScheduleModel>>((ref) {
  final customerAsync = ref.watch(currentCustomerProvider);
  
  return customerAsync.when(
    data: (customer) {
      if (customer == null) {
        return Stream.value([]);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return FirebaseFirestore.instance
          .collection('operational_schedules')
          .where('isDeleted', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            print('DEBUG: Total schedules from Firestore: ${snapshot.docs.length}');
            
            final schedules = snapshot.docs
                .map((doc) => OperationalScheduleModel.fromFirestore(doc))
                .where((schedule) {
                  // First check: must not be deleted and must be active status
                  if (schedule.isDeleted) {
                    print('DEBUG: Skipping deleted schedule: ${schedule.id}');
                    return false;
                  }
                  
                  if (schedule.status != ScheduleStatus.pending && 
                      schedule.status != ScheduleStatus.inProgress) {
                    print('DEBUG: Skipping schedule with status: ${schedule.status}');
                    return false;
                  }
                  
                  // Check if schedule is for today based on recurrence type
                  final scheduleDate = DateTime(
                    schedule.scheduledDate.year,
                    schedule.scheduledDate.month,
                    schedule.scheduledDate.day,
                  );

                  // For one-time schedules, check exact date
                  if (schedule.recurrenceType == ScheduleRecurrenceType.oneTime) {
                    if (!scheduleDate.isAtSameMomentAs(today)) {
                      print('DEBUG: Skipping one-time schedule not for today: ${schedule.id}');
                      return false;
                    }
                  } 
                  // For daily schedules, check if today is within start and end date range
                  else if (schedule.recurrenceType == ScheduleRecurrenceType.daily) {
                    final recurrenceEndDate = schedule.recurrenceEndDate != null
                        ? DateTime(
                            schedule.recurrenceEndDate!.year,
                            schedule.recurrenceEndDate!.month,
                            schedule.recurrenceEndDate!.day,
                          )
                        : null;

                    // Check if today is before start date
                    if (today.isBefore(scheduleDate)) {
                      print('DEBUG: Skipping daily schedule - today is before start date: ${schedule.id}');
                      return false;
                    }

                    // Check if today is after end date
                    if (recurrenceEndDate != null && today.isAfter(recurrenceEndDate)) {
                      print('DEBUG: Skipping daily schedule - today is after end date: ${schedule.id}');
                      return false;
                    }
                    
                    print('DEBUG: Including daily schedule for today: ${schedule.id}');
                  }
                  // For weekly schedules, check if today's day of week matches selected days
                  else if (schedule.recurrenceType == ScheduleRecurrenceType.weekly) {
                    final recurrenceEndDate = schedule.recurrenceEndDate != null
                        ? DateTime(
                            schedule.recurrenceEndDate!.year,
                            schedule.recurrenceEndDate!.month,
                            schedule.recurrenceEndDate!.day,
                          )
                        : null;

                    print('DEBUG: Weekly schedule check - scheduleDate: $scheduleDate, today: $today, recurrenceEndDate: $recurrenceEndDate');
                    print('DEBUG: Weekly schedule - recurrenceDaysOfWeek: ${schedule.recurrenceDaysOfWeek}, today.weekday: ${today.weekday}');

                    // Check if today is before start date
                    if (today.isBefore(scheduleDate)) {
                      print('DEBUG: Skipping weekly schedule - today is before start date: ${schedule.id}');
                      return false;
                    }

                    // Check if today is after end date
                    if (recurrenceEndDate != null && today.isAfter(recurrenceEndDate)) {
                      print('DEBUG: Skipping weekly schedule - today is after end date: ${schedule.id}');
                      return false;
                    }

                    // Check if today's day of week is in the selected days (1=Monday, 7=Sunday)
                    final todayDayOfWeek = today.weekday; // 1=Monday, 7=Sunday
                    if (!schedule.recurrenceDaysOfWeek.contains(todayDayOfWeek)) {
                      print('DEBUG: Skipping weekly schedule - today ($todayDayOfWeek) not in selected days: ${schedule.id}');
                      return false;
                    }
                    
                    print('DEBUG: Including weekly schedule for today: ${schedule.id}');
                  }
                  // For custom days schedules
                  else if (schedule.recurrenceType == ScheduleRecurrenceType.customDays) {
                    final recurrenceEndDate = schedule.recurrenceEndDate != null
                        ? DateTime(
                            schedule.recurrenceEndDate!.year,
                            schedule.recurrenceEndDate!.month,
                            schedule.recurrenceEndDate!.day,
                          )
                        : null;

                    // Check if today is before start date
                    if (today.isBefore(scheduleDate)) {
                      print('DEBUG: Skipping custom days schedule - today is before start date: ${schedule.id}');
                      return false;
                    }

                    // Check if today is after end date
                    if (recurrenceEndDate != null && today.isAfter(recurrenceEndDate)) {
                      print('DEBUG: Skipping custom days schedule - today is after end date: ${schedule.id}');
                      return false;
                    }

                    // Check if today's day of week is in the selected custom days
                    final todayDayOfWeek = today.weekday;
                    if (!schedule.recurrenceDaysOfWeek.contains(todayDayOfWeek)) {
                      print('DEBUG: Skipping custom days schedule - today not in custom days: ${schedule.id}');
                      return false;
                    }
                    
                    print('DEBUG: Including custom days schedule for today: ${schedule.id}');
                  }

                  // Check if schedule applies to customer's apartment
                  final appliesToCustomer = schedule.visibilityScope == ScheduleVisibilityScope.entireHub ||
                      schedule.selectedApartmentIds.contains(customer.apartmentId);
                  
                  if (!appliesToCustomer) {
                    print('DEBUG: Skipping schedule not for customer apartment: ${schedule.id}');
                    return false;
                  }
                  
                  print('DEBUG: Including schedule: ${schedule.id}, status: ${schedule.status}');
                  return true;
                })
                .toList();

            print('DEBUG: Filtered schedules count: ${schedules.length}');
            return schedules;
          });
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Provider for products available in active schedules
final availableProductsProvider = StreamProvider.autoDispose<List<ProductWithSchedule>>((ref) {
  final schedulesAsync = ref.watch(activeSchedulesProvider);

  return schedulesAsync.when(
    data: (schedules) async* {
      if (schedules.isEmpty) {
        yield [];
        return;
      }

      // Collect all unique product IDs from all active schedules
      final availableProductIds = <String>{};
      for (final schedule in schedules) {
        for (final product in schedule.products) {
          availableProductIds.add(product.productId);
        }
      }

      // Fetch ALL active products from Firestore (not just scheduled ones)
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();

      // Fetch all farmers to get farmer names
      final farmersSnapshot = await FirebaseFirestore.instance
          .collection('farmers')
          .where('isActive', isEqualTo: true)
          .where('isDeleted', isEqualTo: false)
          .get();

      final Map<String, String> farmerNames = {};
      for (final doc in farmersSnapshot.docs) {
        final data = doc.data();
        farmerNames[doc.id] = data['name'] as String? ?? 'Farmer';
      }

      final List<ProductWithSchedule> allProducts = [];
      
      for (final doc in snapshot.docs) {
        final product = ProductModel.fromFirestore(doc);
        
        // Find which schedules contain this product
        final relatedSchedules = schedules.where((schedule) {
          return schedule.products.any((p) => p.productId == product.id);
        }).toList();

        // Get farmer name from schedule or farmers collection
        String? farmerName;
        if (relatedSchedules.isNotEmpty) {
          farmerName = relatedSchedules.first.products
              .firstWhere((p) => p.productId == product.id, orElse: () => relatedSchedules.first.products.first)
              .farmerName;
        } else if (product.farmerId != null) {
          farmerName = farmerNames[product.farmerId];
        }

        // Add product with availability status
        allProducts.add(ProductWithSchedule(
          product: product,
          schedules: relatedSchedules,
          isAvailable: relatedSchedules.isNotEmpty,
          farmerName: farmerName,
        ));
      }

      yield allProducts;
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// Cart state provider
final cartProvider = StateNotifierProvider<CartNotifier, Map<String, CartItemModel>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<Map<String, CartItemModel>> {
  CartNotifier() : super({});

  void addItem(CartItemModel item) {
    state = {
      ...state,
      item.productId: item,
    };
  }

  void updateQuantity(String productId, double quantity) {
    if (quantity <= 0) {
      removeItem(productId);
      return;
    }

    final item = state[productId];
    if (item != null) {
      // For discrete units, ensure quantity is a whole number
      if (item.isDiscreteUnit) {
        quantity = quantity.roundToDouble();
      }
      state = {
        ...state,
        productId: item.copyWith(quantity: quantity),
      };
    }
  }

  void incrementQuantity(String productId) {
    final item = state[productId];
    if (item != null) {
      final newQuantity = item.quantity + item.quantityIncrement;
      updateQuantity(productId, newQuantity);
    }
  }

  void decrementQuantity(String productId) {
    final item = state[productId];
    if (item != null) {
      final newQuantity = item.quantity - item.quantityIncrement;
      updateQuantity(productId, newQuantity);
    }
  }

  void removeItem(String productId) {
    final newState = Map<String, CartItemModel>.from(state);
    newState.remove(productId);
    state = newState;
  }

  void clear() {
    state = {};
  }

  double get totalAmount {
    return state.values.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  int get itemCount => state.length;

  double get totalWeight {
    return state.values.fold(0.0, (sum, item) => sum + item.quantity);
  }
}

// Helper class to associate products with their schedules
class ProductWithSchedule {
  final ProductModel product;
  final List<OperationalScheduleModel> schedules;
  final bool isAvailable;
  final String? farmerName;

  ProductWithSchedule({
    required this.product,
    required this.schedules,
    this.isAvailable = true,
    this.farmerName,
  });

  // Get the farmer info from the first schedule, or fall back to product farmerId
  String? get farmerId {
    if (schedules.isNotEmpty) {
      return schedules.first.products
          .firstWhere((p) => p.productId == product.id, orElse: () => schedules.first.products.first)
          .farmerId;
    }
    return product.farmerId;
  }
}
