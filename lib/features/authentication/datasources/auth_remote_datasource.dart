import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> loginWithUsername(String username, String password);
  Future<void> logout();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<String> resetPassword(String userId, String newPassword);
  Future<User?> getCurrentFirebaseUser();
  Future<String?> getIdToken();
  Future<void> refreshToken();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  })  : _firebaseAuth = firebaseAuth,
        _firestore = firestore;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  @override
  Future<UserModel> loginWithUsername(String username, String password) async {
    try {
      AppLogger.info('Attempting login for username: $username');

      // Check if input is an email or username
      final isEmail = username.contains('@');
      
      QuerySnapshot userQuery;
      if (isEmail) {
        // Search by email
        userQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();
      } else {
        // Search by username
        userQuery = await _firestore
            .collection('users')
            .where('username', isEqualTo: username.toLowerCase())
            .limit(1)
            .get();
      }

      if (userQuery.docs.isEmpty) {
        throw const AppException.authentication(
          message: 'Invalid username or password',
        );
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data() as Map<String, dynamic>;
      final email = userData['email'] as String;

      AppLogger.debug('Found user with email: $email');

      AppLogger.debug('Attempting Firebase Auth sign-in...');
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.debug('Firebase Auth sign-in successful');

      if (userCredential.user == null) {
        throw const AppException.authentication(
          message: 'Authentication failed',
        );
      }

      AppLogger.debug('Creating user model from data...');
      final userModel = UserModel.fromJson({
        'id': userDoc.id,
        ...userData,
      });

      if (!userModel.canLogin) {
        await _firebaseAuth.signOut();
        if (userModel.isDeleted) {
          throw const AppException.userDeleted(
            message: 'Your account has been deleted',
          );
        }
        if (!userModel.isActive) {
          throw const AppException.userInactive(
            message: 'Your account is inactive. Contact administrator.',
          );
        }
      }

      // TODO: Fix Firestore rules for lastLogin update
      // AppLogger.debug('Updating lastLogin timestamp...');
      // await _firestore.collection('users').doc(userDoc.id).update({
      //   'lastLogin': FieldValue.serverTimestamp(),
      // });
      // AppLogger.debug('lastLogin updated successfully');

      AppLogger.info('Login successful for user: ${userModel.username}');

      return userModel;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Firebase Auth Error', e);
      throw AppException.authentication(
        message: _getAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    } on AppException {
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error('Login error', e, stackTrace);
      throw AppException.unknown(
        message: 'An error occurred during login',
        originalError: e,
      );
    }
  }

  @override
  Future<void> logout() async {
    try {
      AppLogger.info('Logging out user');
      await _firebaseAuth.signOut();
    } catch (e, stackTrace) {
      AppLogger.error('Logout error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to logout',
        originalError: e,
      );
    }
  }

  @override
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AppException.authentication(
          message: 'No user logged in',
        );
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        await _firestore.collection('users').doc(userQuery.docs.first.id).update({
          'passwordChanged': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      AppLogger.info('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Change password error', e);
      throw AppException.authentication(
        message: _getAuthErrorMessage(e.code),
        code: e.code,
        originalError: e,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Change password error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to change password',
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

      final userData = userDoc.data()!;
      final email = userData['email'] as String;

      final tempPassword = _generateTemporaryPassword();

      // Note: Firebase client SDK doesn't support admin operations
      // In production, this should trigger a Cloud Function to reset password
      // For now, we'll just mark the user as needing password change
      
      await _firestore.collection('users').doc(userId).update({
        'passwordChanged': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.info('Password reset requested for user: $userId');

      return tempPassword;
    } catch (e, stackTrace) {
      AppLogger.error('Reset password error', e, stackTrace);
      throw AppException.unknown(
        message: 'Failed to reset password',
        originalError: e,
      );
    }
  }

  @override
  Future<User?> getCurrentFirebaseUser() async {
    return _firebaseAuth.currentUser;
  }

  @override
  Future<String?> getIdToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  @override
  Future<void> refreshToken() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.getIdToken(true);
    }
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid username or password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      case 'weak-password':
        return 'Password is too weak';
      case 'requires-recent-login':
        return 'Please login again to perform this action';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  String _generateTemporaryPassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(12, (index) => chars[(random + index) % chars.length]).join();
  }
}
