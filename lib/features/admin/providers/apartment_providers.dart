import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/apartment_datasource.dart';
import 'package:f2c/features/admin/repositories/apartment_repository.dart';
import 'package:f2c/features/admin/models/apartment_model.dart';

final apartmentDataSourceProvider = Provider<ApartmentDataSource>((ref) {
  return ApartmentDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final apartmentRepositoryProvider = Provider<ApartmentRepository>((ref) {
  return ApartmentRepositoryImpl(dataSource: ref.watch(apartmentDataSourceProvider));
});

final apartmentsStreamProvider = StreamProvider<List<ApartmentModel>>((ref) {
  final repository = ref.watch(apartmentRepositoryProvider);
  return repository.watchApartments();
});

final apartmentStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(apartmentRepositoryProvider);
  return await repository.getApartmentStats();
});
