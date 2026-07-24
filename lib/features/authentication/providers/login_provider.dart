import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/core/exceptions/app_exception.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/models/login_request.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(
    authRepository: ref.watch(authRepositoryProvider),
  );
});

class LoginNotifier extends StateNotifier<LoginState> {
  LoginNotifier({
    required this.authRepository,
  }) : super(const LoginState.initial());

  final authRepository;

  Future<void> login(LoginRequest request) async {
    state = const LoginState.loading();

    try {
      AppLogger.info('Login started for: ${request.username}');
      
      final user = await authRepository.login(request);
      
      state = LoginState.success(user);
      
      AppLogger.info('Login completed successfully');
    } on AppException catch (e) {
      AppLogger.error('Login failed', e);
      state = LoginState.error(e.when(
        network: (message, code, originalError) => message,
        authentication: (message, code, originalError) => message,
        authorization: (message, code, originalError) => message,
        validation: (message, fieldErrors) => message,
        notFound: (message, resource) => message,
        server: (message, code, originalError) => message,
        unknown: (message, originalError) => message,
        userInactive: (message) => message,
        userDeleted: (message) => message,
        passwordChangeRequired: (message) => message,
      ));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected login error', e, stackTrace);
      state = const LoginState.error('An unexpected error occurred');
    }
  }

  void reset() {
    state = const LoginState.initial();
  }
}

sealed class LoginState {
  const LoginState();

  const factory LoginState.initial() = LoginInitial;
  const factory LoginState.loading() = LoginLoading;
  const factory LoginState.success(UserModel user) = LoginSuccess;
  const factory LoginState.error(String message) = LoginError;
}

class LoginInitial extends LoginState {
  const LoginInitial();
}

class LoginLoading extends LoginState {
  const LoginLoading();
}

class LoginSuccess extends LoginState {
  const LoginSuccess(this.user);
  final UserModel user;
}

class LoginError extends LoginState {
  const LoginError(this.message);
  final String message;
}
