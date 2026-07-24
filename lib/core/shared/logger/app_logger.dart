import 'package:logger/logger.dart';
import 'package:f2c/core/config/app_config.dart';

class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
  );

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (AppConfig.instance.showDebugInfo) {
      _logger.d(message, error: error, stackTrace: stackTrace);
    }
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  static void warning(
    dynamic message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  static void fatal(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.f(message, error: error, stackTrace: stackTrace);
  }

  static void logAuthEvent(String event, Map<String, dynamic> data) {
    info('AUTH_EVENT: $event', data);
  }

  static void logUserAction(String action, Map<String, dynamic> data) {
    info('USER_ACTION: $action', data);
  }

  static void logApiCall(String endpoint, Map<String, dynamic> data) {
    debug('API_CALL: $endpoint', data);
  }

  static void logNavigation(String route, Map<String, dynamic>? params) {
    debug('NAVIGATION: $route', params);
  }
}
