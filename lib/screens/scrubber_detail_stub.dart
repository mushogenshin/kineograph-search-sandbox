// New for the search sandbox. Replaces the production scrubber player
// surface. The sandbox stub exists only to confirm that the search-
// result tap delivered the right Firestore-path coordinates.

import 'package:flutter/material.dart';

/// Sandbox-only stub. Shows the Typesense collection name (which
/// determines whether the scrubber is library / user-authored) and the
/// computed Firestore path.
class ScrubberDetailStub extends StatelessWidget {
  final String docId;
  final String collection;
  final String authorUid;
  final String title;

  const ScrubberDetailStub({
    super.key,
    required this.docId,
    required this.collection,
    required this.authorUid,
    required this.title,
  });

  String get _firestorePath => collection == 'scrubbers_library'
      ? 'library_scrubbers/$docId'
      : 'users/$authorUid/scrubbers/$docId';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scrubber (stub)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: 'Typesense', value: collection),
            _Row(label: 'docId', value: docId),
            _Row(label: 'Author UID', value: authorUid),
            _Row(label: 'Title', value: title),
            const Divider(height: 32),
            _Row(label: 'Firestore', value: _firestorePath),
            const SizedBox(height: 24),
            Text(
              'Navigation OK.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value.isEmpty ? '<empty>' : value)),
        ],
      ),
    );
  }
}
