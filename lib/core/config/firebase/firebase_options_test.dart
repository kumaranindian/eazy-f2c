import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDgaXhypcfptN06zHdCl9g5b2F6q9B5dn4',
    appId: '1:461138846295:web:a743571030cf2294847912',
    messagingSenderId: '461138846295',
    projectId: 'f2c-test',
    authDomain: 'f2c-test.firebaseapp.com',
    storageBucket: 'f2c-test.firebasestorage.app',
    measurementId: 'G-W9NGJW4YKJ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_TEST_ANDROID_API_KEY',
    appId: 'YOUR_TEST_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_TEST_MESSAGING_SENDER_ID',
    projectId: 'f2c-test',
    storageBucket: 'f2c-test.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_TEST_IOS_API_KEY',
    appId: 'YOUR_TEST_IOS_APP_ID',
    messagingSenderId: 'YOUR_TEST_MESSAGING_SENDER_ID',
    projectId: 'f2c-test',
    storageBucket: 'f2c-test.appspot.com',
    iosBundleId: 'com.f2c.test',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_TEST_MACOS_API_KEY',
    appId: 'YOUR_TEST_MACOS_APP_ID',
    messagingSenderId: 'YOUR_TEST_MESSAGING_SENDER_ID',
    projectId: 'f2c-test',
    storageBucket: 'f2c-test.appspot.com',
    iosBundleId: 'com.f2c.test',
  );
}
