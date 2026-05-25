// New for the search sandbox. Mirrors the field list configured in
// extensions/typesense-sync-user-profiles.env so the collaborator can
// see exactly which Firestore fields the extension is publishing into
// the `user_profiles` Typesense collection.

import 'package:cloud_firestore/cloud_firestore.dart';

/// Document shape for the Firestore `user_profiles/{uid}` collection.
///
/// This is the public-search projection of a Kineograph user: the minimum
/// fields needed to render a "found by @handle" result tile. It excludes
/// auth identifiers, email, linked-account metadata, entitlement state,
/// device info, and everything else that lives on `users/{uid}` proper.
///
/// The Firestore→Typesense extension is configured (see
/// `extensions/typesense-sync-user-profiles.env`) to mirror exactly this
/// field set:
///
/// ```
/// displayName, photoUrl, provider, username, scrubberCount, updatedAt
/// ```
///
/// `provider` is the auth-provider identifier (e.g. `apple`, `google`,
/// `steam`) — Typesense indexes it as a facet but the sandbox search UI
/// doesn't surface a facet filter, so it lives on the model only.
///
/// The Official Account variant (`oa_profiles/{uid}`) adds an
/// `isOfficialAccount: true` field. See `oa_profiles.json` schema +
/// `typesense-sync-oa-profiles.env` for the OA-specific projection.
class UserProfile {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? provider;
  final String? username;
  final int scrubberCount;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.provider,
    this.username,
    this.scrubberCount = 0,
    this.updatedAt,
  });

  /// Parses a `user_profiles/{uid}` Firestore document.
  ///
  /// Provided for shape-comparison reference — the sandbox itself doesn't
  /// load these documents (stub navigation skips the round-trip).
  factory UserProfile.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    final ts = data['updatedAt'];
    DateTime? updated;
    if (ts is Timestamp) {
      updated = ts.toDate();
    } else if (ts is int) {
      updated = DateTime.fromMillisecondsSinceEpoch(ts);
    }
    return UserProfile(
      uid: uid,
      displayName: data['displayName'] as String? ?? '',
      photoUrl: data['photoUrl'] as String?,
      provider: data['provider'] as String?,
      username: data['username'] as String?,
      scrubberCount: (data['scrubberCount'] as num?)?.toInt() ?? 0,
      updatedAt: updated,
    );
  }
}
