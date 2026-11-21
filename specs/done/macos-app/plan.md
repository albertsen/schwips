# macOS App — Plan

## Current State (audited 2026-11-21)

- **Toolchain:** Xcode 27.2 (27B52), Swift 6.4.2, `sqlite3` 3.54.0. Identity "Apple Development" (U4QMFKCJC7), team `3PT9KVM9AJ`. No profile needed: without iCloud the app uses no restricted entitlement.
- **Web data** (`runtime/data/schwips.db`): 45 wines, 70 bottles, 133 photos, 29 grapes, 12 aliases. Dates `YYYY-MM-DD` text, timestamps Unix seconds, three JSON text columns. Photos are files in `runtime/photos/<file_path>`, about 2.3 MB each.
- **Import rules** (`webapp/scripts/import.ts`, `webapp/src/lib/import/zod.ts`): grapes and aliases first; `match_existing` reuses the wine unchanged; else signature match, earlier bottles of the batch included; only a new wine's first photo is primary. The CLI never checks photos exist before committing; the app must.
- **Signature** (`webapp/src/lib/signature.ts`): `ä ö ü ß` fold before NFKD; canonical grapes sorted.
- **Repo:** the web app is in `webapp/` (runtime at `../runtime`), the package in `app/`. `.claude/settings.json` allows all of `Bash`.

## Research

- **SwiftData on SQLite** (Core Data format): entity `Wine` is table `ZWINE`, attribute `producer` column `ZPRODUCER`, a to-one `wine` column `ZWINE` holding `Z_PK`; a `Date` is REAL seconds since 2001-01-01 (+978307200 for Unix); many-to-many adds join tables; WAL mode. Source: Core Data Programming Guide, "Persistent Store Types"; WWDC23 "Meet SwiftData".
- **Container protection** (macOS 14+): reading another app's container prompts once. Source: WWDC23 "What's new in privacy".
- **Sandbox folder access:** entitlements `files.user-selected.read-write` and `files.bookmarks.app-scope`, a security-scoped bookmark. Source: App Sandbox Design Guide, "Security-Scoped Bookmarks".
- **Folder watching:** a `.write` `DispatchSource` on a directory fires on added, renamed or removed entries, not on content changes. Source: Dispatch docs, `DISPATCH_VNODE_WRITE`.
- **URL scheme:** `CFBundleURLTypes` plus `.onOpenURL`. `handlesExternalEvents(matching:)` stops a second window from opening. Source: SwiftUI docs.
- **Photo shrinking:** `CGImageSourceCreateThumbnailAtIndex` (max pixel size, `WithTransform` for EXIF rotation), `CGImageDestination` JPEG. Source: ImageIO docs.
- **SQLite3** ships in the macOS and iOS SDKs: no dependency.

## Decisions

1. **Buchhalter's architecture** (its architecture.md: Targets, Layout, Localization, Decisions 1–5, 8–10, 12), SwiftPM + `make` in `app/`; the SvelteKit app in `webapp/`. The targets are `SchwipsCore` (Foundation, SwiftData, ImageIO), `SchwipsWebCellar` (SQLite3; reads the web app's DB once), the executable `Schwips` (`App/` and `Views/` shared, `Mac/` Mac-only, `defaultIsolation(MainActor)`) and the test targets. Platforms are `.macOS("27.0")` and `.iOS("27.0")`.
2. **CloudKit-shaped `SchemaV1` from the first commit:** every attribute optional or defaulted, enums stored as raw `String`, no `.unique`, every relationship optional with an inverse, photos `.externalStorage`, inside one `SchemaMigrationPlan`.
3. **A flat store for `sqlite3`.** No many-to-many relationships (grapes go through a `WineGrape` join entity), and the three JSON fields are `String` attributes holding JSON. The commands query plain columns and `json_extract`.
4. **Wine number:** `Wine.number: Int`, web id on copy, max+1 on create, unique by the operations. Sync must revisit it (two devices, one number).
5. **Dates:** a drunk date or purchase date is a `Date` at local noon of that day, so a time-zone change can't move it to another day.
6. **`Cellar` holds every write** (Buchhalter `Library`): rating, field edits, bottles, the import and the web copy. `Cellar.change` uses snapshot undo (Buchhalter Decision 12). Snapshots hold wine scalars and bottles only, never photo bytes. The import and the copy save without registering undo.
7. **One importer for both sources.** `CellarImporter` takes value types (review file, or the web cellar in the same shape plus numbers, ratings, drunk bottles). Order: validate everything → shrink photos `@concurrent` → insert on the main context → one `save()` (rollback on error) → only then delete the originals from `incoming/`. The web copy never deletes anything.
8. **Photos shrink to 2400 px JPEG 0.85** on import and on copy (user's choice), plus a 240 px thumbnail attribute for the detail strip.
9. **The import ledger is in the store:** `ImportRecord` (file name, file modification date, status `imported|failed|skipped`, message, counts). It decides new-or-changed, feeds banner and Settings, and `/import-wines` polls it by file name. Choosing a folder records existing files as `skipped`.
10. **`ReviewInbox`** (app, `@MainActor @Observable`) owns the bookmark, the DispatchSource and a 1 s debounce. It rescans at launch and when the app becomes active, and imports `*.json` oldest first. Invalid JSON modified under 10 s ago is retried 3× every 2 s before failing (still being written).
11. **Lists, facets, search and sort run in the core over fetched arrays** (Buchhalter Decision 10): `CellarQuery` → results, counts, facet options. Text comparison and folding use `de_DE`, ignoring case and diacritics; search covers labels and canonical grape names.
12. **In-place editing** follows Buchhalter's `Views/Detail/InlineFields.swift`. The rules live in `WineField` (parse, validate, format) and `Cellar.set(_:to:on:)`, which records provenance `user`, recomputes the signature for identity fields and applies a price to every bottle.
13. **Window state** in `@AppStorage` (list, filters as JSON, sort, selected number). Photo viewer: `WindowGroup(for: PhotoTarget)`.
14. **Signing:** `make app` signs with "Apple Development", hardened runtime and the sandbox entitlements, no profile. Bundle id `de.juergenalbertsen.schwips`. `$SCHWIPS_HOME` moves the store, for agent runs.

## Components

All new unless marked.

- In `app/`: `Package.swift`, `Makefile` (`build`, `app`, `install`, `test`, `strings`, `icon`), `Resources/Info.plist` (URL type `schwips`), `Resources/Schwips.entitlements`, `Resources/Localizable.xcstrings`, `Scripts/make-icon.swift` → `Resources/AppIcon.icns`. Changed: `.gitignore` (`.build/`, `build/`).
- `SchwipsCore/Model`: `SchemaV1` with `Wine`, `Bottle`, `WineGrape`, `Grape`, `GrapeAlias`, `Photo`, `ImportRecord`; `Enums.swift` (WineType, WineColor, Sweetness, Closure, BottleStatus, Provenance). The description field is `notes`.
- `SchwipsCore/Store`: `CellarContainer` (store URL, `$SCHWIPS_HOME`), `Cellar` + `CellarSnapshot` (undo), `BottleOperations`, `FieldOperations`, `CellarImporter`, `GrapeSeed` (the list from `webapp/scripts/seed-grapes.ts`, used by Start Empty).
- `SchwipsCore/Logic`: `Signature` (exact port), `CellarQuery`, `TextFolding`, `WineField`, `CellarFormatting` (prices, years, ranges, plurals with an explicit `Locale`), `PhotoShrinker`.
- `SchwipsCore/Import`: `ReviewFile` (Codable mirror of `reviewFileSchema`), `ReviewValidation` (turns `DecodingError` and range checks into "Bottle 2: “vintage” must be a whole number."), `ImportSummary` (banner text).
- `SchwipsWebCellar/WebCellarReader`: opens `data/schwips.db` read-only (`SQLITE_OPEN_READONLY`), returns value types plus the photo paths.
- `Schwips/App`: `ReviewInbox`, `RuntimeFolder` (bookmark, state found/missing), `WebCopyModel` (progress, all or nothing), `URLRouter` (`schwips://wine/N`).
- `Schwips/Views`: one view per design artboard area (`RootView`, `Sidebar`, `WineList`, `WineDetail`, `BottleSection`, `InlineFields`, `ImportBanner`, `EmptyStates`, `PhotoViewer`, `WelcomeSheet`, `SettingsView`).
- `Schwips/Mac`: `SchwipsMacApp` (`@main`, scenes, Wine menu, keys), `AppDelegate` (URL events).
- Changed: `.claude/commands/import-wines.md` (no `npm run import`; writes the pair, then polls `ZIMPORTRECORD` for up to 30 s and reports; alias and signature queries go to the app's store) and `.claude/commands/recommend.md` (stock from the app's store, `schwips://wine/<number>` links). Both use `sqlite3 -readonly` on the container's `Application Support/Schwips/Schwips.store`, with the column names from Testing step 2.

## Testing

`swift test`, in-memory containers, one file per area:

- `SignatureTests`: equal to the web DB's `wine_signature` for every wine in `Fixtures/signatures.json` (exported once from the web DB).
- `ReviewFileTests`: the current review file in `runtime/incoming/review/` decodes; every kind of wrong field gives its message with the bottle's position.
- `ImporterTests`: `match_existing` by number, signature dedup inside one batch, new grapes and learned aliases, a missing photo fails the whole file, a failed file leaves nothing behind, numbers continue from the maximum.
- `WebCellarTests`: a temporary DB built from `webapp/drizzle/0000_petite_the_hand.sql` and `0001_round_magneto.sql` with sample rows copies with numbers, drunk bottles, ratings and provenance intact.
- `CellarQueryTests`: lists, facets excluding their own filter, search folding and label names, sort with missing values last.
- `FieldOperationTests`: validation limits, provenance `user`, signature recompute, price on every bottle, an empty winery refused.
- `UndoTests`: each action undoes and redoes, named and persisted.
- `PhotoShrinkerTests`: 2400 px, EXIF orientation, small images unscaled.
- `LocalizationCatalogTests` (Buchhalter's).

**Order with a stop point:** (1) core and tests green. (2) Build, run the binary once with `SCHWIPS_HOME` set to a scratch folder, read `.schema` of the scratch store and write the real table and column names into both commands. (3) Finish the views, `make app`, stop: "The app is ready for testing." The user runs the first launch and copy.

## Risks

- The DispatchSource also fires for the `.md`, for temp files and for the app's own deletions. Filter to `*.json`, and never import while an import is running.
- The security scope must stay open for the app's lifetime. Stopping it early breaks watching silently.
- `sqlite3` without `-readonly` while the app has the store open can take a write lock, and then the app's next `save()` fails.
- `Wine.description` would shadow `CustomStringConvertible`; hence `notes`.
