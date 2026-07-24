import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class UserRemoteDataSource {
  Future<UserModel> getUserById(String userId);
  Future<UserModel> getUserByUsername(String username);
  Future<List<UserModel>> getAllUsers();
  Future<List<UserModel>> getUsersByRole(UserRole role);
  Future<UserModel> createUser(UserModel user, String password);
  Future<UserModel> updateUser(UserModel user);
  Future<void> deleteUser(String userId);
  Future<void> activateUser(String userId);
  Future<void> deactivateUser(String userId);
  Future<String> resetPassword(String userId, String newPassword);
  Future<bool> isUsernameAvailable(String username);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  UserRemoteDataSourceImpl({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  })  : _firestore = firestore,
        _firebaseAuth = firebaseAuth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  @override
  Future<UserModel> getUserById(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        throw const AppException.notFound(
          message: 'User not found',
          resource: 'User',
        );
      }

      return UserModel.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Get user by ID error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get user',
        originalError: e,
      );
    }
  }

  @override
  Future<UserModel> getUserByUsername(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        throw const AppException.notFound(
          message: 'User not found',
          resource: 'User',
        );
      }

      final doc = query.docs.first;
      return UserModel.fromJson({
        'id': doc.id,
        ...doc.data(),
      });
    } catch (e, stackTrace) {
      AppLogger.error('Get user by username error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to get user',
        originalError: e,
      );
    }
  }

  @override
  Future<List<UserModel>> getAllUsers() async {
    try {
      final query = await _firestore
          .collection('users')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        return UserModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Get all users error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get users',
        originalError: e,
      );
    }
  }

  @override
  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('role', isEqualTo: role.name)
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .get();

      return query.docs.map((doc) {
        return UserModel.fromJson({
          'id': doc.id,
          ...doc.data(),
        });
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Get users by role error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to get users',
        originalError: e,
      );
    }
  }

  @override
  Future<UserModel> createUser(UserModel user, String password) async {
    try {
      final isAvailable = await isUsernameAvailable(user.username);
      if (!isAvailable) {
        throw const AppException.validation(
          message: 'Username already exists',
          fieldErrors: {'username': 'Username already exists'},
        );
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: user.email,
        password: password,
      );

      if (userCredential.user == null) {
        throw const AppException.server(
          message: 'Failed to create user in Firebase Auth',
        );
      }

      final userData = {
        'name': user.name,
        'username': user.username.toLowerCase(),
        'email': user.email,
        'mobile': user.mobile,
        'role': user.role.name,
        'branchId': user.branchId,
        'hubId': user.hubId,
        'profileImage': user.profileImage,
        'isActive': user.isActive,
        'isDeleted': false,
        'passwordChanged': false,
        'lastLogin': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdBy': user.createdBy,
        'updatedBy': user.updatedBy,
      };

      final docRef = await _firestore.collection('users').add(userData);

      final doc = await docRef.get();

      AppLogger.info('User created successfully: ${user.username}');

      return UserModel.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Create user Firebase Auth error', e);
      throw AppException.server(
        message: _getAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Create user error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to create user',
        originalError: e,
      );
    }
  }

  @override
  Future<UserModel> updateUser(UserModel user) async {
    try {
      final updateData = {
        'name': user.name,
        'mobile': user.mobile,
        'role': user.role.name,
        'branchId': user.branchId,
        'hubId': user.hubId,
        'profileImage': user.profileImage,
        'isActive': user.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.updatedBy,
      };

      await _firestore.collection('users').doc(user.id).update(updateData);

      final doc = await _firestore.collection('users').doc(user.id).get();

      AppLogger.info('User updated successfully: ${user.id}');

      return UserModel.fromJson({
        'id': doc.id,
        ...doc.data()!,
      });
    } catch (e, stackTrace) {
      AppLogger.error('Update user error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to update user',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('User deleted (soft): $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Delete user error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to delete user',
        originalError: e,
      );
    }
  }

  @override
  Future<void> activateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('User activated: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Activate user error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to activate user',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deactivateUser(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('User deactivated: $userId');
    } catch (e, stackTrace) {
      AppLogger.error('Deactivate user error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to deactivate user',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('username', isEqualTo: username.toLowerCase())
          .limit(1)
          .get();

      return query.docs.isEmpty;
    } catch (e, stackTrace) {
      AppLogger.error('Check username availability error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to check username availability',
        originalError: e,
      );
    }
  }

  @override
  Future<String> resetPassword(String userId, String newPassword) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) {
        throw const AppException.notFound(
          message: 'User not found',
          resource: 'User',
        );
      }

      // Note: Firebase client SDK doesn't support admin password reset
      // In production, this should trigger a Cloud Function
      // For now, we'll just mark the user as needing password change
      
      await _firestore.collection('users').doc(userId).update({
        'passwordChanged': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Password reset requested for user: $userId');

      return newPassword;
    } catch (e, stackTrace) {
      AppLogger.error('Reset password error', e, stackTrace);
      if (e is AppException) rethrow;
      throw AppException.unknown(
        message: 'Failed to reset password',
        originalError: e,
      );
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Email already in use';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'Failed to create user';
    }
  }
}
