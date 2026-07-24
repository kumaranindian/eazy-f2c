import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/apartment_model.dart';

abstract class ApartmentDataSource {
  Stream<List<ApartmentModel>> watchApartments();
  Future<List<ApartmentModel>> getApartments();
  Future<ApartmentModel> getApartmentById(String id);
  Future<String> createApartment(ApartmentModel apartment);
  Future<void> updateApartment(String id, ApartmentModel apartment);
  Future<void> deleteApartment(String id);
  Future<Map<String, int>> getApartmentStats();
}

class ApartmentDataSourceImpl implements ApartmentDataSource {
  ApartmentDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _apartmentsCollection =>
      _firestore.collection('apartments');

  @override
  Stream<List<ApartmentModel>> watchApartments() {
    try {
      return _apartmentsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ApartmentModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching apartments', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch apartments',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ApartmentModel>> getApartments() async {
    try {
      final snapshot = await _apartmentsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ApartmentModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting apartments', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get apartments',
        originalError: e,
      );
    }
  }

  @override
  Future<ApartmentModel> getApartmentById(String id) async {
    try {
      final doc = await _apartmentsCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Apartment not found',
          resource: 'Apartment',
        );
      }

      return ApartmentModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting apartment by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createApartment(ApartmentModel apartment) async {
    try {
      final docRef = await _apartmentsCollection.add(apartment.toFirestore());
      AppLogger.info('Apartment created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating apartment', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateApartment(String id, ApartmentModel apartment) async {
    try {
      await _apartmentsCollection.doc(id).update(apartment.toFirestore());
      AppLogger.info('Apartment updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating apartment', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteApartment(String id) async {
    try {
      await _apartmentsCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Apartment deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting apartment', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete apartment',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getApartmentStats() async {
    try {
      final snapshot = await _apartmentsCollection.get();

      final apartments = snapshot.docs
          .map((doc) => ApartmentModel.fromFirestore(doc))
          .toList();

      final activeApartments = apartments.where((a) => !a.isDeleted && a.isActive).toList();
      final inactiveApartments = apartments.where((a) => !a.isDeleted && !a.isActive).toList();
      final deletedApartments = apartments.where((a) => a.isDeleted).toList();
      
      final totalApartments = activeApartments.length + inactiveApartments.length;
      final totalCustomers = activeApartments.fold<int>(0, (sum, a) => sum + a.totalCustomers) +
                             inactiveApartments.fold<int>(0, (sum, a) => sum + a.totalCustomers);
      
      // Count unique hubs
      final uniqueHubs = apartments
          .where((a) => !a.isDeleted)
          .map((a) => a.hubId)
          .toSet()
          .length;

      return {
        'totalApartments': totalApartments,
        'activeApartments': activeApartments.length,
        'inactiveApartments': inactiveApartments.length,
        'deletedApartments': deletedApartments.length,
        'totalCustomers': totalCustomers,
        'totalHubs': uniqueHubs,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting apartment stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get apartment stats',
        originalError: e,
      );
    }
  }
}
