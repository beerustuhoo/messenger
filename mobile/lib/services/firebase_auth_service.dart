import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

class FirebaseAuthService {
  static bool _ready = false;

  static bool get isEnabled => _ready;

  static FirebaseAuth get auth => FirebaseAuth.instance;

  static Future<bool> initialize() async {
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint('Firebase: not configured (missing FIREBASE_API_KEY / FIREBASE_PROJECT_ID)');
      return false;
    }
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _ready = true;
      debugPrint('Firebase Auth enabled');
      return true;
    } catch (e) {
      debugPrint('Firebase init failed: $e');
      return false;
    }
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
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  static String? fieldForError(FirebaseAuthException e) {
    if (e.code == 'email-already-in-use') return 'email';
    return null;
  }
}
