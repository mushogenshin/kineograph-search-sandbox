// New for the search sandbox. Production uses go_router with deep-link
// handling, a custom theme system (vanilla / atelier), localization,
// SwipeBack gestures, and the OverlayToast service. The sandbox uses
// stock Material 3 with a plain Navigator — the route surface is small
// enough (home + search + 3 stubs) that go_router isn't worth the
// dependency.

import 'package:flutter/material.dart';

import 'package:kineograph_search_sandbox/screens/home_screen.dart';

/// Root widget. Stock Material 3, anonymous-only auth elsewhere.
class SandboxApp extends StatelessWidget {
  const SandboxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kineograph Search Sandbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
