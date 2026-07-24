import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:f2c/core/config/app_config.dart';
import 'package:f2c/core/config/app_environment.dart';
import 'package:f2c/core/config/firebase/firebase_options_test.dart';
import 'package:f2c/core/shared/logger/app_logger.dart';
import 'package:f2c/features/authentication/providers/auth_providers.dart';
import 'package:f2c/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  setPathUrlStrategy();

  AppConfig.initialize(
    environment: AppEnvironment.testing,
    appName: 'F2C Test',
    appVersion: '1.0.0',
    buildNumber: '1',
  );

  AppLogger.info('Initializing F2C Testing Environment');

  try {
    // Initialize SharedPreferences for web
    final sharedPreferences = await SharedPreferences.getInstance();
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    AppLogger.info('Firebase initialized successfully');

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const F2CApp(),
      ),
    );
  } catch (e, stackTrace) {
    AppLogger.error('Failed to initialize Firebase', e, stackTrace);
    rethrow;
  }
}
