import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/branch_model.dart';

abstract class BranchDataSource {
  Stream<List<BranchModel>> watchBranches();
  Future<List<BranchModel>> getBranches();
  Future<BranchModel> getBranchById(String id);
  Future<String> createBranch(BranchModel branch);
  Future<void> updateBranch(String id, BranchModel branch);
  Future<void> deleteBranch(String id);
  Future<Map<String, int>> getBranchStats();
}

class BranchDataSourceImpl implements BranchDataSource {
  BranchDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _branchesCollection =>
      _firestore.collection('branches');

  @override
  Stream<List<BranchModel>> watchBranches() {
    try {
      // Show all branches including deleted ones
      return _branchesCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => BranchModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching branches', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch branches',
        originalError: e,
      );
    }
  }

  @override
  Future<List<BranchModel>> getBranches() async {
    try {
      final snapshot = await _branchesCollection
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BranchModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting branches', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get branches',
        originalError: e,
      );
    }
  }

  @override
  Future<BranchModel> getBranchById(String id) async {
    try {
      final doc = await _branchesCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Branch not found',
          resource: 'Branch',
        );
      }

      return BranchModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting branch by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get branch',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createBranch(BranchModel branch) async {
    try {
      final docRef = await _branchesCollection.add(branch.toFirestore());
      AppLogger.info('Branch created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating branch', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create branch',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateBranch(String id, BranchModel branch) async {
    try {
      await _branchesCollection.doc(id).update(branch.toFirestore());
      AppLogger.info('Branch updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating branch', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update branch',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteBranch(String id) async {
    try {
      await _branchesCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Branch deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting branch', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete branch',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getBranchStats() async {
    try {
      final snapshot = await _branchesCollection.get();

      final branches = snapshot.docs
          .map((doc) => BranchModel.fromFirestore(doc))
          .toList();

      final activeBranches = branches.where((b) => !b.isDeleted && b.isActive).toList();
      final inactiveBranches = branches.where((b) => !b.isDeleted && !b.isActive).toList();
      final deletedBranches = branches.where((b) => b.isDeleted).toList();
      
      final totalBranches = activeBranches.length + inactiveBranches.length;
      final totalHubs = activeBranches.fold<int>(0, (sum, b) => sum + b.hubCount) +
                        inactiveBranches.fold<int>(0, (sum, b) => sum + b.hubCount);

      return {
        'totalBranches': totalBranches,
        'activeBranches': activeBranches.length,
        'inactiveBranches': inactiveBranches.length,
        'deletedBranches': deletedBranches.length,
        'totalHubs': totalHubs,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting branch stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get branch stats',
        originalError: e,
      );
    }
  }
}
