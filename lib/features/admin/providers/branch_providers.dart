import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/branch_datasource.dart';
import 'package:f2c/features/admin/repositories/branch_repository.dart';
import 'package:f2c/features/admin/models/branch_model.dart';

// Datasource Provider
final branchDataSourceProvider = Provider<BranchDataSource>((ref) {
  return BranchDataSourceImpl(
    firestore: FirebaseFirestore.instance,
  );
});

// Repository Provider
final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepositoryImpl(
    dataSource: ref.watch(branchDataSourceProvider),
  );
});

// Watch all branches (real-time)
final branchesStreamProvider = StreamProvider<List<BranchModel>>((ref) {
  final repository = ref.watch(branchRepositoryProvider);
  return repository.watchBranches();
});

// Get branch stats
final branchStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(branchRepositoryProvider);
  return await repository.getBranchStats();
});

// Get single branch by ID
final branchByIdProvider =
    FutureProvider.family<BranchModel, String>((ref, id) async {
  final repository = ref.watch(branchRepositoryProvider);
  return await repository.getBranchById(id);
});
