// New for the search sandbox. The production AuthService handles
// Google / Apple / Steam / Discord / GitHub providers, account linking,
// merge flows, and a custom auth state ValueNotifier. The sandbox only
// signs in anonymously — enough for Firestore security rules that
// require `request.auth != null`.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:kineograph_search_sandbox/services/firebase_init.dart';

/// Best-effort anonymous sign-in.
///
/// Production Firestore security rules typically require a non-null
/// `request.auth` even for read-only paths. Signing in anonymously
/// gives the sandbox an Auth UID without bringing in any of the
/// real auth providers.
///
/// Skipped silently when Firebase isn't initialized (e.g. the collaborator
/// hasn't run `flutterfire configure` yet). Other failures are logged
/// but not surfaced — the rest of the app should still launch so the
/// collaborator can hit Typesense directly.
Future<void> signInAnonymouslyIfNeeded() async {
  if (!firebaseAvailable) {
    debugPrint('Auth: skipping (Firebase not initialized)');
    return;
  }
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
