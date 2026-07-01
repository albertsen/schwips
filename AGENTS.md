# AGENTS.md

Instructions for AI coding agents working in this repository. See `README.md` for the human-facing overview.

## What this is

Schwips is a personal wine-cellar inventory app. SvelteKit (TypeScript) + SQLite via Drizzle ORM. The UI is entirely German; all code, identifiers, comments, and DB column/table names are English. Never hardcode a German string in a component — resolve it through `src/lib/i18n/de.ts`.

## Runtime data lives outside the app

`runtime/` (containing `runtime/data/schwips.db`, `runtime/photos/`, `runtime/incoming/`, `runtime/incoming/review/`) is entirely gitignored and created automatically:

- `src/lib/server/runtime-dirs.ts` exports the path constants and `ensureRuntimeDirs()`.
- `src/lib/server/db/index.ts` calls it and runs pending Drizzle migrations before opening the DB, as a module-level side effect — so importing that module from *anywhere* (a route, the import CLI, the seed script) is enough to bootstrap everything.
- `src/hooks.server.ts` also calls `ensureRuntimeDirs()` at startup, so it's covered even for requests that never touch the DB module.

Never hardcode `'data/...'`, `'photos/...'`, or `'incoming/...'` path literals — import the constants from `runtime-dirs.ts` instead. If you add a new script or route that touches these paths, make sure it goes through that module (or imports `db/index.ts`, which triggers it as a side effect).

## The import pipeline

`scripts/import.ts` (`npm run import -- <review-json>`) is the **only** code path that writes wines/bottles/photos to the DB. It validates against `src/lib/import/zod.ts`, runs the whole batch in one transaction, and only moves photos out of `runtime/incoming/` into `runtime/photos/<wine_id>/` after the transaction commits. Anything else that needs to create wine data must produce a review JSON matching `reviewFileSchema` and run it through this CLI — don't add a second DB-writing code path.

The `/import-wines` Claude Code command (`.claude/commands/import-wines.md`) reads label photos, researches missing fields, writes a review JSON + human-readable Markdown pair to `runtime/incoming/review/`, and then runs the import CLI itself — it does not wait for manual approval before writing. The review Markdown (with embedded photo links and an `open_questions` list) is kept as an after-the-fact record, not a pre-write gate. If you touch this command file, preserve that: generate the artifact, then import immediately.

## Data model essentials

- `wines` (the product: producer, vintage, grapes, appellation, quality tier, drinking window, ...) is separate from `bottles` (the physical stock: one row per bottle, `status: in_stock|consumed|gifted`). Inventory count for a wine = count of its `in_stock` bottles.
- Dedup is signature-based: `wines.wineSignature` is a normalized composite key (`src/lib/signature.ts::computeSignature`) of producer/vintage/appellation/vineyard/name/quality_level/wine_type/sorted canonical grapes. A new bottle whose wine hashes to an existing signature increments stock on the existing wine instead of creating a duplicate. If you rename a field that feeds the signature (e.g. bulk-editing `producer` across existing rows), you must recompute `wine_signature` for affected rows or future imports will silently stop matching them.
- `wines.quality_level` holds only the bare legal/classification tier (e.g. `DOCG`, `AOC`, `VDP.Erste Lage`, `Deutscher Prädikatswein`) — not combined with a specific name. `wines.appellation` holds the specific named designation (e.g. `Brunello di Montalcino`, `Saint-Estèphe`, `Bierzo`). Keep these two non-overlapping; don't fold the tier back into the name or vice versa.
- Grape varieties: `grapes` (canonical, German-preferred name) + `grape_aliases` (synonyms, e.g. Pinot Grigio → Grauburgunder) + `wine_grapes.label_name` (as printed on the label) + `wine_grapes.percentage`. New varieties are created on the fly by the import CLI if not already present.
- `wines.data_sources` is a JSON map of field name → `'label' | 'research' | 'user'`, plus `wines.import_confidence` (0..1). Preserve this provenance tracking on any new field you add to the wine model.

## Known intentional Drizzle workaround

A raw `sql` template used as a correlated subquery renders unqualified column names and mis-binds to the wrong table (verified bug, not a hypothesis). Where you need an aggregate per row (e.g. bottle count per wine), use a grouped `SELECT ... GROUP BY` query plus a JS `Map` for the join instead of a correlated subquery — see `src/routes/+page.server.ts` and `src/routes/trinkfenster/+page.server.ts` for the pattern.

## Before you're done

Run `npm run check` (svelte-check) after any TypeScript/Svelte change. There's no automated test suite; verify DB-affecting changes by querying `runtime/data/schwips.db` directly (`sqlite3` or a throwaway `node -e` script) and verify UI changes against the running dev server (`npm run dev`, then `curl`/browser).
