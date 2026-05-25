// New for the search sandbox. The production AuthService handles
// Google / Apple / Steam / Discord / GitHub providers, account linking,
// merge flows, and a custom auth state ValueNotifier. The sandbox only
// signs in anonymously — enough for Firestore security rules that
// require `request.auth != null`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Best-effort anonymous sign-in.
///
/// Production Firestore security rules typically require a non-null
/// `request.auth` even for read-only paths. Signing in anonymously
/// gives the sandbox an Auth UID without bringing in any of the
/// real auth providers.
///
/// Failures are logged but not surfaced — the rest of the app should
/// still launch so the collaborator can at least see the search screen
/// and any error toast on the first Firestore round-trip.
Future<void> signInAnonymouslyIfNeeded() async {
  final auth = FirebaseAuth.instance;
  if (auth.currentUser != null) {
    debugPrint('Auth: already signed in (uid=${auth.currentUser!.uid})');
    return;
  }
  try {
    final cred = await auth.signInAnonymously();
    debugPrint('Auth: signed in anonymously (uid=${cred.user?.uid})');
  } catch (e) {
    debugPrint('Auth: anonymous sign-in failed: $e');
  }
}
