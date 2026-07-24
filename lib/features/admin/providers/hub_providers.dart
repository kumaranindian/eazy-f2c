import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/hub_datasource.dart';
import 'package:f2c/features/admin/repositories/hub_repository.dart';
import 'package:f2c/features/admin/models/hub_model.dart';

final hubDataSourceProvider = Provider<HubDataSource>((ref) {
  return HubDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final hubRepositoryProvider = Provider<HubRepository>((ref) {
  return HubRepositoryImpl(dataSource: ref.watch(hubDataSourceProvider));
});

final hubsStreamProvider = StreamProvider<List<HubModel>>((ref) {
  final repository = ref.watch(hubRepositoryProvider);
  return repository.watchHubs();
});

final hubStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(hubRepositoryProvider);
  return await repository.getHubStats();
});
