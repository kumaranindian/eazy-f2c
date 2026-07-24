enum AppEnvironment {
  development('dev', 'Development', 'f2c-dev'),
  testing('test', 'Testing', 'f2c-test'),
  uat('uat', 'UAT', 'f2c-uat'),
  production('prod', 'Production', 'f2c-prod');

  const AppEnvironment(this.value, this.displayName, this.firebaseProjectId);

  final String value;
  final String displayName;
  final String firebaseProjectId;

  bool get isDevelopment => this == AppEnvironment.development;
  bool get isTesting => this == AppEnvironment.testing;
  bool get isUat => this == AppEnvironment.uat;
  bool get isProduction => this == AppEnvironment.production;

  bool get showEnvironmentBadge => !isProduction;
}
