import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/operational_schedule_datasource.dart';
import 'package:f2c/features/admin/repositories/operational_schedule_repository.dart';
import 'package:f2c/features/admin/models/operational_schedule_model.dart';

final operationalScheduleDataSourceProvider = Provider<OperationalScheduleDataSource>((ref) {
  return OperationalScheduleDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final operationalScheduleRepositoryProvider = Provider<OperationalScheduleRepository>((ref) {
  return OperationalScheduleRepositoryImpl(
    dataSource: ref.watch(operationalScheduleDataSourceProvider),
  );
});

final schedulesStreamProvider = StreamProvider<List<OperationalScheduleModel>>((ref) {
  final repository = ref.watch(operationalScheduleRepositoryProvider);
  return repository.watchSchedules();
});

final scheduleStatsProvider = StreamProvider<Map<String, int>>((ref) async* {
  final repository = ref.watch(operationalScheduleRepositoryProvider);
  // Stream stats whenever schedules change
  yield await repository.getScheduleStats();
  // Listen to schedule changes and update stats
  await for (final _ in repository.watchSchedules()) {
    yield await repository.getScheduleStats();
  }
});

final schedulesByDateProvider = FutureProvider.family<List<OperationalScheduleModel>, DateTime>((ref, date) async {
  final repository = ref.watch(operationalScheduleRepositoryProvider);
  return await repository.getSchedulesByDate(date);
});
