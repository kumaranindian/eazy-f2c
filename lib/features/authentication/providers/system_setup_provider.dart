import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

final systemSetupCheckProvider = FutureProvider<bool>((ref) async {
  final firestore = ref.watch(firestoreProvider);
  
  try {
    final usersQuery = await firestore
        .collection('users')
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .get();
    
    final hasUsers = usersQuery.docs.isNotEmpty;
    AppLogger.info('System setup check: hasUsers=$hasUsers, needsSetup=${!hasUsers}');
    return !hasUsers; // Returns true if no users exist (needs setup)
  } catch (e, stackTrace) {
    AppLogger.error('System setup check error', e, stackTrace);
    // If there's an error checking, assume setup is needed (safer default)
    return true;
  }
});

final firstUserSetupProvider = StateNotifierProvider<FirstUserSetupNotifier, FirstUserSetupState>((ref) {
  return FirstUserSetupNotifier(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
  );
});

class FirstUserSetupNotifier extends StateNotifier<FirstUserSetupState> {
  FirstUserSetupNotifier({
    required FirebaseFirestore firestore,
    required FirebaseAuth firebaseAuth,
  })  : _firestore = firestore,
        _firebaseAuth = firebaseAuth,
        super(const FirstUserSetupState.initial());

  final FirebaseFirestore _firestore;
  final FirebaseAuth _firebaseAuth;

  Future<void> createFirstUser({
    required String name,
    required String username,
    required String email,
    required String password,
    String mobile = '0000000000',
  }) async {
    state = const FirstUserSetupState.loading();

    try {
      AppLogger.info('Creating first admin user: $username');

      final usersQuery = await _firestore
          .collection('users')
          .where('isDeleted', isEqualTo: false)
          .limit(1)
          .get();

      if (usersQuery.docs.isNotEmpty) {
        state = const FirstUserSetupState.error('System already has users. Please use the login page.');
        return;
      }

      UserCredential? userCredential;
      try {
        userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        AppLogger.info('Firebase Auth user created: ${userCredential.user?.uid}');
      } catch (e) {
        AppLogger.error('Failed to create Firebase Auth user', e);
        state = FirstUserSetupState.error('Failed to create authentication user: ${e.toString()}');
        return;
      }

      try {
        final userId = userCredential.user!.uid;
        final userData = {
          'name': name,
          'username': username.toLowerCase(),
          'email': email,
          'mobile': mobile,
          'role': 'superAdmin',
          'branchId': null,
          'hubId': null,
          'profileImage': null,
          'isActive': true,
          'isDeleted': false,
          'passwordChanged': true,
          'lastLogin': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'createdBy': 'System Setup',
          'updatedBy': 'System Setup',
        };

        await _firestore.collection('users').doc(userId).set(userData);
        AppLogger.info('Firestore super admin user document created: $userId');
      } catch (e) {
        AppLogger.error('Failed to create Firestore user document', e);
        
        if (userCredential?.user != null) {
          AppLogger.info('Cleaning up Firebase Auth user...');
          await userCredential!.user!.delete();
        }
        state = FirstUserSetupState.error('Failed to create user profile: ${e.toString()}');
        return;
      }

      try {
        await _firestore.collection('system').doc('configuration').set({
          'initialized': true,
          'initializedAt': FieldValue.serverTimestamp(),
          'initializedBy': 'System Setup',
          'version': '1.0.0',
          'environment': 'dev',
        });
        AppLogger.info('System configuration created');
      } catch (e) {
        AppLogger.error('Failed to create system configuration', e);
      }

      try {
        final logId = DateTime.now().millisecondsSinceEpoch.toString();
        await _firestore.collection('auditLogs').doc(logId).set({
          'id': logId,
          'action': 'userCreated',
          'performedBy': 'System Setup',
          'performedFor': userCredential.user?.uid,
          'timestamp': FieldValue.serverTimestamp(),
          'device': 'Web Browser',
          'ipAddress': null,
          'environment': 'dev',
          'metadata': {
            'username': username,
            'role': 'admin',
            'email': email,
          },
          'description': 'First admin user created via system setup',
        });
        AppLogger.info('Audit log created');
      } catch (e) {
        AppLogger.error('Failed to create audit log', e);
      }

      AppLogger.info('First user setup completed successfully');
      state = const FirstUserSetupState.success();
    } catch (e, stackTrace) {
      AppLogger.error('First user setup error', e, stackTrace);
      state = FirstUserSetupState.error('Setup failed: ${e.toString()}');
    }
  }

  void reset() {
    state = const FirstUserSetupState.initial();
  }
}

sealed class FirstUserSetupState {
  const FirstUserSetupState();

  const factory FirstUserSetupState.initial() = FirstUserSetupInitial;
  const factory FirstUserSetupState.loading() = FirstUserSetupLoading;
  const factory FirstUserSetupState.success() = FirstUserSetupSuccess;
  const factory FirstUserSetupState.error(String message) = FirstUserSetupError;
}

class FirstUserSetupInitial extends FirstUserSetupState {
  const FirstUserSetupInitial();
}

class FirstUserSetupLoading extends FirstUserSetupState {
  const FirstUserSetupLoading();
}

class FirstUserSetupSuccess extends FirstUserSetupState {
  const FirstUserSetupSuccess();
}

class FirstUserSetupError extends FirstUserSetupState {
  const FirstUserSetupError(this.message);
  final String message;
}
