// New for the search sandbox — the production AuthorInfo has provider-
// specific logic (Apple/Google/Steam/Discord display-name handling,
// linked-account merging, federation flags) none of which is relevant
// to consuming search results.

/// Minimal author-identity record, used inside [ArticleSearchResult] and
/// to render result tiles.
///
/// Mirrors the subset of the production `AuthorInfo` shape that the
/// Firestore→Typesense extension actually indexes. The production model
/// is much richer (provider, federation status, linked accounts, Apple
/// auto-generated display-name detection); none of those affect search
/// behavior, so they're excluded.
class AuthorInfo {
  final String uid;
  final String displayName;
  final String? username;
  final String? photoUrl;

  const AuthorInfo({
    required this.uid,
    required this.displayName,
    this.username,
    this.photoUrl,
  });

  /// Best human-facing identifier — preferred username, fallback to display name.
  String get displayIdentity =>
      (username != null && username!.isNotEmpty) ? '@$username' : displayName;
}
