import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/datasources/product_datasource.dart';
import 'package:f2c/features/admin/models/product_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class ProductRepository {
  Stream<List<ProductModel>> watchProducts();
  Future<List<ProductModel>> getProducts();
  Future<ProductModel> getProductById(String id);
  Future<String> createProduct(ProductModel product, String userId, UserRole userRole);
  Future<void> updateProduct(String id, ProductModel product, String userId, UserRole userRole);
  Future<void> deleteProduct(String id, String userId, UserRole userRole);
  Future<void> restoreProduct(String id, String userId, UserRole userRole);
  Future<Map<String, int>> getProductStats();
}

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required ProductDataSource dataSource,
  }) : _dataSource = dataSource;

  final ProductDataSource _dataSource;

  void _validateAdminPermission(UserRole userRole) {
    if (userRole != UserRole.admin && userRole != UserRole.superAdmin) {
      throw const AppException.authorization(
        message: 'Only admins can manage products',
      );
    }
  }

  @override
  Stream<List<ProductModel>> watchProducts() {
    return _dataSource.watchProducts();
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    return await _dataSource.getProducts();
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    return await _dataSource.getProductById(id);
  }

  @override
  Future<String> createProduct(
    ProductModel product,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final productId = await _dataSource.createProduct(product);
      AppLogger.info('Product created successfully: $productId by user: $userId');
      return productId;
    } catch (e, stackTrace) {
      AppLogger.error('Create product error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create product',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateProduct(
    String id,
    ProductModel product,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.updateProduct(id, product);
      AppLogger.info('Product updated successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Update product error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to update product',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteProduct(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      await _dataSource.deleteProduct(id);
      AppLogger.info('Product deleted successfully: $id by user: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete product error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to delete product',
        originalError: e,
      );
    }
  }

  @override
  Future<void> restoreProduct(
    String id,
    String userId,
    UserRole userRole,
  ) async {
    try {
      _validateAdminPermission(userRole);

      final product = await _dataSource.getProductById(id);
      final restoredProduct = product.copyWith(
        isDeleted: false,
        updatedAt: DateTime.now(),
        updatedBy: userId,
      );

      await _dataSource.updateProduct(id, restoredProduct);
      AppLogger.info('Product restored successfully: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Restore product error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to restore product',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getProductStats() async {
    return await _dataSource.getProductStats();
  }
}
