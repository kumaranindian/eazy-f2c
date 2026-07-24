import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/admin/models/product_model.dart';

abstract class ProductDataSource {
  Stream<List<ProductModel>> watchProducts();
  Future<List<ProductModel>> getProducts();
  Future<ProductModel> getProductById(String id);
  Future<String> createProduct(ProductModel product);
  Future<void> updateProduct(String id, ProductModel product);
  Future<void> deleteProduct(String id);
  Future<Map<String, int>> getProductStats();
}

class ProductDataSourceImpl implements ProductDataSource {
  ProductDataSourceImpl({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _productsCollection =>
      _firestore.collection('products');

  @override
  Stream<List<ProductModel>> watchProducts() {
    try {
      return _productsCollection
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ProductModel.fromFirestore(doc))
              .toList());
    } catch (e, stackTrace) {
      AppLogger.error('Error watching products', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to watch products',
        originalError: e,
      );
    }
  }

  @override
  Future<List<ProductModel>> getProducts() async {
    try {
      final snapshot = await _productsCollection
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error('Error getting products', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get products',
        originalError: e,
      );
    }
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    try {
      final doc = await _productsCollection.doc(id).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'Product not found',
          resource: 'Product',
        );
      }

      return ProductModel.fromFirestore(doc);
    } catch (e, stackTrace) {
      AppLogger.error('Error getting product by id', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get product',
        originalError: e,
      );
    }
  }

  @override
  Future<String> createProduct(ProductModel product) async {
    try {
      final docRef = await _productsCollection.add(product.toFirestore());
      AppLogger.info('Product created: ${docRef.id}');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Error creating product', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to create product',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateProduct(String id, ProductModel product) async {
    try {
      await _productsCollection.doc(id).update(product.toFirestore());
      AppLogger.info('Product updated: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error updating product', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update product',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    try {
      await _productsCollection.doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('Product deleted: $id');
    } catch (e, stackTrace) {
      AppLogger.error('Error deleting product', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete product',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, int>> getProductStats() async {
    try {
      final snapshot = await _productsCollection.get();

      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc))
          .toList();

      final activeProducts = products.where((p) => !p.isDeleted && p.isActive).toList();
      final inactiveProducts = products.where((p) => !p.isDeleted && !p.isActive).toList();
      final deletedProducts = products.where((p) => p.isDeleted).toList();
      
      final totalProducts = activeProducts.length + inactiveProducts.length;
      final totalStock = activeProducts.fold<int>(0, (sum, p) => sum + p.stockQuantity) +
                          inactiveProducts.fold<int>(0, (sum, p) => sum + p.stockQuantity);
      
      // Count unique categories
      final uniqueCategories = products
          .where((p) => !p.isDeleted)
          .map((p) => p.category)
          .toSet()
          .length;

      return {
        'totalProducts': totalProducts,
        'activeProducts': activeProducts.length,
        'inactiveProducts': inactiveProducts.length,
        'deletedProducts': deletedProducts.length,
        'totalStock': totalStock,
        'totalCategories': uniqueCategories,
      };
    } catch (e, stackTrace) {
      AppLogger.error('Error getting product stats', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get product stats',
        originalError: e,
      );
    }
  }
}
