import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD0YIxzBkKpt68yU3ZHe0ZguSqhWNqFbO4',
    appId: '1:477936445339:web:413daa1c6d6cf1d731633e',
    messagingSenderId: '477936445339',
    projectId: 'verifyglobally',
    authDomain: 'verifyglobally.firebaseapp.com',
    storageBucket: 'verifyglobally.firebasestorage.app',
  );

  // Temporary same values for now (enough for Chrome testing)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD0YIxzBkKpt68yU3ZHe0ZguSqhWNqFbO4',
    appId: '1:477936445339:web:413daa1c6d6cf1d731633e',
    messagingSenderId: '477936445339',
    projectId: 'verifyglobally',
    authDomain: 'verifyglobally.firebaseapp.com',
    storageBucket: 'verifyglobally.firebasestorage.app',
    iosBundleId: 'com.verifyglobally.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD0YIxzBkKpt68yU3ZHe0ZguSqhWNqFbO4',
    appId: '1:477936445339:web:413daa1c6d6cf1d731633e',
    messagingSenderId: '477936445339',
    projectId: 'verifyglobally',
    authDomain: 'verifyglobally.firebaseapp.com',
    storageBucket: 'verifyglobally.firebasestorage.app',
  );
}