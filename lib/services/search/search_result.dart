// Carved from musculature/lib/services/search/search_result.dart for
// search sandbox. Unchanged — pure data classes with no external deps.

/// Unified search result models returned by [TypesenseService].
library;

/// Base class for all Typesense search results.
sealed class SearchResult {
  /// Best available title for display (locale-resolved).
  String get displayTitle;
}

/// An article result from one of the article collections.
class ArticleSearchResult extends SearchResult {
  final String docId;

  /// Discipline ID (e.g. `'anatomy'`, `'animation'`).
  final String disciplineId;
  final String title;
  final List<String> authorNames;
  final String? highlightSnippet;

  ArticleSearchResult({
    required this.docId,
    required this.disciplineId,
    required this.title,
    this.authorNames = const [],
    this.highlightSnippet,
  });

  @override
  String get displayTitle => title;
}

/// A scrubber result from the library or user scrubber collections.
class ScrubberSearchResult extends SearchResult {
  final String docId;

  /// Which Typesense collection this came from (determines official vs user).
  final String typesenseCollection;
  final String title;
  final String authorName;
  final String authorUid;
  final String? imagePath;
  final int? rangeStart;
  final int? imageVersion;

  ScrubberSearchResult({
    required this.docId,
    required this.typesenseCollection,
    required this.title,
    required this.authorName,
    required this.authorUid,
    this.imagePath,
    this.rangeStart,
    this.imageVersion,
  });

  bool get isOfficial => typesenseCollection == 'scrubbers_library';

  /// Firestore document path for this scrubber.
  String get firestorePath => isOfficial
      ? 'library_scrubbers/$docId'
      : 'users/$authorUid/scrubbers/$docId';

  @override
  String get displayTitle => title;
}

/// A user or Official Account profile result.
class UserSearchResult extends SearchResult {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final int scrubberCount;

  /// True when this result represents an Official Account.
  final bool isOfficialAccount;

  UserSearchResult({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.scrubberCount = 0,
    this.isOfficialAccount = false,
  });

  @override
  String get displayTitle => displayName;
}
