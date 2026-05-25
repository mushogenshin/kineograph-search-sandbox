// New for the search sandbox. Replaces the production ArticleScreen
// (which renders blocks, scrubbers, comments, vote affordances, etc.).
// The sandbox stub exists only to confirm that the search-result tap
// successfully delivered the right Firestore-path coordinates.

import 'package:flutter/material.dart';

/// Sandbox-only stub. Displays the routing payload from a search-result
/// tap and a back button. No Firestore round-trip.
class ArticleDetailStub extends StatelessWidget {
  final String docId;
  final String disciplineId;
  final String title;

  const ArticleDetailStub({
    super.key,
    required this.docId,
    required this.disciplineId,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Article (stub)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(label: 'Collection', value: 'articles'),
            _Row(label: 'Discipline', value: disciplineId),
            _Row(label: 'docId', value: docId),
            _Row(label: 'Title', value: title),
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
