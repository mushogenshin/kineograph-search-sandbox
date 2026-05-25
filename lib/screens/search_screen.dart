// Carved from musculature/lib/article/search.dart for the search sandbox.
// Production CustomSearchDelegate has three paths: client-side substring
// fallback over an in-memory ArticleData list, Typesense scoped by
// discipline / facet filter, and global Typesense multi-search. The
// sandbox keeps only the global path:
//
//   - No client-side fallback (no in-memory article list).
//   - No discipline / facet scoping (no hub-card surface in the sandbox).
//   - Result tap navigates to a sandbox stub screen, not the production
//     scrubber / article reader.
//
// Debounce, dedup, section grouping, locale-aware query_by, and tile
// shape are preserved verbatim.

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:kineograph_search_sandbox/screens/article_detail_stub.dart';
import 'package:kineograph_search_sandbox/screens/scrubber_detail_stub.dart';
import 'package:kineograph_search_sandbox/screens/user_profile_stub.dart';
import 'package:kineograph_search_sandbox/services/search/search_result.dart';
import 'package:kineograph_search_sandbox/services/search/typesense_service.dart';

/// Material `SearchDelegate` that pushes the user-typed query into a
/// debounced Typesense `multi_search` round-trip and renders grouped
/// results.
///
/// Opens via `showSearch(context: context, delegate: SandboxSearchDelegate())`
/// from the home screen.
class SandboxSearchDelegate extends SearchDelegate<void> {
  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) => _build(context);

  Widget _build(BuildContext context) {
    if (!TypesenseService().isAvailable) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Typesense is not configured.\n'
            'Pass --dart-define=TYPESENSE_HOST and TYPESENSE_API_KEY '
            'and relaunch.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return _TypesenseResults(query: query);
  }
}

// ── Typesense async results widget ──────────────────────────────────────────

class _TypesenseResults extends StatefulWidget {
  final String query;
  const _TypesenseResults({required this.query});

  @override
  State<_TypesenseResults> createState() => _TypesenseResultsState();
}

class _TypesenseResultsState extends State<_TypesenseResults> {
  Timer? _debounce;
  List<SearchResult> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void didUpdateWidget(covariant _TypesenseResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) _scheduleSearch();
  }

  @override
  void initState() {
    super.initState();
    _scheduleSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    if (widget.query.trim().isEmpty) {
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    // 500ms debounce — each Typesense call costs money. Don't fire on
    // every keystroke; wait for a meaningful pause.
    _debounce = Timer(const Duration(milliseconds: 500), _search);
    if (_results.isEmpty) setState(() => _loading = true);
  }

  Future<void> _search() async {
    final q = widget.query.trim();
    if (q.isEmpty || q == _lastQuery) return;
    _lastQuery = q;

    if (mounted) setState(() => _loading = true);
    final locale = Localizations.localeOf(context).languageCode;

    final results = await TypesenseService().searchAll(q, locale);

    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.query.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return Center(child: Text('No results found for "${widget.query}"'));
    }

    final articleResults =
        _results.whereType<ArticleSearchResult>().toList();
    final scrubberResults =
        _results.whereType<ScrubberSearchResult>().toList();
    final userResults = _results.whereType<UserSearchResult>().toList();

    return ListView(
      children: [
        if (articleResults.isNotEmpty) ...[
          _sectionHeader(context, 'Articles', articleResults.length),
          for (final r in articleResults) _articleTile(context, r),
        ],
        if (scrubberResults.isNotEmpty) ...[
          _sectionHeader(context, 'Scrubbers', scrubberResults.length),
          for (final r in scrubberResults) _scrubberTile(context, r),
        ],
        if (userResults.isNotEmpty) ...[
          _sectionHeader(context, 'Users', userResults.length),
          for (final r in userResults) _userTile(context, r),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        '$title ($count)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _articleTile(BuildContext context, ArticleSearchResult r) {
    return ListTile(
      leading: const Icon(Icons.article_outlined),
      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (r.authorNames.isNotEmpty) r.authorNames.join(', '),
          r.disciplineId,
        ].where((s) => s.isNotEmpty).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ArticleDetailStub(
            docId: r.docId,
            disciplineId: r.disciplineId,
            title: r.title,
          ),
        ));
      },
    );
  }

  Widget _scrubberTile(BuildContext context, ScrubberSearchResult r) {
    return ListTile(
      leading: const Icon(Icons.animation_outlined),
      title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        'by ${r.authorName}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ScrubberDetailStub(
            docId: r.docId,
            collection: r.typesenseCollection,
            authorUid: r.authorUid,
            title: r.title,
          ),
        ));
      },
    );
  }

  Widget _userTile(BuildContext context, UserSearchResult r) {
    return ListTile(
      leading: r.photoUrl != null && r.photoUrl!.isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(r.photoUrl!),
              radius: 16,
            )
          : const CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 16),
            ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              r.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (r.isOfficialAccount) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.verified,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
      subtitle: Text(
        r.isOfficialAccount
            ? 'Official Account'
            : '${r.scrubberCount} '
                'scrubber${r.scrubberCount == 1 ? '' : 's'}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UserProfileStub(
            uid: r.uid,
            displayName: r.displayName,
            isOfficialAccount: r.isOfficialAccount,
          ),
        ));
      },
    );
  }
}
