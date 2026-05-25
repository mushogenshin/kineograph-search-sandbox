// Carved from musculature/lib/models/article_data.dart for the search
// sandbox. The production class wraps ArticleMetadata, ContentBlock,
// UserArticle, entitlementBundles, sortWeight, sourceType/Uid, and a
// computeSearchContent() that builds locale-flat _searchContent_<locale>
// fields when writing to Firestore. The sandbox never writes, so all
// write-side plumbing is removed; the read side keeps only the fields
// that the Typesense Extension publishes per
// extensions/typesense-sync-articles.env.

import 'package:kineograph_search_sandbox/models/author_info.dart';

/// Document shape for the unified `articles/{docId}` Firestore collection.
///
/// **Indexed fields** (per `extensions/typesense-sync-articles.env`):
///
/// ```
/// title_en, title_de, title_es, title_fr, title_ja, title_ko, title_ru,
/// title_vi, title_zh, title_zh_Hant,
/// author_names, author_uids, author_usernames,
/// tags_all,
/// _searchContent_en, _searchContent_de, _searchContent_es,
/// _searchContent_fr, _searchContent_ja, _searchContent_ko,
/// _searchContent_ru, _searchContent_vi, _searchContent_zh,
/// _searchContent_zh_Hant,
/// primaryDiscipline, disciplines, _facetIndex,
/// accessTier, isPrivate
/// ```
///
/// `_searchContent_<locale>` is a denormalized concatenation built by the
/// production app at write-time (title + tags + scrubber titles +
/// scrubber descriptions + author names + text-block plain text +
/// discipline / facet values, see `ArticleData.computeSearchContent`
/// in the production source). The Typesense Extension can only mirror
/// top-level Firestore fields, so the denormalization happens
/// client-side before the write. The sandbox does NOT include the
/// computeSearchContent function because the sandbox does not write.
///
/// `_facetIndex` is a flattened version of the structured `facets` map
/// (e.g. `["era:19th-century", "medium:photography"]`). Used by
/// Typesense queries via `filter_by: _facetIndex:=<value>` and by
/// Firestore queries via `arrayContains`.
class ArticleData {
  final String id;

  /// Per-locale title. Stored as flat `title_<locale>` fields in
  /// Firestore so the Typesense Extension can publish them top-level.
  final Map<String, String> title;

  final List<AuthorInfo> authors;

  /// Flattened tag list across all locales (production has structured
  /// LocalizedTag per locale; the indexed `tags_all` field is a flat
  /// denormalization).
  final List<String> tagsAll;

  /// Discipline IDs this article belongs to.
  final List<String> disciplines;

  /// The primary discipline — first entry in [disciplines].
  /// Routing / display color / default grouping all key off this.
  final String primaryDiscipline;

  /// Structured facets keyed by dimension ID.
  /// Example: `{"era": ["19th-century"], "medium": ["photography"]}`.
  final Map<String, List<String>> facets;

  /// Flattened facet index for Firestore `arrayContains` queries and
  /// Typesense `filter_by` clauses.
  final List<String> facetIndex;

  /// Entitlement tier required to access this article (`free`, `plus`,
  /// `pro`, `max`). Faceted for filtering by access tier.
  final String accessTier;

  /// Whether this article is hidden from public listings & search in
  /// non-debug builds. The TypesenseService applies a `isPrivate:false`
  /// filter automatically in release mode.
  final bool isPrivate;

  const ArticleData({
    required this.id,
    this.title = const {},
    this.authors = const [],
    this.tagsAll = const [],
    this.disciplines = const [],
    this.primaryDiscipline = '',
    this.facets = const {},
    this.facetIndex = const [],
    this.accessTier = 'plus',
    this.isPrivate = false,
  });

  /// Resolves the title for the given [locale], falling back to English,
  /// then to the first available locale.
  String resolvedTitle(String locale) {
    final v = title[locale];
    if (v != null && v.isNotEmpty) return v;
    final en = title['en'];
    if (en != null && en.isNotEmpty) return en;
    for (final entry in title.entries) {
      if (entry.value.isNotEmpty) return entry.value;
    }
    return '';
  }

  /// Parses a Firestore article document.
  ///
  /// Read-side only — the sandbox doesn't write back. Reads the flat
  /// `title_<locale>` fields and reconstructs them into the map shape
  /// this Dart class uses.
  factory ArticleData.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    final title = <String, String>{};
    for (final entry in data.entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is String && k.startsWith('title_')) {
        title[k.substring('title_'.length).replaceAll('_', '-')] = v;
      }
    }

    final authorNames =
        (data['author_names'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    final authorUids =
        (data['author_uids'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    final authorUsernames =
        (data['author_usernames'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];

    final authors = <AuthorInfo>[];
    for (var i = 0; i < authorNames.length; i++) {
      authors.add(AuthorInfo(
        uid: i < authorUids.length ? authorUids[i] : '',
        displayName: authorNames[i],
        username: i < authorUsernames.length ? authorUsernames[i] : null,
      ));
    }

    final tags =
        (data['tags_all'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];
    final disciplines =
        (data['disciplines'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];

    final rawFacets = data['facets'] as Map<String, dynamic>? ?? const {};
    final facets = <String, List<String>>{};
    for (final entry in rawFacets.entries) {
      final values = entry.value;
      if (values is List) {
        facets[entry.key] = values.whereType<String>().toList();
      }
    }

    final facetIndex =
        (data['_facetIndex'] as List<dynamic>?)?.whereType<String>().toList() ??
            const [];

    return ArticleData(
      id: docId,
      title: title,
      authors: authors,
      tagsAll: tags,
      disciplines: disciplines,
      primaryDiscipline:
          data['primaryDiscipline'] as String? ?? disciplines.firstOrNull ?? '',
      facets: facets,
      facetIndex: facetIndex,
      accessTier: data['accessTier'] as String? ?? 'plus',
      isPrivate: data['isPrivate'] as bool? ?? false,
    );
  }
}
