# AGENTS.md

Instructions for AI coding agents working in this repository. See `README.md` for the human-facing overview.

## What this is

Schwips is a personal wine-cellar inventory app: a native Mac app in SwiftUI over a SwiftData store, built so an iOS app can follow. The UI is in English and German; all code, identifiers, comments and stored values are English. New bottles arrive through the `/import-wines` Claude Code command, which writes review files that the app imports.

## Layout

- `app/`: the Swift package (SwiftPM + `make`). Targets: `SchwipsCore` (Foundation, SwiftData, ImageIO: model, operations, import, query logic; unit-tested), `SchwipsWebCellar` (SQLite3: reads the old web app's database once, for the copy), the executable `Schwips` (`App/` and `Views/` shared, `Mac/` Mac-only, `@MainActor` by default), `SchwipsCoreTests` (Swift Testing, fixtures read through `#filePath`). Platforms are macOS 27 and iOS 27.
- `app/Resources/`: `Info.plist` (URL scheme `schwips`), `Schwips.entitlements`, `Localizable.xcstrings`, `AppIcon.icns` (drawn by `app/Scripts/make-icon.swift`).
- `runtime/`: gitignored, at the repository root. `runtime/incoming/` takes label photos, `runtime/incoming/review/` the review files; `runtime/data/schwips.db` and `runtime/photos/` hold the old web app's cellar, read once by the copy on first launch.
- `.claude/commands/`: `import-wines.md`, `recommend.md`.

## Build and run

Toolchain: Xcode 27.2, Swift 6.4.2, macOS 27 SDK. In `app/`:

| Command | Result |
|---|---|
| `make app` | `build/Schwips.app`: sandboxed, hardened runtime, signed with "Apple Development" (team `3PT9KVM9AJ`), no provisioning profile (no restricted entitlement yet) |
| `make install` | Copies it to `/Applications/Schwips.app`. Only on the user's request |
| `make test` / `swift test` | The core tests, including the catalog test |
| `make strings` | Syncs the texts the compiler finds into `Resources/Localizable.xcstrings`; new keys need English and German values |
| `make icon` | Redraws `Resources/AppIcon.icns` |

Bundle id `de.juergenalbertsen.schwips`. The store is `~/Library/Containers/de.juergenalbertsen.schwips/Data/Library/Application Support/Schwips/Schwips.store` (photos in its external storage). `$SCHWIPS_HOME` moves the store to a scratch folder; the user tests on the real store, so agents never start the app on it.

## The runtime folder and imports

- On first launch the user chooses the `runtime` folder; the app keeps it as a security-scoped bookmark and keeps access open for its lifetime (`App/RuntimeFolder.swift`). Settings can change it.
- The app is the **only** writer of the store. `App/ReviewInbox.swift` watches `incoming/review/` (DispatchSource plus a rescan at launch and activation) and imports each new `*.json` once, oldest first. A file that isn't complete JSON and changed in the last 10 s is retried before it fails.
- An import is all or nothing (`CellarImporter`): decode and validate (`ReviewValidation`, messages like "Bottle 2: “vintage” must be a whole number."), check and shrink the photos off the main actor (`PhotoShrinker`: JPEG, 2400 px, quality 0.85, plus a 240 px thumbnail), insert, one save, and only then delete the originals from `incoming/`. Never delete photos before the save succeeded.
- `ImportRecord` is the ledger, one per file name: `imported`, `failed` or `skipped` (files already in the folder when it was chosen). A failed file is retried by Try Again or when the file changes; an imported one never again.
- The review JSON's shape is documented in `.claude/commands/import-wines.md` and mirrored by `Import/ReviewFile.swift`; keep the two in step.
- The copy of the old web cellar (`Cellar.copyWebCellar`) runs only into an empty cellar, keeps every wine's number and recomputes match keys (the web app's stored keys were stale).

## Data model essentials

- `Model/SchemaV2.swift` is current; `SchemaV1` is frozen. The model follows CloudKit's rules from the start: every attribute optional or defaulted, enums as `String` raw values, no `.unique`, optional relationships with inverses, photos `.externalStorage`. A schema change is a new `VersionedSchema` plus a stage in `SchwipsMigrationPlan`, never an edit of a shipped one. `MigrationTests` opens a V1 store.
- `Wine` (the product) is separate from `Bottle` (one per physical bottle, `statusRaw`: `in_stock`, `consumed`, `gifted`). Stock = bottles in stock.
- `Wine.number` is the wine's number: the web app's id for copied wines, max + 1 for new ones, unique by the operations. Review files (`match_existing`) and `schwips://wine/<number>` links use it.
- Dedup is signature-based: `Wine.signature` is `Signature.compute` (an exact port of the web app's `computeSignature`, checked against it in `SignatureTests`) over producer, vintage, appellation, vineyard, name, quality level, wine type and the sorted canonical grapes. Editing an identity field recomputes it; any other path that changes those fields must too.
- `qualityLevel` holds only the bare tier (`DOCG`, `VDP.Erste Lage`); `appellation` the named designation (`Brunello di Montalcino`). Keep them non-overlapping.
- Grapes: `Grape` (canonical, German-preferred) + `GrapeAlias` + `WineGrape` (ordered join with `labelName` and `percentage`). No many-to-many relationships, so the store stays plain columns for `sqlite3`.
- `Wine.notes` is the description; `Wine.userNotes` the user's own notes. `dataSourcesJSON` maps field names to `label`, `research` or `user`, plus `importConfidence`. Preserve provenance on any new field; edits in the app mark the field `user`.
- Dates of drunk and purchased bottles are calendar days stored at local noon (`Day`).

## Code rules

- Logic that runs without a display goes into `SchwipsCore` with tests. Views read with `@Query` and change data only through `Cellar` operations.
- Undo: `Cellar.change` runs one user action as one named undo step from value snapshots and writes back only the difference (`CellarSnapshot`, `CellarDiff`). SwiftData's own undo is not used: on macOS 27.2 an undone change is never saved. Imports and the copy are not undoable. A new undoable field must be added to `CellarSnapshot.WineRecord` or `BottleRecord`.
- Lists, filters, search and sort run in memory over fetched wines (`CellarQuery`), with German collation and folding (`TextFolding`).
- Every user-visible text exists in English and German in the one String Catalog; keys are the English text (semantic keys with a default where one English text needs two German ones, e.g. `chip.readyToDrink`). `LocalizationCatalogTests` fails on a missing or untranslated value or a plural without `one` and `other`. Prices, numbers and days go through `CellarFormatting` with an explicit locale.
- Shared views compile for iOS: AppKit only inside `#if os(macOS)` or in `Mac/`; Mac-only styles are mapped in `Views/Common/PlatformStyles.swift`.
- No third-party dependencies without asking.

## Claude Code reads the store

`/import-wines` (aliases, match keys, the import ledger) and `/recommend` (stock) read the store with `sqlite3 -readonly`, never writing; without `-readonly` a lock can make the app's save fail. Tables follow Core Data naming: `ZWINE` (`ZNUMBER`, `ZPRODUCER`, `ZSIGNATURE`, `ZNOTES`, `ZUSERNOTES`, …), `ZBOTTLE` (`ZWINE` → `ZWINE.Z_PK`, `ZSTATUSRAW`), `ZWINEGRAPE`, `ZGRAPE`, `ZGRAPEALIAS`, `ZIMPORTRECORD`, `ZPHOTO`; dates are seconds since 2001-01-01. A new or renamed model property changes these columns: update both command files. macOS asks once whether the terminal may read another app's data.

`/import-wines` writes the review Markdown, then the JSON, and polls `ZIMPORTRECORD` for up to 30 s to report the result; it does not wait for approval before writing. `/recommend` always answers in German and links each wine as `schwips://wine/<number>`, which selects it in the app.

## Before you're done

Run `swift test` in `app/` after any change to `SchwipsCore`, and `make app` after any app change; fix warnings. After adding texts run `make strings` and add both languages. The user tests every UI change by hand on the real store: build, then say the app is ready for testing.
