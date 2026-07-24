import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/customer_model.dart';

abstract class CustomerDataSource {
  Stream<List<CustomerModel>> watchCustomers();
  Future<List<CustomerModel>> getCustomers();
  Future<CustomerModel> getCustomerById(String id);
  Future<String> createCustomer(CustomerModel customer);
  Future<void> updateCustomer(String id, CustomerModel customer);
  Future<void> deleteCustomer(String id);
  Future<Map<String, int>> getCustomerStats();
}

class CustomerDataSourceImpl implements CustomerDataSource {
  CustomerDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _customersCollection =>
      _firestore.collection('customers');

  @override
  Stream<List<CustomerModel>> watchCustomers() {
    try {
      return _customersCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => CustomerModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching customers', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch customers',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final snapshot = await _customersCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting customers', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get customers',
        originalError: e,
      );
    }
  }

  @override
  Future<CustomerModel> getCustomerById(String id) async {
    try {
      final doc = await _customersCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Customer not found',
          resource: 'Customer',
        );
      }

      return CustomerModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting customer by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get customer',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createCustomer(CustomerModel customer) async {
    try {
      final docRef = await _customersCollection.add(customer.toFirestore());
      AppLogger.info('Customer created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating customer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create customer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateCustomer(String id, CustomerModel customer) async {
    try {
      await _customersCollection.doc(id).update(customer.toFirestore());
      AppLogger.info('Customer updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating customer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update customer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteCustomer(String id) async {
    try {
      await _customersCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Customer deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting customer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete customer',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getCustomerStats() async {
    try {
      final snapshot = await _customersCollection.get();

      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc))
          .toList();

      final activeCustomers = customers.where((c) => !c.isDeleted && c.isActive).toList();
      final inactiveCustomers = customers.where((c) => !c.isDeleted && !c.isActive).toList();
      final deletedCustomers = customers.where((c) => c.isDeleted).toList();
      
      final totalCustomers = activeCustomers.length + inactiveCustomers.length;
      final totalOrders = activeCustomers.fold<int>(0, (sum, c) => sum + c.totalOrders) +
                          inactiveCustomers.fold<int>(0, (sum, c) => sum + c.totalOrders);
      
      // Count unique apartments
      final uniqueApartments = customers
          .where((c) => !c.isDeleted)
          .map((c) => c.apartmentId)
          .toSet()
          .length;

      return {
        'totalCustomers': totalCustomers,
        'activeCustomers': activeCustomers.length,
        'inactiveCustomers': inactiveCustomers.length,
        'deletedCustomers': deletedCustomers.length,
        'totalOrders': totalOrders,
        'totalApartments': uniqueApartments,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting customer stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get customer stats',
        originalError: e,
      );
    }
  }
}
