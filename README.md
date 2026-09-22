# Noteflow

An offline-first notes & checklist app for Android, built with Flutter.

Noteflow is a privacy-focused, local-first notes app: text notes and checklists,
colours, categories, pinning, archive, trash, search, calendar, local reminders,
app lock, and backup/restore — all working without any account, backend, or cloud
database. It draws on the familiar usability of classic sticky-note apps while
using an entirely original design, brand, and codebase.

## Principles

- **Offline-first** — all core features work with no internet. No custom backend,
  no REST API, no cloud database, no login.
- **Local-first storage** — everything persists in an on-device SQLite database
  (via Drift) and Android secure storage for secrets.
- **Privacy** — note content never leaves the device. Third-party services
  (ads, Play Billing) are clearly scoped and optional to the core experience.

## Tech stack

| Concern | Choice |
|---|---|
| Language / UI | Flutter (Dart 3.4) |
| State management | Riverpod |
| Local database | Drift (SQLite) |
| Navigation | go_router |
| Local notifications | flutter_local_notifications + timezone *(Phase 5)* |
| Security | local_auth + flutter_secure_storage *(Phase 6)* |
| Monetization | google_mobile_ads + in_app_purchase *(Phase 9)* |

## Project structure

```
lib/
  core/          app-wide config: theme, router, providers
  data/
    local/       Drift database + table definitions
    repositories/ typed data access (settings, notes, …)
  domain/
    entities/    enums and domain models
  features/
    home/        notes home screen
    settings/    settings + preferences
    …            (notes, checklist, calendar, reminders, security, backup, billing)
  shared/
    widgets/     reusable UI (empty states, …)
  main.dart
```

## Build & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generate Drift code
flutter run                                                  # on a connected Android device
```

Regenerate database code whenever `lib/data/local/tables.dart` changes.

## Testing

```bash
flutter test
```

> Database-backed tests require the `sqlite3` native library. On desktop hosts
> that don't ship it, those tests skip with a clear reason and run in full
> on-device / on CI images that provide sqlite3.

## Configuration before release

Secrets are never committed. Before a release build you must supply:

- **Signing** — `android/key.properties` + a keystore (git-ignored).
- **AdMob** — your application ID and ad unit IDs *(Phase 9)*.
- **Play Billing** — the `Lifetime Remove Ads` product ID configured in the
  Play Console *(Phase 9)*.

## Status

Built incrementally in phases. **Phase 1 complete:** architecture, theme,
navigation, and the local database schema for all planned entities.

## Contact

Aakash Mangukiya — aakashmangukiya10@gmail.com
