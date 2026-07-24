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
    apiKey: 'YOUR_UAT_WEB_API_KEY',
    appId: 'YOUR_UAT_WEB_APP_ID',
    messagingSenderId: 'YOUR_UAT_MESSAGING_SENDER_ID',
    projectId: 'f2c-uat',
    authDomain: 'f2c-uat.firebaseapp.com',
    storageBucket: 'f2c-uat.appspot.com',
    measurementId: 'YOUR_UAT_MEASUREMENT_ID',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_UAT_ANDROID_API_KEY',
    appId: 'YOUR_UAT_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_UAT_MESSAGING_SENDER_ID',
    projectId: 'f2c-uat',
    storageBucket: 'f2c-uat.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_UAT_IOS_API_KEY',
    appId: 'YOUR_UAT_IOS_APP_ID',
    messagingSenderId: 'YOUR_UAT_MESSAGING_SENDER_ID',
    projectId: 'f2c-uat',
    storageBucket: 'f2c-uat.appspot.com',
    iosBundleId: 'com.f2c.uat',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_UAT_MACOS_API_KEY',
    appId: 'YOUR_UAT_MACOS_APP_ID',
    messagingSenderId: 'YOUR_UAT_MESSAGING_SENDER_ID',
    projectId: 'f2c-uat',
    storageBucket: 'f2c-uat.appspot.com',
    iosBundleId: 'com.f2c.uat',
  );
}
