import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/category_datasource.dart';
import 'package:f2c/features/admin/models/category_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class CategoryRepository {
  Stream<List<CategoryModel>> watchCategories();
  Future<List<CategoryModel>> getCategories();
  Future<CategoryModel> getCategoryById(String id);
  Future<String> createCategory(CategoryModel category, String userId, UserRole userRole);
  Future<void> updateCategory(String id, CategoryModel category, String userId, UserRole userRole);
  Future<void> deleteCategory(String id, String userId, UserRole userRole);
}

class CategoryRepositoryImpl implements CategoryRepository {
  CategoryRepositoryImpl({
    required CategoryDataSource dataSource,
  }) : _dataSource = dataSource;

  final CategoryDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage categories',
      );
    }
  }

  @override
  Stream<List<CategoryModel>> watchCategories() {
    return _dataSource.watchCategories();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    return await _dataSource.getCategories();
  }

  @override
  Future<CategoryModel> getCategoryById(String id) async {
    return await _dataSource.getCategoryById(id);
  }

  @override
  Future<String> createCategory(
    CategoryModel category,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final categoryId = await _dataSource.createCategory(category);
      AppLogger.info('Category created successfully: $categoryId by user: $userId');
      return categoryId;
    } catch (e, stackTrace) {
      AppLogger.error('Create category error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create category',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateCategory(
    String id,
    CategoryModel category,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateCategory(id, category);
      AppLogger.info('Category updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update category error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update category',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteCategory(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteCategory(id);
      AppLogger.info('Category deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete category error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete category',
        originalError: e,
      );
    }
  }
}
