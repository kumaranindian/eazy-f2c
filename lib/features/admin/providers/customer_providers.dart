import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/customer_datasource.dart';
import 'package:f2c/features/admin/repositories/customer_repository.dart';
import 'package:f2c/features/admin/models/customer_model.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/authentication/repositories/user_repository.dart';

final customerDataSourceProvider = Provider<CustomerDataSource>((ref) {
  return CustomerDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepositoryImpl(
    dataSource: ref.watch(customerDataSourceProvider),
    userRepository: ref.watch(userRepositoryProvider),
  );
});

final customersStreamProvider = StreamProvider<List<CustomerModel>>((ref) {
  final repository = ref.watch(customerRepositoryProvider);
  return repository.watchCustomers();
});

final customerStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(customerRepositoryProvider);
  return await repository.getCustomerStats();
});
