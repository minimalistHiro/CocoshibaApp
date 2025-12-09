// File generated manually based on Firebase console configuration.
// Mirrors the structure produced by `flutterfire configure`.

import 'package:firebase_core/firebase_core.dart'
    show FirebaseOptions;
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
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCcrYyh4HB9yjiLaaSWhwlmYdtHywNlZc8',
    appId: '1:618793511488:web:8b94886a37ebeb39520da5',
    messagingSenderId: '618793511488',
    projectId: 'cocoshibaapp',
    storageBucket: 'cocoshibaapp.firebasestorage.app',
    authDomain: 'cocoshibaapp.firebaseapp.com',
    measurementId: 'G-D2G572D4NH',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7RYxgZLOaTab0nKw42PPmHZ5yir9h-UQ',
    appId: '1:618793511488:android:bdb6738ff2be7526520da5',
    messagingSenderId: '618793511488',
    projectId: 'cocoshibaapp',
    storageBucket: 'cocoshibaapp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCWceB7aYFEzOJPyV4nhn8WmD6P3qxSIz4',
    appId: '1:618793511488:ios:2ef5a5ea1963acba520da5',
    messagingSenderId: '618793511488',
    projectId: 'cocoshibaapp',
    storageBucket: 'cocoshibaapp.firebasestorage.app',
    iosBundleId: 'com.groumap.cocoshiba',
  );
}
