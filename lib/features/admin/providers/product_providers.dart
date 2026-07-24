import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/product_datasource.dart';
import 'package:f2c/features/admin/repositories/product_repository.dart';
import 'package:f2c/features/admin/models/product_model.dart';

final productDataSourceProvider = Provider<ProductDataSource>((ref) {
  return ProductDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    dataSource: ref.watch(productDataSourceProvider),
  );
});

final productsStreamProvider = StreamProvider<List<ProductModel>>((ref) {
  final repository = ref.watch(productRepositoryProvider);
  return repository.watchProducts();
});

final productStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repository = ref.watch(productRepositoryProvider);
  return await repository.getProductStats();
});

final displayNamesProvider = FutureProvider<List<String>>((ref) async {
  final firestore = FirebaseFirestore.instance;
  final snapshot = await firestore
      .collection('products')
      .where('isDeleted', isEqualTo: false)
      .get();
  
  final displayNames = snapshot.docs
      .map((doc) => doc.data()['displayName'] as String? ?? '')
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList();
  
  displayNames.sort();
  return displayNames;
});
