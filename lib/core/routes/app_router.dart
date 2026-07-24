import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/authentication/providers/system_setup_provider.dart';
import 'package:f2c/features/authentication/presentation/pages/login_page.dart';
import 'package:f2c/features/authentication/presentation/pages/change_password_page.dart';
import 'package:f2c/features/authentication/presentation/pages/splash_page.dart';
import 'package:f2c/features/authentication/presentation/pages/first_user_setup_page.dart';
import 'package:f2c/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:f2c/features/admin/presentation/pages/users/users_list_page.dart';
import 'package:f2c/features/admin/presentation/pages/users/user_create_page.dart';
import 'package:f2c/features/admin/presentation/pages/users/user_edit_page.dart';
import 'package:f2c/features/admin/presentation/pages/branches/branches_list_page.dart';
import 'package:f2c/features/customer/presentation/pages/customer_dashboard_page.dart';
import 'package:f2c/features/packaging/presentation/pages/packaging_dashboard_page.dart';
import 'package:f2c/features/delivery/presentation/pages/delivery_dashboard_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionAsync = ref.watch(currentSessionProvider);
  final needsSetupAsync = ref.watch(systemSetupCheckProvider);

  return GoRouter(
    initialLocation: RouteNames.splash,
    redirect: (context, state) {
      // Don't redirect while loading session
      if (sessionAsync.isLoading || needsSetupAsync.isLoading) {
        return null;
      }

      final session = sessionAsync.valueOrNull;
      final needsSetup = needsSetupAsync.valueOrNull ?? false;
      final isLoggedIn = session != null;
      final isLoginPage = state.matchedLocation == RouteNames.login;
      final isSplashPage = state.matchedLocation == RouteNames.splash;
      final isSetupPage = state.matchedLocation == RouteNames.firstUserSetup;

      if (needsSetup && !isSetupPage && !isSplashPage) {
        return RouteNames.firstUserSetup;
      }

      if (!needsSetup && isSetupPage) {
        return RouteNames.login;
      }

      if (!isLoggedIn && !isLoginPage && !isSplashPage && !isSetupPage) {
        return RouteNames.login;
      }

      if (isLoggedIn && (isLoginPage || isSplashPage || isSetupPage)) {
        return session.role.dashboardRoute;
      }

      if (isLoggedIn) {
        final currentPath = state.matchedLocation;
        if (!_isAuthorized(currentPath, session.role)) {
          return session.role.dashboardRoute;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: RouteNames.firstUserSetup,
        builder: (context, state) => const FirstUserSetupPage(),
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RouteNames.changePassword,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const AdminDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.adminUsers,
        builder: (context, state) => const UsersListPage(),
      ),
      GoRoute(
        path: RouteNames.adminUserCreate,
        builder: (context, state) => const UserCreatePage(),
      ),
      GoRoute(
        path: '${RouteNames.adminUserEdit}/:userId',
        builder: (context, state) {
          final userId = state.pathParameters['userId']!;
          return UserEditPage(userId: userId);
        },
      ),
      GoRoute(
        path: RouteNames.adminBranches,
        builder: (context, state) => const BranchesListPage(),
      ),
      GoRoute(
        path: RouteNames.customerDashboard,
        builder: (context, state) => const CustomerDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.packagingDashboard,
        builder: (context, state) => const PackagingDashboardPage(),
      ),
      GoRoute(
        path: RouteNames.deliveryDashboard,
        builder: (context, state) => const DeliveryDashboardPage(),
      ),
    ],
  );
});

bool _isAuthorized(String path, UserRole role) {
  if (path.startsWith('/admin')) {
    return role == UserRole.superAdmin || role == UserRole.admin;
  }
  if (path.startsWith('/customer')) {
    return role == UserRole.customer;
  }
  if (path.startsWith('/packaging')) {
    return role == UserRole.packaging;
  }
  if (path.startsWith('/delivery')) {
    return role == UserRole.delivery;
  }
  return true;
}
