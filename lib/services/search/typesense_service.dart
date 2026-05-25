// Carved from musculature/lib/services/search/typesense_service.dart for
// search sandbox. Two structural changes vs production:
//   1. Imports rebased to package:kineograph_search_sandbox/...
//   2. The Typesense Client's URI scheme reads from kTypesenseProtocol
//      (was hardcoded 'https') so the collaborator can swap https↔http via
//      --dart-define without touching source.
// All search logic, parsing, cost-aware comments, and field-name handling
// are preserved verbatim.

import 'package:flutter/foundation.dart';
import 'package:typesense/typesense.dart';

import 'package:kineograph_search_sandbox/config/typesense_config.dart';
import 'package:kineograph_search_sandbox/services/search/search_result.dart';

/// Minimum query length before hitting Typesense. Short queries (1 char)
/// produce broad matches that cost money without adding value — let the
/// user type a meaningful prefix first.
const kMinTypesenseQueryLength = 2;

/// Singleton wrapping the Typesense Dart client for full-text search.
///
/// Call [init] at app startup. If Typesense is not configured (empty host/key),
/// [isAvailable] stays `false` and all search methods return empty lists — the
/// UI should fall back to client-side substring search in that case.
///
/// ## Cost awareness
///
/// Typesense Cloud bills per search operation. Each sub-search inside a
/// `multi_search` call counts as one operation. Cost levers:
///
/// - **`infix` mode**: `'fallback'` falls back to substring scanning when
///   prefix matching fails — by far the most expensive mode. Use `'off'`
///   (prefix-only) unless substring matching is essential for the field.
///   Only enable `'fallback'` for short identifier fields (usernames) where
///   users commonly search by middle-of-word substrings.
///
/// - **Collection count**: each collection in a `multi_search` is billed
///   separately. Minimize the number of collections searched.
///
/// - **Client-side guards**: debounce (500ms), minimum query length (2 chars),
///   and dedup (`_lastQuery`) all reduce spurious API calls.
class TypesenseService {
  static final TypesenseService _instance = TypesenseService._internal();
  factory TypesenseService() => _instance;
  TypesenseService._internal();

  Client? _client;

  /// Whether Typesense is configured and ready for queries.
  bool get isAvailable => _client != null;

  /// Initialises the Typesense client. No-op if host or key is empty.
  ///
  /// The URI scheme comes from [kTypesenseProtocol] (default `https`). This
  /// is the **only** code path that consumes the protocol value — any new
  /// logic that talks to Typesense should also use [kTypesenseProtocol]
  /// rather than hardcoding `https`. (See Phase 4 of the carve prompt:
  /// host/protocol/key swap must be config-only, no source edits.)
  void init({
    String host = kTypesenseHost,
    String apiKey = kTypesenseApiKey,
    int port = kTypesensePort,
    String protocol = kTypesenseProtocol,
  }) {
    if (host.isEmpty || apiKey.isEmpty) {
      debugPrint('TypesenseService: disabled (no host/key configured)');
      return;
    }
    final config = Configuration(
      apiKey,
      nodes: {
        Node.withUri(Uri(scheme: protocol, host: host, port: port)),
      },
      connectionTimeout: const Duration(seconds: 5),
    );
    _client = Client(config);
    debugPrint('TypesenseService: initialised ($protocol://$host:$port)');
  }

  // ── Public search methods ───────────────────────────────────────────────

  /// Searches articles across all article collections, or a single one when
  /// [firestoreCollectionName] is provided (e.g. `'muscles'`).
  /// Searches articles, optionally scoped by collection or facet filter.
  ///
  /// [firestoreCollectionName] limits to a single Typesense collection
  /// (legacy discipline-based scoping).
  ///
  /// [facetFilter] adds a `_facetIndex:=value` filter — e.g.
  /// `"source:handbuch-anatomie-tiere-1901"`. Use this for hub card
  /// rule-based scoping where the primary facet may not be a discipline.
  Future<List<ArticleSearchResult>> searchArticles(
    String query,
    String locale, {
    String? firestoreCollectionName,
    String? facetFilter,
    int perPage = 8,
  }) async {
    if (_client == null || query.trim().length < kMinTypesenseQueryLength) {
      return [];
    }

    final queryBy = _articleQueryBy(locale);

    // When scoped to a single Firestore collection, only search its
    // corresponding Typesense collection.
    final collections = firestoreCollectionName != null
        ? kArticleTypesenseCollections.where((c) =>
            kTypesenseToFirestoreCollection[c] == firestoreCollectionName)
        : kArticleTypesenseCollections;

    // Build filter_by: combine isPrivate guard with optional facet filter.
    final filters = <String>[
      if (!kDebugMode) 'isPrivate:false',
      if (facetFilter != null) '_facetIndex:=$facetFilter',
    ];
    final filterBy = filters.isNotEmpty ? filters.join(' && ') : null;

    final searches = [
      for (final c in collections)
        {
          'collection': c,
          'query_by': queryBy,
          'highlight_fields': _articleHighlightFields(locale),
          if (filterBy != null) 'filter_by': filterBy,
          'per_page': '$perPage',
        },
    ];

    try {
      final response = await _client!.multiSearch
          .perform({'searches': searches}, queryParams: {'q': query});
      return _parseArticleResults(response);
    } catch (e) {
      debugPrint('TypesenseService.searchArticles: $e');
      return [];
    }
  }

  /// Searches scrubbers across library + user collections.
  Future<List<ScrubberSearchResult>> searchScrubbers(
    String query,
    String locale, {
    int perPage = 8,
  }) async {
    if (_client == null || query.trim().length < kMinTypesenseQueryLength) {
      return [];
    }

    final queryBy = _scrubberQueryBy(locale);
    final searches = [
      for (final c in kScrubberTypesenseCollections)
        {
          'collection': c,
          'query_by': queryBy,
          'highlight_fields': _scrubberHighlightFields(locale),
          'per_page': '$perPage',
        },
    ];

    try {
      final response = await _client!.multiSearch
          .perform({'searches': searches}, queryParams: {'q': query});
      return _parseScrubberResults(response);
    } catch (e) {
      debugPrint('TypesenseService.searchScrubbers: $e');
      return [];
    }
  }

  /// Searches user profiles.
  Future<List<UserSearchResult>> searchUsers(
    String query, {
    int perPage = 8,
  }) async {
    if (_client == null || query.trim().length < kMinTypesenseQueryLength) {
      return [];
    }

    try {
      final response = await _client!.multiSearch.perform({
        'searches': [
          {
            'collection': kUserProfileTypesenseCollection,
            'query_by': 'displayName,username',
            // infix only on username — users search "@handle" substrings.
            // displayName uses prefix matching (cheaper).
            'infix': 'off,fallback',
            'per_page': '$perPage',
          },
          {
            'collection': kOaProfileTypesenseCollection,
            'query_by': 'displayName,username',
            'infix': 'off,fallback',
            'per_page': '$perPage',
          },
        ],
      }, queryParams: {
        'q': query,
      });
      return _parseUserResults(response);
    } catch (e) {
      debugPrint('TypesenseService.searchUsers: $e');
      return [];
    }
  }

  /// Combined search across all types in a single `multi_search` round-trip.
  ///
  /// Cost: 8 sub-searches (4 article + 2 scrubber + 2 user profile collections)
  /// per call. Guarded by [kMinTypesenseQueryLength] and 500ms debounce in
  /// the UI layer. Consider reducing collection count when migrating to a
  /// unified `articles` Typesense collection.
  Future<List<SearchResult>> searchAll(
    String query,
    String locale, {
    int perPage = 4,
  }) async {
    if (_client == null || query.trim().length < kMinTypesenseQueryLength) {
      return [];
    }

    final artQueryBy = _articleQueryBy(locale);
    final scrQueryBy = _scrubberQueryBy(locale);

    final searches = <Map<String, String>>[
      for (final c in kArticleTypesenseCollections)
        {
          'collection': c,
          'query_by': artQueryBy,
          'highlight_fields': _articleHighlightFields(locale),
          if (!kDebugMode) 'filter_by': 'isPrivate:false',
          'per_page': '$perPage',
        },
      for (final c in kScrubberTypesenseCollections)
        {
          'collection': c,
          'query_by': scrQueryBy,
          'highlight_fields': _scrubberHighlightFields(locale),
          'per_page': '$perPage',
        },
      {
        'collection': kUserProfileTypesenseCollection,
        'query_by': 'displayName,username',
        'infix': 'off,fallback',
        'per_page': '$perPage',
      },
      {
        'collection': kOaProfileTypesenseCollection,
        'query_by': 'displayName,username',
        'infix': 'off,fallback',
        'per_page': '$perPage',
      },
    ];

    try {
      final response = await _client!.multiSearch
          .perform({'searches': searches}, queryParams: {'q': query});
      return _parseAllResults(response);
    } catch (e) {
      debugPrint('TypesenseService.searchAll: $e');
      return [];
    }
  }

  // ── query_by builders ───────────────────────────────────────────────────

  /// Builds the `query_by` field list for article searches.
  ///
  /// Prioritises the user's locale, falls back to English, then metadata.
  String _articleQueryBy(String locale) {
    final suffix = _toSuffix(locale);
    final fields = <String>[
      'title_$suffix',
      '_searchContent_$suffix',
    ];
    if (suffix != 'en') {
      fields.addAll(['title_en', '_searchContent_en']);
    }
    fields.addAll(['author_names', 'author_usernames', 'tags_all']);
    return fields.join(',');
  }

  String _articleHighlightFields(String locale) {
    final suffix = _toSuffix(locale);
    return suffix == 'en' ? 'title_en' : 'title_$suffix,title_en';
  }

  /// Builds the `query_by` field list for scrubber searches.
  String _scrubberQueryBy(String locale) {
    final suffix = _toSuffix(locale);
    final fields = <String>[
      'title_$suffix',
      'description_$suffix',
    ];
    if (suffix != 'en') {
      fields.addAll(['title_en', 'description_en']);
    }
    fields.addAll(['author_name', 'author_username', 'tags_all']);
    return fields.join(',');
  }

  String _scrubberHighlightFields(String locale) {
    final suffix = _toSuffix(locale);
    return suffix == 'en' ? 'title_en' : 'title_$suffix,title_en';
  }

  /// Converts a Flutter language code to our flat-field suffix.
  static String _toSuffix(String locale) => locale.replaceAll('-', '_');

  // ── Response parsers ────────────────────────────────────────────────────

  List<ArticleSearchResult> _parseArticleResults(Map<String, dynamic> resp) {
    final results = resp['results'] as List<dynamic>? ?? [];
    final out = <ArticleSearchResult>[];
    for (final resultSet in results) {
      final hits = (resultSet as Map<String, dynamic>)['hits'] as List? ?? [];
      for (final hit in hits) {
        out.add(_parseArticleHit(hit as Map<String, dynamic>));
      }
    }
    return out;
  }

  ArticleSearchResult _parseArticleHit(Map<String, dynamic> hit) {
    final doc = hit['document'] as Map<String, dynamic>? ?? {};
    final highlights = hit['highlights'] as List<dynamic>? ?? [];

    return ArticleSearchResult(
      docId: doc['id'] as String? ?? '',
      disciplineId: doc['disciplineId'] as String? ?? '',
      title: _resolveTitle(doc),
      authorNames: _toStringList(doc['author_names']),
      highlightSnippet: _firstSnippet(highlights),
    );
  }

  List<ScrubberSearchResult> _parseScrubberResults(Map<String, dynamic> resp) {
    final results = resp['results'] as List<dynamic>? ?? [];
    final out = <ScrubberSearchResult>[];
    for (int i = 0; i < results.length; i++) {
      final resultSet = results[i] as Map<String, dynamic>;
      final hits = resultSet['hits'] as List? ?? [];
      final collection = kScrubberTypesenseCollections[i];
      for (final hit in hits) {
        out.add(_parseScrubberHit(hit as Map<String, dynamic>, collection));
      }
    }
    return out;
  }

  ScrubberSearchResult _parseScrubberHit(
      Map<String, dynamic> hit, String collection) {
    final doc = hit['document'] as Map<String, dynamic>? ?? {};

    return ScrubberSearchResult(
      docId: doc['id'] as String? ?? '',
      typesenseCollection: collection,
      title: _resolveTitle(doc),
      authorName: doc['author_name'] as String? ?? '',
      authorUid: doc['author_uid'] as String? ?? '',
      imagePath: doc['imagePath'] as String?,
      rangeStart: doc['rangeStart'] as int?,
      imageVersion: doc['imageVersion'] as int?,
    );
  }

  List<UserSearchResult> _parseUserResults(Map<String, dynamic> resp) {
    final results = resp['results'] as List<dynamic>? ?? [];
    final out = <UserSearchResult>[];
    for (final resultSet in results) {
      final hits = (resultSet as Map<String, dynamic>)['hits'] as List? ?? [];
      for (final hit in hits) {
        out.add(_parseUserHit(hit as Map<String, dynamic>));
      }
    }
    return out;
  }

  UserSearchResult _parseUserHit(Map<String, dynamic> hit,
      {bool isOfficialAccount = false}) {
    final doc = hit['document'] as Map<String, dynamic>? ?? {};
    return UserSearchResult(
      uid: doc['id'] as String? ?? '',
      displayName: doc['displayName'] as String? ?? '',
      photoUrl: doc['photoUrl'] as String?,
      scrubberCount: doc['scrubberCount'] as int? ?? 0,
      isOfficialAccount:
          isOfficialAccount || doc['isOfficialAccount'] == true,
    );
  }

  /// Parses combined results from [searchAll].
  ///
  /// The results array order matches the searches order:
  /// [0..3] articles, [4..5] scrubbers, [6] users, [7] OA profiles.
  List<SearchResult> _parseAllResults(Map<String, dynamic> resp) {
    final results = resp['results'] as List<dynamic>? ?? [];
    final out = <SearchResult>[];

    final artCount = kArticleTypesenseCollections.length;
    final scrCount = kScrubberTypesenseCollections.length;
    final userIdx = artCount + scrCount; // user_profiles index
    final oaIdx = userIdx + 1; // oa_profiles index

    for (int i = 0; i < results.length; i++) {
      final resultSet = results[i] as Map<String, dynamic>;
      final hits = resultSet['hits'] as List<dynamic>? ?? [];

      if (i < artCount) {
        for (final hit in hits) {
          out.add(_parseArticleHit(hit as Map<String, dynamic>));
        }
      } else if (i < artCount + scrCount) {
        final collection = kScrubberTypesenseCollections[i - artCount];
        for (final hit in hits) {
          out.add(_parseScrubberHit(hit as Map<String, dynamic>, collection));
        }
      } else if (i == oaIdx) {
        for (final hit in hits) {
          out.add(_parseUserHit(hit as Map<String, dynamic>,
              isOfficialAccount: true));
        }
      } else {
        for (final hit in hits) {
          out.add(_parseUserHit(hit as Map<String, dynamic>));
        }
      }
    }

    return out;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  /// Picks the best available title from the document fields.
  ///
  /// Tries the user's locale first, then English, then any `title_*` field.
  static String _resolveTitle(Map<String, dynamic> doc) {
    // Try common locales in priority order.
    for (final key in ['title_en', 'title_de', 'title_ja', 'title_fr']) {
      final v = doc[key];
      if (v is String && v.isNotEmpty) return v;
    }
    // Fallback: first non-empty title_* field.
    for (final entry in doc.entries) {
      if (entry.key.startsWith('title_') &&
          entry.value is String &&
          (entry.value as String).isNotEmpty) {
        return entry.value as String;
      }
    }
    return '';
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static String? _firstSnippet(List<dynamic> highlights) {
    if (highlights.isEmpty) return null;
    final first = highlights[0];
    if (first is Map<String, dynamic>) return first['snippet'] as String?;
    return null;
  }
}
