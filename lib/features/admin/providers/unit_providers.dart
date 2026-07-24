import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/unit_datasource.dart';
import 'package:f2c/features/admin/repositories/unit_repository.dart';
import 'package:f2c/features/admin/models/unit_model.dart';

final unitDataSourceProvider = Provider<UnitDataSource>((ref) {
  return UnitDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final unitRepositoryProvider = Provider<UnitRepository>((ref) {
  return UnitRepositoryImpl(
    dataSource: ref.watch(unitDataSourceProvider),
  );
});

final unitsStreamProvider = StreamProvider<List<UnitModel>>((ref) {
  final repository = ref.watch(unitRepositoryProvider);
  return repository.watchUnits();
});

final unitStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(unitRepositoryProvider);
  return await repository.getUnitStats();
});
