import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:f2c/core/config/app_config.dart';
import 'package:f2c/core/constants/app_constants.dart';
import 'package:f2c/core/widgets/f2c_logo.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/features/authentication/providers/system_setup_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    
    // Scale animation for logo
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    
    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    
    // Rotate animation for loading indicator
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _rotateAnimation = CurvedAnimation(
      parent: _rotateController,
      curve: Curves.easeInOut,
    );
    
    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _rotateController.repeat(reverse: true);
    });
    
    _checkSession();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }


  Future<void> _checkSession() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final needsSetup = await ref.read(systemSetupCheckProvider.future);

    if (!mounted) return;

    if (needsSetup) {
      context.go(RouteNames.firstUserSetup);
      return;
    }

    final session = await ref.read(currentSessionProvider.future);

    if (!mounted) return;

    if (session != null) {
      context.go(session.role.dashboardRoute);
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC), // Beige background like in the image
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated F2C Logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const ClipOval(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: F2CLogo(
                      size: 160,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Animated App Name
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                AppConstants.appFullName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E7D32), // Dark green
                      letterSpacing: 1.2,
                    ),
              ),
            ),
            const SizedBox(height: 48),
            // Animated Loading Indicator
            RotationTransition(
              turns: _rotateAnimation,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF4CAF50),
                    width: 3,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.eco,
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Version Text
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Version ${AppConfig.instance.fullVersion}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
            if (AppConfig.instance.environment.showEnvironmentBadge) ...[
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Chip(
                  label: Text(AppConfig.instance.environmentName),
                  backgroundColor: Colors.orange,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
