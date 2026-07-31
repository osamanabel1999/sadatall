import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Fetches a Firebase custom token from the backend (POST
/// /api/auth/firebase-token, requires the mode's own JWT bearer header) and
/// signs into Firebase Auth with it. Each mode wires [fetchCustomToken] to
/// its own Dio/ApiClient instance since the shared chat module doesn't know
/// about any mode's network stack.
///
/// Needed because Firestore security rules key off `request.auth.uid`, and
/// this app's real auth is a custom JWT with no `firebase_auth` sign-in of
/// its own until this bridge runs.
class ChatAuthService {
  static Future<bool> signIn(Future<String?> Function() fetchCustomToken) async {
    try {
      final token = await fetchCustomToken();
      if (token == null) return false;
      await FirebaseAuth.instance.signInWithCustomToken(token);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('ChatAuthService.signIn failed: $e');
      return false;
    }
  }

  static Future<void> signOut() async {
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {}
  }

  static bool get isSignedIn => FirebaseAuth.instance.currentUser != null;
}
