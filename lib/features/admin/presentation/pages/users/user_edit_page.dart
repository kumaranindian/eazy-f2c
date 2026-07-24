import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:f2c/core/shared/utils/validators.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/features/authentication/models/user_model.dart';
import 'package:f2c/features/authentication/models/user_role.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';

final userDetailProvider = FutureProvider.family<UserModel, String>((ref, userId) async {
  final userRepo = ref.watch(userRepositoryProvider);
  return await userRepo.getUserById(userId);
});

class UserEditPage extends ConsumerStatefulWidget {
  const UserEditPage({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  ConsumerState<UserEditPage> createState() => _UserEditPageState();
}

class _UserEditPageState extends ConsumerState<UserEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _alternativeMobileController = TextEditingController();

  UserRole? _selectedRole;
  bool _isActive = true;
  bool _isLoading = false;
  UserModel? _originalUser;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _alternativeMobileController.dispose();
    super.dispose();
  }

  void _initializeForm(UserModel user) {
    if (_originalUser == null) {
      _originalUser = user;
      _nameController.text = user.name;
      _mobileController.text = user.mobile;
      _alternativeMobileController.text = user.alternativeMobile ?? '';
      _selectedRole = user.role;
      _isActive = user.isActive;
    }
  }

  Future<void> _handleUpdateUser() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_originalUser == null) return;

      setState(() => _isLoading = true);

      try {
        final currentUser = await ref.read(currentUserProvider.future);
        if (currentUser == null) {
          throw Exception('No current user found');
        }

        final userRepo = ref.read(userRepositoryProvider);

        final updatedUser = _originalUser!.copyWith(
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          alternativeMobile: _alternativeMobileController.text.trim().isEmpty
              ? null
              : _alternativeMobileController.text.trim(),
          role: _selectedRole!,
          isActive: _isActive,
          updatedAt: DateTime.now(),
          updatedBy: currentUser.id,
        );

        await userRepo.updateUser(updatedUser, currentUser.id);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        context.go(RouteNames.adminUsers);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userDetailProvider(widget.userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User'),
      ),
      body: userAsync.when(
        data: (user) {
          _initializeForm(user);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(user.avatarUrl),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '@${user.username}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            user.email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  DropdownButtonFormField<UserRole>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      prefixIcon: Icon(Icons.badge),
                    ),
                    items: UserRole.values.map((role) {
                      return DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      );
                    }).toList(),
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedRole = value);
                            }
                          },
                    validator: (value) =>
                        value == null ? ValidationMessages.roleRequired : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: Validators.validateName,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _mobileController,
                    decoration: const InputDecoration(
                      labelText: 'Mobile',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: Validators.validateMobile,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _alternativeMobileController,
                    decoration: const InputDecoration(
                      labelText: 'Alternative Mobile (Optional)',
                      prefixIcon: Icon(Icons.phone_android),
                    ),
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Active'),
                    subtitle: const Text('User can login'),
                    value: _isActive,
                    onChanged: _isLoading
                        ? null
                        : (value) {
                            setState(() => _isActive = value);
                          },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleUpdateUser,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Update User',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(userDetailProvider(widget.userId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
