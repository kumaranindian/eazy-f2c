import 'package:flutter/material.dart';
import 'package:f2c/core/config/app_config.dart';
import 'package:f2c/core/config/app_environment.dart';

class EnvironmentBadge extends StatelessWidget {
  const EnvironmentBadge({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.instance.environment.showEnvironmentBadge) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    switch (AppConfig.instance.environment) {
      case AppEnvironment.development:
        badgeColor = Colors.blue;
        break;
      case AppEnvironment.testing:
        badgeColor = Colors.orange;
        break;
      case AppEnvironment.uat:
        badgeColor = Colors.purple;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Chip(
      label: Text(
        AppConfig.instance.environmentName.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: badgeColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
