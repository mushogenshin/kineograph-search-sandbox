// New for the search sandbox. Replaces the production public-profile
// page. The sandbox stub exists only to confirm that the search-result
// tap delivered the right `user_profiles/{uid}` document path.

import 'package:flutter/material.dart';

/// Sandbox-only stub. Shows the matched profile UID, whether it's an
/// Official Account, and the inferred Firestore path.
class UserProfileStub extends StatelessWidget {
  final String uid;
  final String displayName;
  final bool isOfficialAccount;

  const UserProfileStub({
    super.key,
    required this.uid,
    required this.displayName,
    this.isOfficialAccount = false,
  });

  String get _firestorePath =>
      isOfficialAccount ? 'oa_profiles/$uid' : 'user_profiles/$uid';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User profile (stub)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
              label: 'Collection',
              value:
                  isOfficialAccount ? 'oa_profiles' : 'user_profiles',
            ),
            _Row(label: 'UID', value: uid),
            _Row(label: 'Display name', value: displayName),
            _Row(label: 'Official?', value: '$isOfficialAccount'),
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
