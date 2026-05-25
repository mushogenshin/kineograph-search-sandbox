# Kineograph Search Sandbox

Sandbox for validating Typesense search behavior against the Kineograph
production data set. Carved from the production Flutter app — **not a
complete reproduction**. The only product surface you can exercise here
is the search bar; everything else (the article reader, scrubber player,
authoring tools, payments) was deliberately excluded.

The point: if a self-hosted Typesense node returns the same hits with the
same ranking as Typesense Cloud for the same query against the same
Firestore data, the swap is safe. This repo gives you a way to test that
end-to-end without standing up the production app.

## Prerequisites

- **Flutter SDK** ≥ 3.9 (matches the production app — anything newer should
  work, anything older won't).
- **Firebase CLI** (`firebase` and `flutterfire`). You'll use these to
  generate a `firebase_options.dart` against your own Firebase access.
- A **Typesense endpoint** to point at — either the existing Typesense
  Cloud cluster or your own self-hosted node.

## First-time setup

1. **Clone and pub get.**

   ```bash
   flutter pub get
   ```

2. **Generate Firebase config for your machine.** This writes
   `lib/firebase_options.dart` and the platform-specific config bundles
   (`google-services.json`, `GoogleService-Info.plist`). All three are
   `.gitignore`d — they should never be committed.

   ```bash
   flutterfire configure --project=anastomia-musculature
   ```

3. **Wire `firebase_options.dart` into `main.dart`** (if you want to run
   on macOS / Windows / web). Edit `lib/services/firebase_init.dart` and
   pass `options: DefaultFirebaseOptions.currentPlatform` to
   `Firebase.initializeApp()`. Android and iOS pick up the platform
   bundle automatically; the other platforms require the generated
   Dart options.

## Running against Typesense Cloud

The production Kineograph app points at a Typesense Cloud cluster. The
search-only API key for that cluster is documented in the production
maintainer's notes, not in this repo. Once you have it:

```bash
flutter run \
  --dart-define=TYPESENSE_HOST=<cluster-host>.a1.typesense.net \
  --dart-define=TYPESENSE_API_KEY=<search-only-key>
```

The home screen will show "Typesense client initialized." and the search
button will be enabled. Type at least two characters to trigger a query
(the 500ms debounce and 2-character minimum are deliberate cost levers
documented in `lib/services/search/typesense_service.dart`).

## Running against a self-hosted Typesense node

The whole point of this sandbox. Once your node is up and you've created
the collections from `typesense/schemas/` via `typesense/create-collections.sh`:

```bash
flutter run \
  --dart-define=TYPESENSE_HOST=search.your-domain.com \
  --dart-define=TYPESENSE_API_KEY=<search-only-key> \
  --dart-define=TYPESENSE_PROTOCOL=https
```

For an early bring-up where TLS isn't yet terminated:

```bash
flutter run \
  --dart-define=TYPESENSE_HOST=localhost \
  --dart-define=TYPESENSE_API_KEY=<your-key> \
  --dart-define=TYPESENSE_PROTOCOL=http \
  --dart-define=TYPESENSE_PORT=8108
```

These are the **only** four flags that change between Cloud and self-host —
no source edits.

## Provisioning the collections

`typesense/create-collections.sh` creates the four collection types
(`articles`, `scrubbers_library`, `scrubbers_user`, `user_profiles`,
`oa_profiles`) from the schemas in `typesense/schemas/`. Set the admin
key and host first:

```bash
export TYPESENSE_HOST=search.your-domain.com
export TYPESENSE_ADMIN_KEY=<admin-key>
cd typesense && ./create-collections.sh
```

Add `--drop` to force-recreate.

To sync Firestore data into the new collections, install the Firebase
Extension `typesense/firestore-typesense-search@2.1.0` five times — once
per `extensions/typesense-sync-*.env` file in this repo. Each `.env`
declares which Firestore collection it watches and which Typesense
collection it writes to.

## What is NOT in this sandbox

This sandbox does **not** include:

- Scrubber editing (onion-skin canvas, frame transforms, staging).
- Article editing (rich-text composer, scrubber picker, vote affordances).
- IAP / Steam / Discord / GitHub / Apple / Google sign-in beyond anonymous.
- Account linking & merging.
- Content moderation, voting, comments.
- Admin tools, notification system.
- The raster editor (Drawpile FFI) and pretext text layout engine.
- The `syncUserProfile` Cloud Function that maintains `user_profiles` for
  search — that's the **write path**; this sandbox only exercises the
  **read path**.
- Premium / entitlement gating (everything is treated as "free, public,
  visible").
- The R2 / Cloudflare CDN image pipeline (thumbnails in result tiles
  reference whatever `photoUrl` Typesense returns; broken URLs show as
  fallback icons).

If you find yourself needing one of these to validate a search regression,
flag it back to the maintainer — extending this sandbox is preferable to
forking pieces out of the production app.

## More

The full hand-over workflow (Firebase access provisioning, what to test,
how to report findings) lives in [`docs/COLLABORATOR_GUIDE.md`](docs/COLLABORATOR_GUIDE.md).
Security-review notes are in [`docs/SECURITY_CHECKLIST.md`](docs/SECURITY_CHECKLIST.md).
