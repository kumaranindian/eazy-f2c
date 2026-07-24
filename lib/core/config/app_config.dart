import 'package:f2c/core/config/app_environment.dart';

class AppConfig {
  AppConfig._({
    required this.environment,
    required this.appName,
    required this.appVersion,
    required this.buildNumber,
  });

  static AppConfig? _instance;

  final AppEnvironment environment;
  final String appName;
  final String appVersion;
  final String buildNumber;

  static AppConfig get instance {
    if (_instance == null) {
      throw Exception(
        'AppConfig not initialized. Call AppConfig.initialize() first.',
      );
    }
    return _instance!;
  }

  static void initialize({
    required AppEnvironment environment,
    required String appName,
    required String appVersion,
    required String buildNumber,
  }) {
    _instance = AppConfig._(
      environment: environment,
      appName: appName,
      appVersion: appVersion,
      buildNumber: buildNumber,
    );
  }

  String get fullVersion => '$appVersion+$buildNumber';

  String get environmentName => environment.displayName;

  bool get isProduction => environment.isProduction;

  bool get showDebugInfo => !isProduction;
}
