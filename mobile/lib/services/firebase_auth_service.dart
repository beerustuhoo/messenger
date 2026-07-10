import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseAuthService {
  static bool _ready = false;
  static String? _lastInitError;

  static bool get isEnabled => _ready;
  static String? get lastInitError => _lastInitError;

  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Future<bool> initialize() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      _lastInitError = 'Firebase config missing in this build';
      debugPrint('Firebase: not configured (missing FIREBASE_API_KEY / FIREBASE_PROJECT_ID)');
      return false;
    }

    final attempts = kIsWeb ? 3 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
              .timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw TimeoutException('Firebase SDK load timed out'),
          );
        }
        _ready = true;
        _lastInitError = null;
        debugPrint('Firebase Auth enabled');
        return true;
      } catch (e) {
        _lastInitError = e.toString();
        debugPrint('Firebase init failed (attempt ${attempt + 1}/$attempts): $e');
        if (attempt < attempts - 1) {
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
    }
    return false;
  }

  static Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = auth.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  static String mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email already in use';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'unauthorized-domain':
        return 'This site is not authorized in Firebase. Add mobile-messenger-i7id.onrender.com under Authentication → Authorized domains.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  static String? fieldForError(FirebaseAuthException e) {
    if (e.code == 'email-already-in-use') return 'email';
    return null;
  }
}
