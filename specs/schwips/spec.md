# Schwips

Track a personal wine collection with bottle-level inventory, where new bottles are added by Claude Code reading label photos, researching, and importing them after a human review step.

## Problem

1. Manually entering each wine (producer, vintage, grapes, drinking window, tasting data) into a spreadsheet or generic wine app is tedious and error-prone.
2. Label data alone is incomplete. Enriching it (drinking window, grape composition, ratings, region facts) requires separate manual research per bottle.
3. Existing wine apps don't let you drive ingestion from photos via an LLM, and they don't cleanly separate the *product* (a wine) from the *physical stock* (individual bottles), which is what inventory actually tracks.

## Goals

- `npm run dev` serves the app on `localhost` with a fully German UI.
- Drizzle schema and migrations live under `src/lib/server/db/`; `npm run db:migrate` applies them to `data/schwips.db`.
- The Claude Code command `/import-wines` produces a review artifact from `incoming/` **without touching the DB**.
- `npm run import -- <review-json>` validates the confirmed JSON, inserts `wines`/`bottles`/`photos` transactionally, and moves photos into `photos/<wine_id>/`.
- Inventory count for a wine equals the number of `bottles` rows for that wine with `status = 'in_stock'`.
- Re-importing the same wine offers "increment stock" (insert a new `bottles` row against the existing `wines` row) rather than creating a duplicate wine.
- A Drizzle-defined schema is the single source of truth, shared verbatim by the web app and the import CLI.

## Non-goals

- No multi-user account management, no user table, no roles. Future hosting uses ONE shared password via an auth-hook seam only.
- No fully-automated or unattended import. The human review step is mandatory; vision output never auto-writes to the DB.
- No mobile-native app. Responsive server-rendered web is sufficient.
- No barcode or hardware OCR-scanner integration.
- No cloud sync and no external hosted DB in v1. The datastore is a single SQLite file.
- No purchase/price tracking beyond the simple per-bottle fields listed below.
- No automatic price or market-value updates from external APIs.

---

## Design

### Stack and layout

SvelteKit full-stack (UI plus server routes and form actions for a small internal API), TypeScript throughout. SQLite as the datastore, a single file at `data/schwips.db`. Drizzle ORM defines the schema and Drizzle Kit runs migrations. All implementation code, identifiers, comments, table names, and column names are **English**. The end-user UI is **German**: every user-facing string is resolved through a German i18n dictionary (see [i18n](#i18n)); no German literals are hardcoded in components.

```
schwips/
  data/
    schwips.db                # SQLite datastore (gitignored)
  incoming/                   # flat photo inbox (iPhone drops)
    review/                   # generated review artifacts
  photos/                     # imported photo library, per wine
    <wine_id>/
  scripts/
    import.ts                 # deterministic import CLI
  src/
    lib/
      server/
        db/
          schema.ts           # Drizzle schema — single source of truth
          index.ts            # db client
          migrate.ts
        auth.ts               # auth-hook seam (see below)
      i18n/
        de.ts                 # German dictionary
      signature.ts            # wine_signature normalization (shared)
      import/
        zod.ts                # Zod schemas mirroring Drizzle
    hooks.server.ts           # handle() hook, wires auth seam
    routes/
      +page.svelte            # Bestand (inventory list)
      wine/[id]/+page.svelte  # wine detail
      trinkfenster/+page.svelte
  drizzle.config.ts
  package.json
```

`package.json` scripts:

```
"dev": "vite dev",
"db:migrate": "tsx src/lib/server/db/migrate.ts",
"db:generate": "drizzle-kit generate",
"import": "tsx scripts/import.ts"
```

### Auth seam

A future single-login deployment uses one shared password and no user management. Build only the seam now, not the login UI.

`src/lib/server/auth.ts` exports `isAuthEnabled()` (reads env `SCHWIPS_AUTH_PASSWORD`; disabled when unset) and `verifySession(cookie: string): boolean` comparing a signed session cookie against the one configured password. `src/hooks.server.ts` implements `handle`: when auth is disabled (local mode, the default) it is a no-op passthrough; when enabled it checks the session cookie and, for unauthenticated requests, would redirect to a login route. The login route and its UI are out of scope for v1 — the hook, env var, and cookie check are the only artifacts. No `users` table exists or is planned.

### Data model

Drizzle schema in `src/lib/server/db/schema.ts`, snake_case columns. Core principle: separate the **wine** (product/metadata, one row per distinct wine) from the **bottle** (a physical instance). Inventory is a COUNT of `bottles`, never a quantity column on `wines`.

#### `wines`

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `producer` | text | Weingut |
| `name` | text null | proprietary/cuvée name printed by the winery (e.g. "GG", "Fumé"); may be null; NOT the identity by itself |
| `vintage` | integer null | Jahrgang; null for NV sparkling |
| `wine_type` | text | Art (e.g. Sekt, Kabinett, Spätlese, Auslese, GG, Landwein); suggested enum, free-ish |
| `color` | text | Farbe: `white` \| `red` \| `rose` \| `orange` |
| `sweetness` | text | Geschmack: `dry` \| `off-dry` \| `medium` \| `sweet` \| `noble-sweet` |
| `quality_level` | text | e.g. QbA, Prädikatswein, VDP.Gutswein/Ortswein/Erste Lage/Große Lage |
| `region` | text | Anbaugebiet (broad, e.g. Toskana, Rheinhessen) |
| `country` | text | |
| `appellation` | text null | Herkunftsbezeichnung / appellation (e.g. Chianti Classico, Bordeaux, Rioja); may be the only origin/identity marker for Old-World wines without printed grapes |
| `vineyard` | text null | Einzellage/Weinlage |
| `abv` | real | alcohol % |
| `residual_sugar_gl` | real null | g/l |
| `acidity_gl` | real null | g/l |
| `drink_from` | integer null | year |
| `drink_until` | integer null | year |
| `description` | text | Beschreibung, long text |
| `food_pairing` | text | Speiseempfehlung |
| `serving_temp_c` | text | range like `"10-12"` |
| `closure` | text | Verschluss: `cork` \| `screwcap` \| `glass` \| `crown` |
| `is_organic` | integer (bool) | |
| `is_vegan` | integer (bool) | |
| `external_links` | text (JSON) | array of URLs found during research |
| `extra_data` | text (JSON) | structured catch-all for label facts with no dedicated column (barrel aging, hand-harvest, bottling number, awards) |
| `data_sources` | text (JSON) | per-field provenance map `field_name -> "label" \| "research" \| "user"` |
| `import_confidence` | real | 0..1, model confidence in the record |
| `wine_signature` | text | normalized soft matching key (see [Identity](#wine-identity-and-dedup)) |
| `created_at` | integer (ts) | |
| `updated_at` | integer (ts) | |

`wine_signature` is indexed (non-unique) for match lookups.

#### `grapes`

One row per **canonical** grape variety. A grape's botanical identity is separate from the name printed on a label: Grauburgunder, Pinot Gris, Pinot Grigio, and Ruländer are the same variety. The canonical `name` is the common **German** name where one exists (`Grauburgunder`, `Spätburgunder`, `Weißburgunder`); otherwise the internationally common name (`Nebbiolo`, `Sangiovese`). Cross-language and regional variants live in `grape_aliases`.

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `name` | text unique | canonical German-preferred variety name (Rebsorte) |
| `color` | text | `white` \| `red` (for filtering) |

#### `grape_aliases`

Maps every synonym / regional / cross-language spelling to its canonical grape, so the importer resolves a printed name to one variety instead of creating duplicates.

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `grape_id` | integer fk -> `grapes.id` | |
| `alias` | text unique | e.g. `Pinot Grigio`, `Pinot Gris`, `Ruländer` -> Grauburgunder |

Seed with common German↔international pairs: Grauburgunder = Pinot Gris/Grigio/Ruländer; Weißburgunder = Pinot Blanc/Bianco/Klevner; Spätburgunder = Pinot Noir/Nero/Blauburgunder; Müller-Thurgau = Rivaner; Zweigelt = Blauer Zweigelt.

#### `wine_grapes`

| column | type | notes |
| --- | --- | --- |
| `wine_id` | integer fk -> `wines.id` | |
| `grape_id` | integer fk -> `grapes.id` | canonical variety |
| `percentage` | real null | optional share |
| `label_name` | text null | the name exactly as printed on THIS bottle's label (e.g. `Pinot Grigio`), preserved for display/provenance |

Primary key `(wine_id, grape_id)`. Filtering/grouping uses the canonical `grape`; display uses `label_name ?? grape.name`.

#### `bottles`

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `wine_id` | integer fk -> `wines.id` | |
| `bottle_size_ml` | integer default 750 | also 375, 500, 1500 magnum, etc. |
| `location` | text | Lagerort, free text like `"Keller, Regal 3, Fach B"` |
| `purchase_date` | integer (date) null | |
| `purchase_price` | real null | EUR |
| `purchase_vendor` | text null | |
| `current_value` | real null | EUR |
| `status` | text | `in_stock` \| `consumed` \| `gifted` |
| `consumed_date` | integer (date) null | |
| `personal_rating` | integer null | 1..5 |
| `created_at` | integer (ts) | |
| `updated_at` | integer (ts) | |

#### `photos`

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `wine_id` | integer fk -> `wines.id` | |
| `file_path` | text | relative, under `photos/<wine_id>/` |
| `is_primary` | integer (bool) | |
| `created_at` | integer (ts) | |

#### `tasting_notes`

Linked to a bottle so a note records the specific bottle that was drunk.

| column | type | notes |
| --- | --- | --- |
| `id` | integer pk | |
| `bottle_id` | integer fk -> `bottles.id` | |
| `tasted_on` | integer (date) | |
| `rating` | integer null | 1..5 |
| `note` | text | |
| `created_at` | integer (ts) | |

### Wine identity and dedup

A wine's identity is **not** `name`. It is a composite natural signature derived from `producer` + `vintage` + `appellation` + `vineyard` + grape composition + proprietary `name` (if any) + `quality_level` + `wine_type`. Including `appellation` means an Old-World wine without any printed grape (e.g. a Chianti) still gets a stable, distinguishing signature. `src/lib/signature.ts` exports `computeSignature(wine)` producing `wine_signature`: lowercased, whitespace-collapsed, diacritics-folded (`ü`→`u`, `ß`→`ss`, etc.) concatenation of those fields with a stable separator. The grape composition uses the **canonical** grape names (resolved via `grape_aliases`), never the label spelling — so a Grauburgunder and a "Pinot Grigio" of the same wine yield an identical signature. The same function is used by the web app (on write) and the import CLI, so signatures are always consistent.

Dedup is **Claude-assisted, then human-confirmed**. During `/import-wines`, the skill computes a candidate signature per proposed bottle and looks for existing `wines` with a matching or near-matching signature. It writes a proposal into the review artifact: either "matches existing wine #N (signature match) → add a bottle / increment stock" or "new wine". The human confirms or corrects that decision in the review JSON.

Adding another bottle of an existing wine means inserting a new `bottles` row against the existing `wines.id`. The `wines` row is **never mutated** by a stock increment. This is how re-importing the same wine increments stock instead of duplicating the product.

### Import pipeline

The core feature. Fuzzy work (vision, clustering, research, proposing dedup) is done by Claude; deterministic work (Zod validation, dedup execution, DB writes, file moves) is done by the import CLI. Data integrity is enforced in code, not left to the model.

All of Claude's communication with the user during a run — clarifying questions, progress notes, `open_questions`, and the human-readable review markdown — is in **German**, matching the UI language, even though code, identifiers, column names, and stored enum values stay English.

#### Inbox

`incoming/` is a flat inbox. The user drops iPhone photos there directly (e.g. `IMG_5106.jpeg` … `IMG_5144.jpeg`, roughly 39 sequential files per batch). A bottle can have **any number** of photos, not a fixed two or three: front label, back label, capsule, plus several overlapping shots of the same label taken while rotating the bottle to capture wrap-around text. The clusterer must not assume a fixed photo count per bottle.

#### Trigger

A Claude Code custom command `/import-wines`, defined in `.claude/commands/import-wines.md` (skill form under `.claude/skills/` is equivalent). The user runs it manually inside Claude Code.

#### Skill steps

1. List `incoming/` and read all photos.
2. **Cluster photos into bottles.** First use filename ordering — sequential capture numbers imply that photos of the same bottle are adjacent. Then confirm and adjust visually, grouping every photo of the same bottle together — front label, back label, capsule, and any number of rotated/overlapping shots of the same label. A group has **no fixed size**; it can be one photo or many. Produce a proposed grouping and, if the correct grouping is genuinely ambiguous (e.g. two adjacent bottles look alike), flag it as an open question rather than guessing.
3. **Per bottle group:** extract label fields via vision; research missing and enriching data via WebSearch (drinking window, grape %, ratings, region facts); capture anything printed but unmodeled into `extra_data`; record per-field provenance in `data_sources` and an overall `import_confidence`. Labels may be in **any language** (German, Italian, French, English, Spanish, …); extract regardless of label language. Free-text fields (`producer`, `region`, `vineyard`, proprietary `name`, `description`) are stored as printed on the label; controlled fields (`color`, `sweetness`, `closure`, and `wine_type` where it maps) are normalized to the English enum values in the schema. Grape names are resolved to a **canonical variety** via `grape_aliases` (e.g. printed "Pinot Grigio" → canonical `Grauburgunder`), with the printed spelling kept in `wine_grapes.label_name`. A grape that matches no canonical variety or alias is proposed as a new canonical grape or raised as an `open_question` — never silently duplicated.

Some wines print an **appellation instead of grapes** (Chianti, Bordeaux, Rioja, Châteauneuf-du-Pape …). In that case Claude records the `appellation` (provenance `"label"`), and researches the appellation's **typical/legal grape composition** (e.g. Chianti → Sangiovese-dominant), inserting those grapes with provenance `"research"`, `label_name` null, and typical percentages where known. Because the blend is inferred rather than read from the bottle, an `open_question` notes this (e.g. "Rebsorten aus Appellation Chianti abgeleitet, nicht vom Etikett"). `wine_grapes` may also legitimately stay empty; the wine remains fully valid and is identified via `appellation`.
4. **Handle what can't be read.** Claude never silently guesses. If a field is illegible or absent on the photos, it (a) attempts to complete it via WebSearch research (marking that field's provenance `"research"`), and (b) if the value still can't be determined confidently, leaves the field null, lowers `import_confidence`, and records an explicit entry in a per-bottle `open_questions` list (e.g. "Jahrgang auf Kapsel unleserlich — 2019 oder 2021?"). During an interactive run Claude may also ask the user directly for anything it cannot resolve; unanswered items still surface as `open_questions` in the review artifact so nothing uncertain is written blindly.
5. **Write the review artifact.** A per-run pair: `incoming/review/<timestamp>.json` (machine-readable, the input the CLI consumes) plus `incoming/review/<timestamp>.md` (human-readable). Each proposed bottle contains its photo group, the extracted-plus-researched fields, the dedup proposal (new wine vs. match existing wine #N), `import_confidence`, and any `open_questions`. The markdown surfaces low-confidence fields and open questions prominently so the human knows exactly what to check. Claude does **not** write to the DB.
6. **Human review.** The user reads the markdown — resolving any `open_questions` and correcting low-confidence fields — edits the JSON if needed, and confirms the dedup decisions.
7. **Import CLI.** `npm run import -- <review-json>` (equivalently `tsx scripts/import.ts <file>`) validates the confirmed JSON against a Zod schema in `src/lib/import/zod.ts` that mirrors the Drizzle schema, then in a single transaction: upserts `grapes`, inserts or reuses the `wines` row per the confirmed dedup decision, inserts the `bottles` row(s), and records `data_sources`/`import_confidence`. On success it moves the grouped photos from `incoming/` into `photos/<wine_id>/` and inserts `photos` rows. The CLI is the **only** writer to the DB during import.
8. **Photo handling.** On successful import, originals are moved (not copied) from `incoming/` into `photos/<wine_id>/`, linked in `photos`, and displayable in the UI. `incoming/` is left clean for the next batch. If the transaction fails, no files are moved and no rows are written.

### Web UI

Server-rendered SvelteKit, German throughout. All writes go through SvelteKit form actions that call the same Drizzle layer used by the CLI.

- **Bestand (inventory list)** — `/`: all wines with their in-stock bottle counts. Filter and sort by `wine_type`, `region`, `vintage`, drinking window (e.g. "trinkreif jetzt"), and `color`.
- **Wine detail** — `/wine/[id]`: all fields, grape composition, photo gallery, the list of that wine's bottles with status and location, and tasting notes.
- **Actions:** mark a bottle consumed (sets `status = 'consumed'` and `consumed_date`); add a tasting note; edit any field (to correct import mistakes — such edits set the field's provenance to `"user"` in `data_sources`); adjust stock by adding or removing `bottles` rows.
- **Trinkfenster** — `/trinkfenster`: wines whose `drink_from..drink_until` includes the current year, plus a section for wines past their window.

### i18n

`src/lib/i18n/de.ts` holds a flat dictionary keyed by English identifiers, resolving to German strings: e.g. `inventory -> "Bestand"`, `vintage -> "Jahrgang"`, `grape -> "Rebsorte"`, `drinkingWindow -> "Trinkreife"`, `location -> "Lagerort"`, `foodPairing -> "Speiseempfehlung"`, `closure -> "Verschluss"`. Components reference keys, never literals. Enum values stored in the DB stay English (`in_stock`, `dry`, `screwcap`) and are mapped to German labels at the presentation layer only. Only one language ships in v1, but the indirection keeps every German string in one file.
