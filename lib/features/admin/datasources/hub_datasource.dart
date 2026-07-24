import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/hub_model.dart';

abstract class HubDataSource {
  Stream<List<HubModel>> watchHubs();
  Future<List<HubModel>> getHubs();
  Future<HubModel> getHubById(String id);
  Future<String> createHub(HubModel hub);
  Future<void> updateHub(String id, HubModel hub);
  Future<void> deleteHub(String id);
  Future<Map<String, int>> getHubStats();
}

class HubDataSourceImpl implements HubDataSource {
  HubDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _hubsCollection =>
      _firestore.collection('hubs');

  @override
  Stream<List<HubModel>> watchHubs() {
    try {
      return _hubsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => HubModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching hubs', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch hubs',
        originalError: e,
      );
    }
  }

  @override
  Future<List<HubModel>> getHubs() async {
    try {
      final snapshot = await _hubsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => HubModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting hubs', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get hubs',
        originalError: e,
      );
    }
  }

  @override
  Future<HubModel> getHubById(String id) async {
    try {
      final doc = await _hubsCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Hub not found',
          resource: 'Hub',
        );
      }

      return HubModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting hub by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get hub',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createHub(HubModel hub) async {
    try {
      final docRef = await _hubsCollection.add(hub.toFirestore());
      AppLogger.info('Hub created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating hub', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create hub',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateHub(String id, HubModel hub) async {
    try {
      await _hubsCollection.doc(id).update(hub.toFirestore());
      AppLogger.info('Hub updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating hub', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update hub',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteHub(String id) async {
    try {
      await _hubsCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Hub deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting hub', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete hub',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getHubStats() async {
    try {
      final snapshot = await _hubsCollection.get();

      final hubs = snapshot.docs
          .map((doc) => HubModel.fromFirestore(doc))
          .toList();

      final activeHubs = hubs.where((h) => !h.isDeleted && h.isActive).toList();
      final inactiveHubs = hubs.where((h) => !h.isDeleted && !h.isActive).toList();
      final deletedHubs = hubs.where((h) => h.isDeleted).toList();
      
      final totalHubs = activeHubs.length + inactiveHubs.length;
      final totalApartments = activeHubs.fold<int>(0, (sum, h) => sum + h.apartmentCount) +
                              inactiveHubs.fold<int>(0, (sum, h) => sum + h.apartmentCount);
      
      // Count unique branches
      final uniqueBranches = hubs
          .where((h) => !h.isDeleted)
          .map((h) => h.branchId)
          .toSet()
          .length;

      return {
        'totalHubs': totalHubs,
        'activeHubs': activeHubs.length,
        'inactiveHubs': inactiveHubs.length,
        'deletedHubs': deletedHubs.length,
        'totalApartments': totalApartments,
        'totalBranches': uniqueBranches,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting hub stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get hub stats',
        originalError: e,
      );
    }
  }
}
