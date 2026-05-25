// Carved from musculature/lib/services/search/typesense_config.dart for
// search sandbox. The production file hardcoded the cluster host and the
// search-only API key as compile-time string literals (documented as
// "safe to embed client-side"); the sandbox replaces those with
// --dart-define values so the collaborator can repoint at a self-hosted
// Typesense node without editing source. Collection-name constants are
// preserved verbatim — they are stable contracts with the Firebase
// Extension's TYPESENSE_COLLECTION_NAME configuration.

/// Configuration for the Typesense client.
///
/// All three runtime values are read from `--dart-define` at compile time:
///
/// ```
/// flutter run \
///   --dart-define=TYPESENSE_HOST=cluster-xxx.a1.typesense.net \
///   --dart-define=TYPESENSE_API_KEY=<search-only-key> \
///   --dart-define=TYPESENSE_PROTOCOL=https
/// ```
///
/// `TYPESENSE_PROTOCOL` defaults to `https`, which is what Typesense Cloud
/// requires and what most TLS-terminated self-hosted setups also need.
/// During early self-hosted bring-up (no TLS yet) the collaborator can pass
/// `--dart-define=TYPESENSE_PROTOCOL=http` to point at an unencrypted node.
///
/// When `TYPESENSE_HOST` or `TYPESENSE_API_KEY` are empty (no defines
/// supplied), `TypesenseService.init()` short-circuits and `isAvailable`
/// stays false — every search method returns an empty list.
library;

/// Cluster hostname. Empty by default — the collaborator must supply a
/// value via `--dart-define=TYPESENSE_HOST=…` before any query can run.
const kTypesenseHost = String.fromEnvironment('TYPESENSE_HOST');

/// Search-only API key. Empty by default. Typesense Cloud's documented
/// guidance is that a key scoped to `documents:search` only is safe to
/// embed client-side; for self-hosted nodes the collaborator can mint a
/// search-only key with `curl -X POST … /keys` (see Typesense docs).
const kTypesenseApiKey = String.fromEnvironment('TYPESENSE_API_KEY');

/// URI scheme used when building the Typesense client URL.
///
/// `https` (the default) matches Typesense Cloud and any TLS-terminated
/// self-hosted deployment. `http` is for early bring-up of a self-hosted
/// node before TLS is in place; switching is config-only with no source
/// changes.
const kTypesenseProtocol =
    String.fromEnvironment('TYPESENSE_PROTOCOL', defaultValue: 'https');

/// Port for the Typesense server.
///
/// Defaults to 443 (Typesense Cloud + most TLS-terminated self-hosted).
/// Self-hosted nodes commonly use 8108 for plain HTTP during bring-up;
/// pass `--dart-define=TYPESENSE_PORT=8108` in that case.
const kTypesensePort =
    int.fromEnvironment('TYPESENSE_PORT', defaultValue: 443);

// ── Collection names ────────────────────────────────────────────────────────

/// Typesense collection names for article searches.
/// Each maps 1:1 to a Firestore collection synced via the Firebase Extension.
///
/// Note: production currently configures the Firebase Extension to publish
/// a single unified `articles` collection (see
/// `extensions/typesense-sync-articles.env`), but the production Dart code
/// still references the legacy per-discipline split. The discrepancy is
/// preserved verbatim here so the sandbox reproduces the production
/// behavior — including whatever staleness exists.
const kArticleTypesenseCollections = [
  'articles_muscles',
  'articles_anim',
  'articles_paint',
  'articles_portrait',
];

/// Typesense collection names for scrubber searches.
const kScrubberTypesenseCollections = [
  'scrubbers_library',
  'scrubbers_user',
];

/// Typesense collection name for user profile searches.
const kUserProfileTypesenseCollection = 'user_profiles';

/// Typesense collection name for Official Account profile searches.
const kOaProfileTypesenseCollection = 'oa_profiles';

/// Maps Typesense article collection names → Firestore collection names.
///
/// Used by the production legacy scoping path (`searchArticles` with a
/// `firestoreCollectionName` filter). The sandbox keeps this constant so
/// `TypesenseService` carves remain identical to production, even though
/// the sandbox UI doesn't expose discipline-scoped search.
const kTypesenseToFirestoreCollection = {
  'articles_muscles': 'muscles',
  'articles_anim': 'anim',
  'articles_paint': 'paint',
  'articles_portrait': 'portrait',
};
