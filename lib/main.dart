// New for the search sandbox. Production main.dart wires up everything:
// mascots, theme persistence, R2 image service, IAP, ads init, Steam,
// connectivity, offline DB, deep-link handlers, etc. The sandbox boots
// the bare minimum: Firebase + anonymous auth + Typesense client.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kineograph_search_sandbox/app.dart';
import 'package:kineograph_search_sandbox/services/auth_service.dart';
import 'package:kineograph_search_sandbox/services/firebase_init.dart';
import 'package:kineograph_search_sandbox/services/search/typesense_service.dart';

/// Sandbox entry point.
///
/// Order matters: Firebase Core must initialize before any Firestore /
/// Auth call site. Anonymous sign-in is fire-and-forget — the search UI
/// doesn't actually depend on auth state, but production-equivalent
/// Firestore rules will reject reads otherwise. Typesense init is
/// synchronous (no network).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initFirebase();

  // Fire-and-forget: don't block UI startup on auth, but kick it off
  // immediately so by the time the user opens search, the Firestore
  // navigation step on result tap (which the production search uses)
  // has a valid UID to send.
  unawaited(signInAnonymouslyIfNeeded());

  TypesenseService().init();

  runApp(const SandboxApp());
}
