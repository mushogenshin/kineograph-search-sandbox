// Stubbed for the search sandbox — the production taxonomy.dart defines a
// full faceted classification system (disciplines × eras × media × subjects
// × pedagogy × Bloom levels). The sandbox only needs the discipline IDs
// because result tiles surface `disciplineId` for articles, and the
// per-discipline article-collection mapping in typesense_config.dart
// references these strings.

/// Known discipline IDs at launch.
///
/// In production these are seed content (per the Yegge mandate in
/// CLAUDE.md: "primitives, not categories" — new disciplines must be
/// addable without code changes by editing `app_config/taxonomy` in
/// Firestore). This sandbox just hardcodes the launch set since it never
/// writes taxonomy data.
const kDisciplineIds = <String>[
  'anatomy',
  'animation',
  'painting',
  'portrait',
];

/// Human-readable label for a discipline ID. Falls back to the raw ID if
/// unknown (e.g. a future Firestore-added discipline the sandbox doesn't
/// know about yet).
String disciplineLabel(String id) {
  switch (id) {
    case 'anatomy':
      return 'Anatomy';
    case 'animation':
      return 'Animation';
    case 'painting':
      return 'Painting';
    case 'portrait':
      return 'Portrait';
    default:
      return id;
  }
}
