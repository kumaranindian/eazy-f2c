import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'This app is configured for web only.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyArjT7aqptS8pH14JGuJDBnNGPh8b4Pczs',
    appId: '1:453142868625:web:7d9cd09bd8f78025d10530',
    messagingSenderId: '453142868625',
    projectId: 'f2c-dev-ddd82',
    authDomain: 'f2c-dev-ddd82.firebaseapp.com',
    storageBucket: 'f2c-dev-ddd82.firebasestorage.app',
    measurementId: 'G-0XMLPK6YK4',
  );
}
