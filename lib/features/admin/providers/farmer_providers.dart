import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/farmer_datasource.dart';
import 'package:f2c/features/admin/repositories/farmer_repository.dart';
import 'package:f2c/features/admin/models/farmer_model.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/authentication/repositories/user_repository.dart';

final farmerDataSourceProvider = Provider<FarmerDataSource>((ref) {
  return FarmerDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final farmerRepositoryProvider = Provider<FarmerRepository>((ref) {
  return FarmerRepositoryImpl(
    dataSource: ref.watch(farmerDataSourceProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

final farmersStreamProvider = StreamProvider<List<FarmerModel>>((ref) {
  final repository = ref.watch(farmerRepositoryProvider);
  return repository.watchFarmers();
});

final farmerStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(farmerRepositoryProvider);
  return await repository.getFarmerStats();
});
