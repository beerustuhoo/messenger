import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase config for project `web-messenger-bbc0f`.
/// Override any value at build time via `--dart-define=FIREBASE_*=...`.
/// See FIREBASE_SETUP.md
class DefaultFirebaseOptions {
  static const String _apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyBq_3CTXsoIwyl_oVh1MgwpnKSA9KHq8nQ',
  );
  static const String _appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:174243186861:web:3274cd9d46eaa582f51e24',
  );
  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
    defaultValue: 'AIzaSyACgXVAmDuNcXsku_7YCSqj5x3q6UoTxCc',
  );
  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
    defaultValue: '1:174243186861:android:0f7c3ce874ae4cf3f51e24',
  );
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '174243186861',
  );
  static const String _projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'web-messenger-bbc0f',
  );
  static const String _authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'web-messenger-bbc0f.firebaseapp.com',
  );
  static const String _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'web-messenger-bbc0f.firebasestorage.app',
  );

  static bool get isConfigured => _apiKey.isNotEmpty && _projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _messagingSenderId,
        projectId: _projectId,
        authDomain: _authDomain,
        storageBucket: _storageBucket,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return FirebaseOptions(
          apiKey: _androidApiKey,
          appId: _androidAppId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
        );
      case TargetPlatform.iOS:
        return FirebaseOptions(
          apiKey: _apiKey,
          appId: _iosAppId.isNotEmpty ? _iosAppId : _appId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
          storageBucket: _storageBucket,
          iosBundleId: 'com.mobilemessenger.mobile',
        );
      default:
        return const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _messagingSenderId,
          projectId: _projectId,
        );
    }
  }
}
