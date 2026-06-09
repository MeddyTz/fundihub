// lib/firebase_options.dart
// Firebase options generated from android/app/google-services.json for FundiHub.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: '108838349548',
    projectId: 'fundihub-2e7c0',
    authDomain: 'fundihub-2e7c0.firebaseapp.com',
    storageBucket: 'fundihub-2e7c0.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCTVon7pKEx0GuYJ2RD64yPQYDKFwh0wlI',
    appId: '1:108838349548:android:ba19db7a32c3072a8593c9',
    messagingSenderId: '108838349548',
    projectId: 'fundihub-2e7c0',
    storageBucket: 'fundihub-2e7c0.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '108838349548',
    projectId: 'fundihub-2e7c0',
    storageBucket: 'fundihub-2e7c0.firebasestorage.app',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.fundihub.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'YOUR_MACOS_API_KEY',
    appId: 'YOUR_MACOS_APP_ID',
    messagingSenderId: '108838349548',
    projectId: 'fundihub-2e7c0',
    storageBucket: 'fundihub-2e7c0.firebasestorage.app',
    iosClientId: 'YOUR_MACOS_CLIENT_ID',
    iosBundleId: 'com.fundihub.app',
  );
}
