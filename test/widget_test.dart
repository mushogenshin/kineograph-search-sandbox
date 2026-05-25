// Minimal smoke test for the search sandbox. Avoids Firebase + Typesense
// network dependencies — those are exercised by hand against the live
// cluster, not in CI.

import 'package:flutter_test/flutter_test.dart';

import 'package:kineograph_search_sandbox/screens/search_screen.dart';

void main() {
  test('SandboxSearchDelegate instantiates cleanly', () {
    final delegate = SandboxSearchDelegate();
    expect(delegate.query, isEmpty);
  });
}
