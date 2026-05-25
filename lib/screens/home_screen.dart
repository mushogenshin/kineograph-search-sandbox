// New for the search sandbox. The production home shell is a heavy
// scaffold (welcome screen, group hubs, Steam-vs-mobile branching,
// theme switcher, deep-link landing flows). The sandbox home is a
// single button: open the search.

import 'package:flutter/material.dart';

import 'package:kineograph_search_sandbox/screens/search_screen.dart';
import 'package:kineograph_search_sandbox/services/search/typesense_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isReady = TypesenseService().isAvailable;
    return Scaffold(
      appBar: AppBar(title: const Text('Kineograph Search Sandbox')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReady ? Icons.search : Icons.warning_amber_rounded,
                size: 64,
                color: isReady
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                isReady
                    ? 'Typesense client initialized.'
                    : 'Typesense is not configured.\n'
                        'Pass --dart-define=TYPESENSE_HOST=… '
                        'and --dart-define=TYPESENSE_API_KEY=… '
                        'on the next run.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => showSearch<void>(
                  context: context,
                  delegate: SandboxSearchDelegate(),
                ),
                icon: const Icon(Icons.search),
                label: const Text('Open Search'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
