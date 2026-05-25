// New for the search sandbox. The production app uses a generated
// firebase_options.dart (via `flutterfire configure`) and a custom
// FirebaseService singleton with App Check, persistence tuning, and
// emulator wiring. The sandbox keeps it to one function so the
// collaborator can swap in her own platform config later.

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Whether the sandbox should connect to the local Firebase emulator
/// suite rather than the production Firebase project.
///
/// Toggle with `--dart-define=USE_FIREBASE_EMULATOR=true` (any non-empty
/// value other than "false" / "0" enables it). When enabled, Firestore
/// and Auth route to `localhost` at the ports declared in `firebase.json`.
bool get _useEmulator {
  const raw =
      String.fromEnvironment('USE_FIREBASE_EMULATOR', defaultValue: '');
  if (raw.isEmpty) return false;
  return raw.toLowerCase() != 'false' && raw != '0';
}

/// Initializes Firebase Core and (when configured) routes Firestore +
/// Auth at the local emulator suite.
///
/// Call once during app startup, before `runApp`. Safe to call multiple
/// times — `Firebase.initializeApp` is idempotent.
///
/// **Platform notes:**
/// - On Android/iOS, `Firebase.initializeApp()` (no `options`) picks up
///   the platform-specific config bundle (`google-services.json` /
///   `GoogleService-Info.plist`). The collaborator must add those before
///   running on those platforms.
/// - On macOS, Windows, web, or Linux, the platform config is read from
///   a generated `firebase_options.dart` passed to `initializeApp(options:
///   DefaultFirebaseOptions.currentPlatform)`. The sandbox does NOT
///   include a generated `firebase_options.dart`. Run `flutterfire
///   configure` locally to generate one (it's gitignored) and update the
///   call site in `main.dart` if you want to target those platforms.
/// True once [initFirebase] has completed successfully — used by the
/// auth and Firestore-read code paths to short-circuit when Firebase
/// isn't actually wired up (collaborator hasn't run `flutterfire configure`
/// yet, or is running on macOS / Windows / web before the platform
/// config has been generated).
bool get firebaseAvailable => _firebaseInitialized;
bool _firebaseInitialized = false;

Future<void> initFirebase() async {
  try {
    await Firebase.initializeApp();
    _firebaseInitialized = true;
  } catch (e) {
    // Most likely cause: no platform config (google-services.json /
    // GoogleService-Info.plist / generated firebase_options.dart). The
    // sandbox keeps running so the collaborator can still hit Typesense
    // directly — search doesn't depend on Firebase. The result-tile
    // navigation paths show the routing payload from the Typesense hit
    // without making the Firestore round-trip the production app does.
    debugPrint(
      'Firebase: initialization failed ($e). '
      'Continuing without Firebase — Firestore reads and anonymous '
      'auth will be skipped. Run `flutterfire configure` to wire it up.',
    );
    return;
  }

  if (_useEmulator) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    debugPrint('Firebase: connected to local emulators');
  }
}
