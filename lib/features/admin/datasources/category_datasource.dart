import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/category_model.dart';

abstract class CategoryDataSource {
  Stream<List<CategoryModel>> watchCategories();
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel> getCategoryById(String id);
  Future<String> createCategory(CategoryModel category);
  Future<void> updateCategory(String id, CategoryModel category);
  Future<void> deleteCategory(String id);
}

class CategoryDataSourceImpl implements CategoryDataSource {
  CategoryDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _categoriesCollection =>
      _firestore.collection('categories');

  @override
  Stream<List<CategoryModel>> watchCategories() {
    try {
      return _categoriesCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => CategoryModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching categories', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch categories',
        originalError: e,
      );
    }
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    try {
      final snapshot = await _categoriesCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting categories', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get categories',
        originalError: e,
      );
    }
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    try {
      final doc = await _categoriesCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Category not found',
          resource: 'Category',
        );
      }

      return CategoryModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting category by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get category',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createCategory(CategoryModel category) async {
    try {
      final docRef = await _categoriesCollection.add(category.toFirestore());
      AppLogger.info('Category created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating category', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create category',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateCategory(String id, CategoryModel category) async {
    try {
      await _categoriesCollection.doc(id).update(category.toFirestore());
      AppLogger.info('Category updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating category', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update category',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    try {
      await _categoriesCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Category deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting category', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete category',
        originalError: e,
      );
    }
  }
}
