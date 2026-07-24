import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';

abstract class FarmerDataSource {
  Stream<List<FarmerModel>> watchFarmers();
  Future<List<FarmerModel>> getFarmers();
  Future<FarmerModel> getFarmerById(String id);
  Future<String> createFarmer(FarmerModel farmer);
  Future<void> updateFarmer(String id, FarmerModel farmer);
  Future<void> deleteFarmer(String id);
  Future<Map<String, int>> getFarmerStats();
}

class FarmerDataSourceImpl implements FarmerDataSource {
  FarmerDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _farmersCollection =>
      _firestore.collection('farmers');

  @override
  Stream<List<FarmerModel>> watchFarmers() {
    try {
      return _farmersCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => FarmerModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching farmers', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch farmers',
        originalError: e,
      );
    }
  }

  @override
  Future<List<FarmerModel>> getFarmers() async {
    try {
      final snapshot = await _farmersCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => FarmerModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting farmers', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get farmers',
        originalError: e,
      );
    }
  }

  @override
  Future<FarmerModel> getFarmerById(String id) async {
    try {
      final doc = await _farmersCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Farmer not found',
          resource: 'Farmer',
        );
      }

      return FarmerModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting farmer by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createFarmer(FarmerModel farmer) async {
    try {
      final docRef = await _farmersCollection.add(farmer.toFirestore());
      AppLogger.info('Farmer created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating farmer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateFarmer(String id, FarmerModel farmer) async {
    try {
      await _farmersCollection.doc(id).update(farmer.toFirestore());
      AppLogger.info('Farmer updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating farmer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteFarmer(String id) async {
    try {
      await _farmersCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Farmer deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting farmer', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete farmer',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getFarmerStats() async {
    try {
      final snapshot = await _farmersCollection.get();

      final farmers = snapshot.docs
          .map((doc) => FarmerModel.fromFirestore(doc))
          .toList();

      final activeFarmers = farmers.where((f) => !f.isDeleted && f.isActive).toList();
      final inactiveFarmers = farmers.where((f) => !f.isDeleted && !f.isActive).toList();
      final deletedFarmers = farmers.where((f) => f.isDeleted).toList();
      
      final totalFarmers = activeFarmers.length + inactiveFarmers.length;
      final totalDeliveries = activeFarmers.fold<int>(0, (sum, f) => sum + f.totalDeliveries) +
                          inactiveFarmers.fold<int>(0, (sum, f) => sum + f.totalDeliveries);
      
      // Count unique locations
      final uniqueLocations = farmers
          .where((f) => !f.isDeleted)
          .map((f) => f.location)
          .toSet()
          .length;

      return {
        'totalFarmers': totalFarmers,
        'activeFarmers': activeFarmers.length,
        'inactiveFarmers': inactiveFarmers.length,
        'deletedFarmers': deletedFarmers.length,
        'totalDeliveries': totalDeliveries,
        'totalLocations': uniqueLocations,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting farmer stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get farmer stats',
        originalError: e,
      );
    }
  }
}
