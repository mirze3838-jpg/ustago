// File generated for UstaGo Firebase Configuration.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return android; // Android fallback
      default:
        return android;
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB0HnbuqWkmKlXw6mzGX4qM0wNya2i2LXI',
    appId: '1:628924933222:android:efed49421a574832a9f9a7',
    messagingSenderId: '628924933222',
    projectId: 'ustago-6a961',
    storageBucket: 'ustago-6a961.firebasestorage.app',
  );
}
