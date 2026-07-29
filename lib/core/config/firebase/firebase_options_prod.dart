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
    apiKey: 'AIzaSyB5HsIGJZru40ZQiGqRuIqZe1TBUMsSaqE',
    appId: '1:626500381981:web:923df2b9be6cdb737905f4',
    messagingSenderId: '626500381981',
    projectId: 'f2c-prod',
    authDomain: 'f2c-prod.firebaseapp.com',
    storageBucket: 'f2c-prod.firebasestorage.app',
    measurementId: 'G-450108YH53',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_PROD_ANDROID_API_KEY',
    appId: 'YOUR_PROD_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_PROD_MESSAGING_SENDER_ID',
    projectId: 'f2c-prod',
    storageBucket: 'f2c-prod.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_PROD_IOS_API_KEY',
    appId: 'YOUR_PROD_IOS_APP_ID',
    messagingSenderId: 'YOUR_PROD_MESSAGING_SENDER_ID',
    projectId: 'f2c-prod',
    storageBucket: 'f2c-prod.appspot.com',
    iosBundleId: 'com.f2c.prod',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_PROD_MACOS_API_KEY',
    appId: 'YOUR_PROD_MACOS_APP_ID',
    messagingSenderId: 'YOUR_PROD_MESSAGING_SENDER_ID',
    projectId: 'f2c-prod',
    storageBucket: 'f2c-prod.appspot.com',
    iosBundleId: 'com.f2c.prod',
  );
}
