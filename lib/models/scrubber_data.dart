// Carved from musculature/lib/models/scrubber_data.dart for the search
// sandbox. The production class carries the entire scrubber-editor data
// model (frame transforms, canvas aspect, R2 thumbnail key plumbing for
// 8 thumbnail variants, boutique stride config, etc.). None of that is
// indexed by Typesense, so the carve drops everything except the fields
// that appear in extensions/typesense-sync-library-scrubbers.env and
// typesense-sync-user-scrubbers.env.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Document shape for `library_scrubbers/{docId}` and
/// `users/{uid}/scrubbers/{docId}` Firestore collections.
///
/// Both collections are synced into Typesense (collections
/// `scrubbers_library` and `scrubbers_user` respectively) with the same
/// field list — that's why the production `create-collections.sh`
/// reuses one `schemas/scrubbers.json` for both with a `PLACEHOLDER`
/// substitution.
///
/// **Indexed fields** (per the extension env files):
///
/// - `title_<locale>`, `description_<locale>` for each of 10 launch
///   locales (`en`, `de`, `es`, `fr`, `ja`, `ko`, `ru`, `vi`, `zh`,
///   `zh_Hant`). These are flat fields, not a nested map — the
///   Firestore Extension can only walk top-level keys.
/// - `author_name`, `author_uid`, `author_username`.
/// - `tags_all` — flat string array, faceted.
/// - `imagePath`, `rangeStart`, `imageVersion` — stored for routing &
///   thumbnail cache-busting in the search-result tile.
/// - `disciplineId` — faceted, for future per-discipline scrubber
///   filtering.
/// - `createdAt` — sortable int64 (ms since epoch).
///
/// Everything else (canvasAspectRatio, frameTransforms, thumbnailKeys,
/// boutiqueStride, productionTier, storagePath, totalBytes…) lives on
/// the Firestore document but is NOT indexed — those fields are read
/// only when the app opens the scrubber for playback, never during
/// search.
class ScrubberData {
  /// Per-locale title. Stored as flat fields (`title_en`, `title_de`, …)
  /// in Firestore so the Typesense Extension can publish them.
  final Map<String, String> title;

  /// Per-locale description. Same flat-field convention as [title].
  final Map<String, String> description;

  final String? authorName;
  final String? authorUid;
  final String? authorUsername;

  /// Flat tag list across all locales (the production model has
  /// per-locale LocalizedTag values; the indexed `tags_all` field is a
  /// flat denormalization).
  final List<String> tagsAll;

  /// First-frame storage path / prefix. Used by the search-result tile
  /// to fetch a thumbnail.
  final String imagePath;

  /// 1-based index of the first frame (legacy: scrubbers used to live
  /// in flat directories with non-zero starting indices).
  final int rangeStart;

  /// Cache-busting counter — appended as `?v=N` to frame URLs after a
  /// content edit so CDN edge caches and client HTTP caches serve fresh
  /// bytes.
  final int imageVersion;

  /// Primary discipline ID (faceted in Typesense). Most scrubbers are
  /// single-discipline; this is the one used for routing.
  final String? disciplineId;

  /// Millisecond epoch (stored as int64 in Typesense for sortability).
  final DateTime? createdAt;

  const ScrubberData({
    this.title = const {},
    this.description = const {},
    this.authorName,
    this.authorUid,
    this.authorUsername,
    this.tagsAll = const [],
    required this.imagePath,
    this.rangeStart = 0,
    this.imageVersion = 0,
    this.disciplineId,
    this.createdAt,
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

  /// Parses a Firestore scrubber document.
  ///
  /// Reads the flat `title_<locale>` / `description_<locale>` fields and
  /// reconstructs them into the map shape this Dart class uses.
  factory ScrubberData.fromFirestore(
    String _,
    Map<String, dynamic> data,
  ) {
    final title = <String, String>{};
    final description = <String, String>{};
    for (final entry in data.entries) {
      final k = entry.key;
      final v = entry.value;
      if (v is! String) continue;
      if (k.startsWith('title_')) {
        title[k.substring('title_'.length).replaceAll('_', '-')] = v;
      } else if (k.startsWith('description_')) {
        description[k.substring('description_'.length).replaceAll('_', '-')] = v;
      }
    }

    final createdRaw = data['createdAt'];
    DateTime? created;
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    } else if (createdRaw is int) {
      created = DateTime.fromMillisecondsSinceEpoch(createdRaw);
    }

    final tags = data['tags_all'] as List<dynamic>? ?? const [];

    return ScrubberData(
      title: title,
      description: description,
      authorName: data['author_name'] as String?,
      authorUid: data['author_uid'] as String?,
      authorUsername: data['author_username'] as String?,
      tagsAll: tags.whereType<String>().toList(),
      imagePath: data['imagePath'] as String? ?? '',
      rangeStart: (data['rangeStart'] as num?)?.toInt() ?? 0,
      imageVersion: (data['imageVersion'] as num?)?.toInt() ?? 0,
      disciplineId: data['disciplineId'] as String?,
      createdAt: created,
    );
  }
}
