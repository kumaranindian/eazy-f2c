import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:f2c/features/authentication/datasources/auth_remote_datasource.dart';
import 'package:f2c/features/authentication/datasources/user_remote_datasource.dart';
import 'package:f2c/features/authentication/datasources/session_local_datasource.dart';
import 'package:f2c/features/authentication/datasources/audit_log_datasource.dart';
import 'package:f2c/features/authentication/repositories/auth_repository.dart';
import 'package:f2c/features/authentication/repositories/user_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden');
});

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSourceImpl(
    firebaseAuth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
  );
});

final userRemoteDataSourceProvider = Provider<UserRemoteDataSource>((ref) {
  return UserRemoteDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
  );
});

final sessionLocalDataSourceProvider = Provider<SessionLocalDataSource>((ref) {
  return SessionLocalDataSourceImpl(
    sharedPreferences: ref.watch(sharedPreferencesProvider),
  );
});

final auditLogDataSourceProvider = Provider<AuditLogDataSource>((ref) {
  return AuditLogDataSourceImpl(
    firestore: ref.watch(firestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
    localDataSource: ref.watch(sessionLocalDataSourceProvider),
    auditLogDataSource: ref.watch(auditLogDataSourceProvider),
  );
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(
    remoteDataSource: ref.watch(userRemoteDataSourceProvider),
    auditLogDataSource: ref.watch(auditLogDataSourceProvider),
  );
});

final currentSessionProvider = FutureProvider((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return await authRepo.getCurrentSession();
});

final currentUserProvider = FutureProvider((ref) async {
  final session = await ref.watch(currentSessionProvider.future);
  if (session == null) return null;
  
  final userRepo = ref.watch(userRepositoryProvider);
  return await userRepo.getUserById(session.uid);
});
