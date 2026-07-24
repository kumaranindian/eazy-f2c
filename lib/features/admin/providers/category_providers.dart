import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/features/admin/datasources/category_datasource.dart';
import 'package:f2c/features/admin/repositories/category_repository.dart';
import 'package:f2c/features/admin/models/category_model.dart';

final categoryDataSourceProvider = Provider<CategoryDataSource>((ref) {
  return CategoryDataSourceImpl(firestore: FirebaseFirestore.instance);
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(
    dataSource: ref.watch(categoryDataSourceProvider),
  );
});

final categoriesStreamProvider = StreamProvider<List<CategoryModel>>((ref) {
  final repository = ref.watch(categoryRepositoryProvider);
  return repository.watchCategories();
});
