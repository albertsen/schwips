# Schwips — Implementation Plan

> On any step: if a Verify block returns unexpected output, stop immediately,
> report what was expected vs. what was observed, and wait for instructions.

## Current State (audited 2026-07-01)

### Local codebase
Nothing is scaffolded yet. The repository root `/Users/juergen/dev/schwips` contains only:
- `.claude/` — `settings.json` (Bash/Edit/WebSearch allow rules) and `settings.local.json`.
- `incoming/` — the flat photo inbox (see below).
- `specs/` — contains `specs/schwips/spec.md`.

There is **no** `package.json`, **no** `node_modules/`, **no** `src/`, **no** `data/`, **no** `photos/`, **no** `scripts/`, **no** `drizzle.config.ts`. The entire application must be built from scratch.

### Tooling
- Node `v26.0.0`, npm `11.12.1`, npx `11.12.1`. Node 26 is brand-new; native module builds are the main risk (see Phase 1).
- Platform: macOS (darwin 25.5.0), shell zsh.

### Git
`/Users/juergen/dev/schwips` is **not** a git repository yet. `git init` is Step 1.1.

### Inbox photos
`incoming/` holds 39 sequential iPhone photos: `IMG_5106.jpeg` … `IMG_5144.jpeg` (all lowercase `.jpeg`). These are real bottle labels used for the end-to-end smoke test in Phase 8. Multiple photos belong to one bottle (front / back / capsule); filenames are captured in sequence, so adjacent numbers usually belong together.

### Spec
`specs/schwips/spec.md` exists and is the authoritative design. This is a **greenfield, local-only** project: SvelteKit + SQLite (single file `data/schwips.db`) + Drizzle. There is no cloud, no AWS, no external DB, no hosting in v1.

---

## Phase 1 — Project scaffold, git, tooling

### Step 1.1 — Initialize git

Version control must exist before any files are generated, so the scaffold is captured as history.

```bash
git -C /Users/juergen/dev/schwips init
```

Verify:
```bash
git -C /Users/juergen/dev/schwips rev-parse --is-inside-work-tree  # expected: true
```

### Step 1.2 — Scaffold SvelteKit (Svelte 5) non-interactively into a temp dir, then merge into the repo root

The repo root is non-empty (`.claude/`, `incoming/`, `specs/`), which would make `sv create .` interactive. Scaffold into a throwaway subdir with the modern CLI, then copy the generated files up (including dotfiles) and delete the temp dir.

```bash
npx sv create /Users/juergen/dev/schwips/.scaffold --template minimal --types ts --no-add-ons --no-install
rsync -a /Users/juergen/dev/schwips/.scaffold/ /Users/juergen/dev/schwips/
rm -rf /Users/juergen/dev/schwips/.scaffold
```

Verify:
```bash
test -f /Users/juergen/dev/schwips/package.json && test -f /Users/juergen/dev/schwips/svelte.config.js && echo OK
# expected: OK
```

### Step 1.3 — Install base dependencies

Pull the SvelteKit toolchain plus the app-specific libraries. `better-sqlite3` is the standard Drizzle SQLite driver (first choice); `tsx` runs the TypeScript CLI/migrate scripts; `zod` validates import JSON.

```bash
npm --prefix /Users/juergen/dev/schwips install
npm --prefix /Users/juergen/dev/schwips install drizzle-orm better-sqlite3 zod
npm --prefix /Users/juergen/dev/schwips install -D drizzle-kit tsx @types/better-sqlite3
```

Verify (this is the native-build check for Node 26):
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3'); const db=new D(':memory:'); console.log(db.prepare('select 1 as x').get().x)"
# expected: 1
```

> **Fallback (only if the Verify above fails to load/compile on Node 26):** uninstall `better-sqlite3` and `@types/better-sqlite3`, install `@libsql/client` instead, and in Phase 2 use Drizzle's `libsql` driver (`drizzle-orm/libsql`, no native compile) with `dbCredentials.url = "file:data/schwips.db"`. Everything else in the plan is unchanged.

### Step 1.4 — Create runtime directories with `.gitkeep`

The datastore, photo library, and review artifacts live in directories that must exist but whose contents are gitignored.

```bash
mkdir -p /Users/juergen/dev/schwips/data /Users/juergen/dev/schwips/photos /Users/juergen/dev/schwips/incoming/review /Users/juergen/dev/schwips/scripts /Users/juergen/dev/schwips/.claude/commands
touch /Users/juergen/dev/schwips/data/.gitkeep /Users/juergen/dev/schwips/photos/.gitkeep /Users/juergen/dev/schwips/incoming/review/.gitkeep
```

Verify:
```bash
ls -d /Users/juergen/dev/schwips/data /Users/juergen/dev/schwips/photos /Users/juergen/dev/schwips/incoming/review /Users/juergen/dev/schwips/scripts /Users/juergen/dev/schwips/.claude/commands
# expected: all five paths listed, no "No such file or directory"
```

### Step 1.5 — Write `.gitignore`

Keep generated builds, the datastore, the photo library, the raw inbox photos, and env secrets out of git — but preserve the empty directories via their `.gitkeep`.

File `/Users/juergen/dev/schwips/.gitignore` must contain exactly:
```
node_modules/
.svelte-kit/
build/
.env
.DS_Store

/data/*
!/data/.gitkeep

/photos/*
!/photos/.gitkeep

/incoming/*.jpeg
/incoming/review/*
!/incoming/review/.gitkeep
```

Verify:
```bash
git -C /Users/juergen/dev/schwips check-ignore incoming/IMG_5106.jpeg data/schwips.db node_modules
# expected: all three paths echoed back (they are ignored)
git -C /Users/juergen/dev/schwips check-ignore incoming/review/.gitkeep; echo "rc=$?"
# expected: rc=1 (NOT ignored — the .gitkeep is tracked)
```

### Step 1.6 — Set `package.json` scripts

The spec pins exact script names used throughout the plan and by the user.

Edit `/Users/juergen/dev/schwips/package.json` so its `"scripts"` block contains (merge with whatever `sv create` generated, keeping `build`/`preview`/`check`):
```json
"scripts": {
  "dev": "vite dev",
  "build": "vite build",
  "preview": "vite preview",
  "db:generate": "drizzle-kit generate",
  "db:migrate": "tsx src/lib/server/db/migrate.ts",
  "import": "tsx scripts/import.ts"
}
```

Verify:
```bash
node -e "const s=require('/Users/juergen/dev/schwips/package.json').scripts; console.log(['dev','db:generate','db:migrate','import'].every(k=>s[k]))"
# expected: true
```

### Step 1.7 — Confirm the dev server boots

Prove the scaffold runs before adding a database layer.

```bash
npm --prefix /Users/juergen/dev/schwips run build
```

Verify:
```bash
echo $?  # expected: 0  (build completed without error)
```

---

## Phase 2 — Drizzle schema, migration, DB client

### Step 2.1 — Write the Drizzle schema (single source of truth)

This schema is shared verbatim by the web app and the import CLI, so it must model every field in the spec. All identifiers/table/column names are English snake_case.

Create `/Users/juergen/dev/schwips/src/lib/server/db/schema.ts` using `drizzle-orm/sqlite-core`. It must define:

- **`wines`**: `id` integer pk autoincrement; `producer` text notNull; `name` text (nullable); `vintage` integer (nullable); `wine_type` text; `color` text `{ enum: ['white','red','rose','orange'] }`; `sweetness` text `{ enum: ['dry','off-dry','medium','sweet','noble-sweet'] }`; `quality_level` text; `region` text; `country` text; `appellation` text (nullable, e.g. Chianti Classico / Bordeaux / Rioja); `vineyard` text (nullable); `abv` real; `residual_sugar_gl` real (nullable); `acidity_gl` real (nullable); `drink_from` integer (nullable, year); `drink_until` integer (nullable, year); `description` text; `food_pairing` text; `serving_temp_c` text; `closure` text `{ enum: ['cork','screwcap','glass','crown'] }`; `is_organic` integer `{ mode: 'boolean' }`; `is_vegan` integer `{ mode: 'boolean' }`; `external_links` text `{ mode: 'json' }`; `extra_data` text `{ mode: 'json' }`; `data_sources` text `{ mode: 'json' }` (map field→`'label'|'research'|'user'`); `import_confidence` real; `wine_signature` text notNull; `created_at` integer `{ mode: 'timestamp' }` default now; `updated_at` integer `{ mode: 'timestamp' }` default now. Add a **non-unique index** on `wine_signature` (e.g. `index('wines_signature_idx').on(t.wine_signature)`).
- **`grapes`** (one row per **canonical** variety): `id` integer pk autoincrement; `name` text notNull **unique** (canonical, German-preferred: `Grauburgunder`, `Spätburgunder`, else international like `Nebbiolo`); `color` text `{ enum: ['white','red'] }`.
- **`grape_aliases`** (synonym/cross-language → canonical): `id` integer pk autoincrement; `grape_id` integer fk→`grapes.id` notNull; `alias` text notNull **unique** (e.g. `Pinot Grigio`, `Pinot Gris`, `Ruländer` all → Grauburgunder).
- **`wine_grapes`**: `wine_id` integer fk→`wines.id`; `grape_id` integer fk→`grapes.id` (canonical); `percentage` real (nullable); `label_name` text (nullable, the spelling printed on THIS bottle, e.g. `Pinot Grigio`); composite primary key `(wine_id, grape_id)`.
- **`bottles`**: `id` integer pk autoincrement; `wine_id` integer fk→`wines.id` notNull; `bottle_size_ml` integer default `750`; `location` text; `purchase_date` text (nullable, ISO `YYYY-MM-DD`); `purchase_price` real (nullable, EUR); `purchase_vendor` text (nullable); `current_value` real (nullable, EUR); `status` text `{ enum: ['in_stock','consumed','gifted'] }` default `'in_stock'`; `consumed_date` text (nullable); `personal_rating` integer (nullable, 1..5); `created_at`/`updated_at` integer timestamp default now.
- **`photos`**: `id` integer pk autoincrement; `wine_id` integer fk→`wines.id` notNull; `file_path` text notNull (relative under `photos/<wine_id>/`); `is_primary` integer `{ mode: 'boolean' }` default false; `created_at` integer timestamp default now.
- **`tasting_notes`**: `id` integer pk autoincrement; `bottle_id` integer fk→`bottles.id` notNull; `tasted_on` text (ISO date); `rating` integer (nullable, 1..5); `note` text; `created_at` integer timestamp default now.

Export all tables plus inferred types (`export type Wine = typeof wines.$inferSelect;` and matching `$inferInsert` for wines/bottles/photos/grapes/grapeAliases/wineGrapes/tastingNotes).

Verify:
```bash
npx --prefix /Users/juergen/dev/schwips tsc --noEmit -p /Users/juergen/dev/schwips/tsconfig.json 2>&1 | grep -c "schema.ts"
# expected: 0  (no type errors originating in schema.ts)
```

### Step 2.2 — Write `drizzle.config.ts`

Drizzle Kit needs to know the dialect, schema location, and datastore path to generate migrations.

Create `/Users/juergen/dev/schwips/drizzle.config.ts` exporting `defineConfig` from `drizzle-kit` with: `dialect: 'sqlite'`, `schema: './src/lib/server/db/schema.ts'`, `out: './drizzle'`, `dbCredentials: { url: './data/schwips.db' }`.

Verify:
```bash
test -f /Users/juergen/dev/schwips/drizzle.config.ts && echo OK  # expected: OK
```

### Step 2.3 — Write the DB client `index.ts`

Both the web layer and CLI import a single configured Drizzle instance.

Create `/Users/juergen/dev/schwips/src/lib/server/db/index.ts`: open `better-sqlite3` at `data/schwips.db` (path resolved relative to `process.cwd()`), enable `PRAGMA foreign_keys = ON`, wrap with `drizzle(sqlite, { schema })` from `drizzle-orm/better-sqlite3`, and `export const db`. Also `export { schema }` re-export for convenience.

Verify:
```bash
test -f /Users/juergen/dev/schwips/src/lib/server/db/index.ts && echo OK  # expected: OK
```

### Step 2.4 — Write the migrate runner `migrate.ts`

`npm run db:migrate` must apply generated SQL to `data/schwips.db`.

Create `/Users/juergen/dev/schwips/src/lib/server/db/migrate.ts`: open `better-sqlite3` at `data/schwips.db`, wrap with `drizzle(...)`, call `migrate(db, { migrationsFolder: './drizzle' })` from `drizzle-orm/better-sqlite3/migrator`, log `"migrations applied"`, then exit 0.

Verify:
```bash
test -f /Users/juergen/dev/schwips/src/lib/server/db/migrate.ts && echo OK  # expected: OK
```

### Step 2.5 — Generate the initial migration

Turn the schema into SQL migration files.

```bash
npm --prefix /Users/juergen/dev/schwips run db:generate
```

Verify:
```bash
ls /Users/juergen/dev/schwips/drizzle/*.sql | head -1  # expected: one path like drizzle/0000_*.sql
grep -c "CREATE TABLE" /Users/juergen/dev/schwips/drizzle/0000_*.sql  # expected: 7
```

### Step 2.6 — Apply the migration and confirm the schema in SQLite

Create the actual datastore file and verify all six tables exist.

```bash
npm --prefix /Users/juergen/dev/schwips run db:migrate
```

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');console.log(db.prepare(\"select name from sqlite_master where type='table' and name not like 'sqlite_%' and name not like '__drizzle%' order by name\").all().map(r=>r.name).join(','))"
# expected: bottles,grape_aliases,grapes,photos,tasting_notes,wine_grapes,wines
```

### Step 2.7 — Seed common canonical grapes and aliases

Pre-populate the well-known German↔international synonym pairs so the importer resolves e.g. "Pinot Grigio" to `Grauburgunder` out of the box instead of raising it as unknown.

Create `/Users/juergen/dev/schwips/scripts/seed-grapes.ts` (add script `"db:seed": "tsx scripts/seed-grapes.ts"` to `package.json`). It upserts canonical grapes (with `color`) and their aliases idempotently (`onConflictDoNothing` on the unique `grapes.name` / `grape_aliases.alias`). Seed at minimum:
- `Grauburgunder` (white) ← `Pinot Gris`, `Pinot Grigio`, `Ruländer`
- `Weißburgunder` (white) ← `Pinot Blanc`, `Pinot Bianco`, `Klevner`
- `Spätburgunder` (red) ← `Pinot Noir`, `Pinot Nero`, `Blauburgunder`
- `Müller-Thurgau` (white) ← `Rivaner`
- `Zweigelt` (red) ← `Blauer Zweigelt`
- Common no-alias varieties as canonical only: `Riesling`, `Silvaner`, `Chardonnay`, `Sauvignon Blanc`, `Nebbiolo`, `Sangiovese`, `Merlot`, `Cabernet Sauvignon`.

Run it:
```bash
npm --prefix /Users/juergen/dev/schwips run db:seed
```

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');const g=db.prepare(\"select g.name from grapes g join grape_aliases a on a.grape_id=g.id where a.alias='Pinot Grigio'\").get();console.log(g&&g.name)"
# expected: Grauburgunder
```

---

## Phase 3 — Shared libraries (signature, i18n, Zod)

### Step 3.1 — Write `signature.ts` (shared identity/dedup normalizer)

Wine identity is a composite natural signature used identically on web writes and CLI imports, so it must live in one shared module.

Create `/Users/juergen/dev/schwips/src/lib/signature.ts` exporting `computeSignature(w)` where `w` has `{ producer, vintage, appellation, vineyard, name, quality_level, wine_type, grapes? }` (grapes = array of **canonical** grape names, never label spellings — the caller resolves aliases first, so "Pinot Grigio" and "Grauburgunder" produce the same signature). Behavior:
- Concatenate, in a fixed order, `producer | vintage | appellation | vineyard | name | quality_level | wine_type | sorted-grape-names`, using `|` as the stable separator.
- Normalize each part: lowercase; fold diacritics with explicit German rules first (`ü→u, ö→o, ä→a, ß→ss`) then Unicode `normalize('NFKD')` strip of combining marks; collapse all whitespace runs to a single space; trim.
- Treat null/undefined parts as empty string; still emit the separator so positions are stable.
- Return the joined string.

Verify:
```bash
node --input-type=module -e "import('/Users/juergen/dev/schwips/src/lib/signature.ts').then(m=>{console.log(m.computeSignature({producer:'Weingut Müller',vintage:2021,appellation:null,vineyard:'Ürziger Würzgarten',name:null,quality_level:'Kabinett',wine_type:'Riesling',grapes:['Riesling']}))})"
# expected: weingut muller|2021||urziger wurzgarten||kabinett|riesling|riesling
```

### Step 3.2 — Write the German i18n dictionary `de.ts`

Every user-facing string is resolved through this one flat dictionary; components never hold German literals.

Create `/Users/juergen/dev/schwips/src/lib/i18n/de.ts` exporting `const de = { ... } as const` and a helper `t(key: keyof typeof de): string`. Keys are English identifiers → German values. Include at minimum: `inventory:"Bestand"`, `vintage:"Jahrgang"`, `grape:"Rebsorte"`, `grapes:"Rebsorten"`, `drinkingWindow:"Trinkreife"`, `location:"Lagerort"`, `foodPairing:"Speiseempfehlung"`, `closure:"Verschluss"`, `producer:"Erzeuger"`, `region:"Region"`, `country:"Land"`, `appellation:"Herkunftsbezeichnung"`, `color:"Farbe"`, `sweetness:"Geschmack"`, `wineType:"Weintyp"`, `qualityLevel:"Qualitätsstufe"`, `abv:"Alkohol"`, `residualSugar:"Restzucker"`, `acidity:"Säure"`, `servingTemp:"Trinktemperatur"`, `description:"Beschreibung"`, `bottles:"Flaschen"`, `status:"Status"`, `tastingNotes:"Verkostungsnotizen"`, `rating:"Bewertung"`, `addBottle:"Flasche hinzufügen"`, `markConsumed:"Als getrunken markieren"`, `addTastingNote:"Notiz hinzufügen"`, `readyNow:"Trinkreif jetzt"`, `pastWindow:"Trinkfenster überschritten"`, `drinkFrom:"Trinken ab"`, `drinkUntil:"Trinken bis"`, `inStock:"vorrätig"`, `organic:"Bio"`, `vegan:"Vegan"`, `trinkfenster:"Trinkfenster"`, `wineDetail:"Weindetails"`.
Also export **enum-value label maps** (English DB value → German), presentation-layer only: `colorLabels` (`white→"Weiß"`, `red→"Rot"`, `rose→"Rosé"`, `orange→"Orange"`), `sweetnessLabels` (`dry→"trocken"`, `off-dry→"halbtrocken"`, `medium→"lieblich"`, `sweet→"süß"`, `noble-sweet→"edelsüß"`), `closureLabels` (`cork→"Kork"`, `screwcap→"Schraubverschluss"`, `glass→"Glasstopfen"`, `crown→"Kronkorken"`), `statusLabels` (`in_stock→"vorrätig"`, `consumed→"getrunken"`, `gifted→"verschenkt"`). DB enum values stay English.

Verify:
```bash
node --input-type=module -e "import('/Users/juergen/dev/schwips/src/lib/i18n/de.ts').then(m=>console.log(m.de.inventory, m.statusLabels.in_stock))"
# expected: Bestand vorrätig
```

### Step 3.3 — Write the Zod import schema `zod.ts` (mirrors Drizzle)

The import CLI validates confirmed review JSON before any DB write; these Zod schemas must mirror the Drizzle model exactly.

Create `/Users/juergen/dev/schwips/src/lib/import/zod.ts` exporting:
- `wineFieldsSchema`: all `wines` columns except `id`/`wine_signature`/`created_at`/`updated_at`, with the same enums (`color`, `sweetness`, `closure`), nullable/optional matching the schema, `import_confidence` in `[0,1]`, and `grapes: z.array(z.object({ canonical: z.string(), label_name: z.string().nullable().optional(), color: z.enum(['white','red']), percentage: z.number().nullable().optional() }))`. `canonical` is the resolved canonical variety name (Claude does the alias resolution); `label_name` is the printed spelling.
- `bottleSchema`: `bottles` insert columns except `id`/`wine_id`/timestamps; `status` enum; `personal_rating` int 1..5 nullable; sizes/prices as in schema.
- `dedupSchema`: `z.discriminatedUnion('action', [...])` with `{ action: 'new_wine' }` and `{ action: 'match_existing', wine_id: z.number().int() }`.
- `reviewBottleSchema`: `{ photos: z.array(z.string()), dedup: dedupSchema, wine: wineFieldsSchema, bottle: bottleSchema, confidence: z.number().min(0).max(1), open_questions: z.array(z.string()).optional() }`. `photos` may hold **any number** of filenames (a bottle can have one photo or many rotated shots). `open_questions` carries German, human-readable notes about anything Claude could not resolve; the CLI ignores it (it is for the reviewer), but it must be accepted by the schema.
- `reviewFileSchema`: `{ generated_at: z.string(), bottles: z.array(reviewBottleSchema) }`.
Export inferred TS types for each.

Verify:
```bash
node --input-type=module -e "import('/Users/juergen/dev/schwips/src/lib/import/zod.ts').then(m=>console.log(m.reviewFileSchema.safeParse({generated_at:'x',bottles:[]}).success))"
# expected: true
```

---

## Phase 4 — Import CLI (`scripts/import.ts`)

### Step 4.1 — Write the deterministic import CLI

The CLI is the ONLY DB writer during import: it validates the confirmed JSON, executes dedup, writes rows in a single transaction, and moves photos on success.

Create `/Users/juergen/dev/schwips/scripts/import.ts`. Behavior:
1. Read the path argument (`process.argv[2]`); error+exit(1) if missing (`"usage: npm run import -- <review-json>"`).
2. Read and `JSON.parse` the file; validate with `reviewFileSchema`; on failure print the Zod error and exit(1) **without touching the DB**.
3. Import `db`, `schema`, and `computeSignature`.
4. Wrap the whole batch in **one** `db.transaction(...)` (better-sqlite3 transactions are synchronous). For each review bottle:
   - Resolve each grape to a canonical row: upsert `grapes` by `canonical` name (`onConflictDoNothing` on unique `name`, persist `color`, then select id). If `label_name` is present and differs from the canonical name, upsert it into `grape_aliases` (`onConflictDoNothing` on unique `alias`) so the synonym is known next time.
   - Resolve the wine: if `dedup.action === 'match_existing'`, use `dedup.wine_id` (verify the row exists; throw to roll back if not). If `new_wine`, compute `wine_signature = computeSignature({...wine, grapes: wine.grapes.map(g=>g.canonical)})`, insert the `wines` row (persist `data_sources`, `import_confidence`, JSON fields), and insert `wine_grapes` links (`grape_id`, `percentage`, `label_name`). **A stock increment never mutates the existing `wines` row.**
   - Insert the `bottles` row against the resolved `wine_id`.
   - Collect the photo filenames + resolved `wine_id` for the post-commit move (do NOT move files inside the transaction).
5. After the transaction commits successfully: for each collected group, `mkdir -p photos/<wine_id>/`, **move** (`fs.renameSync`, falling back to copy+unlink across devices) each photo from `incoming/<file>` into `photos/<wine_id>/<file>`, and insert a `photos` row (relative `file_path = "<wine_id>/<file>"`, first photo of a new wine `is_primary = true`).
6. Print a summary (`inserted N wines, M bottles, K photos`) and exit(0).
7. On any thrown error: the transaction rolls back (no rows written); **no files are moved**; print the error and exit(1).

Verify (dry structural check — CLI reachable and arg-guard works):
```bash
npm --prefix /Users/juergen/dev/schwips run import 2>&1 | grep -qi "usage" && echo OK  # expected: OK
```

### Step 4.2 — Round-trip the CLI against a synthetic review file

Prove insert + dedup + file-move logic before involving real photos.

```bash
printf 'placeholder' > /Users/juergen/dev/schwips/incoming/IMG_TEST.jpeg
cat > /Users/juergen/dev/schwips/incoming/review/_smoke.json <<'JSON'
{"generated_at":"2026-07-01T00:00:00Z","bottles":[{"photos":["IMG_TEST.jpeg"],"dedup":{"action":"new_wine"},"confidence":0.9,"wine":{"producer":"Testweingut","name":null,"vintage":2021,"wine_type":"Riesling","color":"white","sweetness":"dry","quality_level":"QbA","region":"Mosel","country":"Deutschland","appellation":null,"vineyard":null,"abv":11.5,"residual_sugar_gl":null,"acidity_gl":null,"drink_from":2023,"drink_until":2028,"description":"Test","food_pairing":"Fisch","serving_temp_c":"10-12","closure":"screwcap","is_organic":false,"is_vegan":true,"external_links":[],"extra_data":{},"data_sources":{"producer":"label"},"import_confidence":0.9,"grapes":[{"canonical":"Riesling","label_name":null,"color":"white","percentage":100}]},"bottle":{"bottle_size_ml":750,"location":"Keller","purchase_date":null,"purchase_price":null,"purchase_vendor":null,"current_value":null,"status":"in_stock","consumed_date":null,"personal_rating":null}}]}
JSON
npm --prefix /Users/juergen/dev/schwips run import -- incoming/review/_smoke.json
```

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');const w=db.prepare('select id from wines').get();console.log('wines',db.prepare('select count(*) c from wines').get().c,'bottles',db.prepare('select count(*) c from bottles').get().c,'photoRow',db.prepare('select file_path from photos').get().file_path);const fs=require('fs');console.log('moved',fs.existsSync('/Users/juergen/dev/schwips/photos/'+w.id+'/IMG_TEST.jpeg'),'incomingGone',!fs.existsSync('/Users/juergen/dev/schwips/incoming/IMG_TEST.jpeg'))"
# expected: wines 1 bottles 1 photoRow 1/IMG_TEST.jpeg moved true incomingGone true
```

### Step 4.3 — Verify stock-increment dedup path

Confirm re-importing a matched wine adds a bottle without duplicating the wine or mutating it.

```bash
cat > /Users/juergen/dev/schwips/incoming/review/_smoke2.json <<'JSON'
{"generated_at":"2026-07-01T00:00:00Z","bottles":[{"photos":[],"dedup":{"action":"match_existing","wine_id":1},"confidence":1,"wine":{"producer":"Testweingut","name":null,"vintage":2021,"wine_type":"Riesling","color":"white","sweetness":"dry","quality_level":"QbA","region":"Mosel","country":"Deutschland","appellation":null,"vineyard":null,"abv":11.5,"residual_sugar_gl":null,"acidity_gl":null,"drink_from":2023,"drink_until":2028,"description":"Test","food_pairing":"Fisch","serving_temp_c":"10-12","closure":"screwcap","is_organic":false,"is_vegan":true,"external_links":[],"extra_data":{},"data_sources":{},"import_confidence":1,"grapes":[]},"bottle":{"bottle_size_ml":750,"location":"Keller","purchase_date":null,"purchase_price":null,"purchase_vendor":null,"current_value":null,"status":"in_stock","consumed_date":null,"personal_rating":null}}]}
JSON
npm --prefix /Users/juergen/dev/schwips run import -- incoming/review/_smoke2.json
```

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');console.log('wines',db.prepare('select count(*) c from wines').get().c,'bottlesForWine1',db.prepare(\"select count(*) c from bottles where wine_id=1\").get().c)"
# expected: wines 1 bottlesForWine1 2
```

### Step 4.4 — Reset the test data

Remove synthetic rows/files so the real smoke test in Phase 8 starts clean.

```bash
rm -f /Users/juergen/dev/schwips/incoming/review/_smoke.json /Users/juergen/dev/schwips/incoming/review/_smoke2.json
rm -rf /Users/juergen/dev/schwips/photos/1
rm -f /Users/juergen/dev/schwips/data/schwips.db
npm --prefix /Users/juergen/dev/schwips run db:migrate
npm --prefix /Users/juergen/dev/schwips run db:seed
```

**Irreversible:** deletes the throwaway test datastore and recreates an empty (re-seeded) one; only synthetic Phase-4 data is lost.

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');console.log(db.prepare('select count(*) c from wines').get().c)"
# expected: 0
```

---

## Phase 5 — The `/import-wines` Claude command

### Step 5.1 — Write the command file

`/import-wines` drives the fuzzy half of the pipeline (vision, clustering, research, dedup proposal) and writes review artifacts **without touching the DB**.

Create `/Users/juergen/dev/schwips/.claude/commands/import-wines.md`. The command file opens with a directive that **Claude communicates with the user in German** throughout the run (progress notes, clarifying questions, and the review markdown), even though code, identifiers, and stored enum values stay English. Content (a procedure prompt for Claude Code) must instruct:
1. List `incoming/*.jpeg` and read every photo.
2. Cluster photos into bottles: **first** by filename ordering (sequential capture numbers are adjacent), **then** confirm/adjust visually so every photo of the same bottle is grouped — front, back, capsule, and any number of overlapping/rotated shots of the same label. A group has **no fixed size** (one photo or many). If the correct grouping is genuinely ambiguous, flag it as a German open question instead of guessing.
3. For each group: extract label fields via vision. **Labels may be in any language** (German, Italian, French, English, Spanish, …) — extract regardless. Store free-text fields (`producer`, `region`, `vineyard`, `name`, `description`) as printed; normalize controlled fields (`color`, `sweetness`, `closure`, `wine_type` where it maps) to the English enum values. **Grapes:** resolve each printed grape name to its canonical variety (German-preferred, e.g. printed "Pinot Grigio" → `canonical: "Grauburgunder"`), keep the printed spelling in `label_name`, and set the grape `color`. Prefer known aliases from the `grape_aliases` table (query it) and your own knowledge; if a grape matches no canonical variety or alias, propose it as a new canonical grape or raise it as a German `open_question` — never invent a duplicate. **Appellation wines:** if the label prints an appellation instead of grapes (Chianti, Bordeaux, Rioja, Châteauneuf-du-Pape …), set `appellation` (provenance `"label"`) and research the appellation's typical/legal grape composition — insert those grapes with provenance `"research"`, `label_name` null, and typical percentages where known — plus a German `open_question` noting the blend was derived from the appellation, not read from the bottle. Research missing/enriching data via WebSearch (drinking window, grape %, ratings, region facts); capture unmodeled printed facts into `extra_data`; record per-field provenance in `data_sources` (`"label"` | `"research"`) and an overall `import_confidence` in `[0,1]`.
4. **Never silently guess.** If a field is illegible or absent: first try to complete it via WebSearch (provenance `"research"`); if it still cannot be determined confidently, leave the field null, lower `import_confidence`, and add a German note to that bottle's `open_questions` (e.g. `"Jahrgang auf Kapsel unleserlich — 2019 oder 2021?"`). During an interactive run Claude may also ask the user directly in German; anything still unresolved stays in `open_questions`.
5. Dedup: compute the candidate signature (same normalization rules as `src/lib/signature.ts`), query existing wines for matching/near-matching signatures, and emit a dedup proposal per bottle — `{"action":"new_wine"}` or `{"action":"match_existing","wine_id":N}` (increment stock).
6. Write a **pair** of artifacts with a shared timestamp: `incoming/review/<timestamp>.json` (machine, exact shape of `reviewFileSchema` from `src/lib/import/zod.ts` — CLI input, including `open_questions` and a `photos` array of any length) and `incoming/review/<timestamp>.md` (German, human-readable: per-bottle photo group, extracted+researched fields, dedup proposal, `import_confidence`, and any `open_questions` surfaced prominently along with low-confidence fields).
7. State explicitly that Claude does **NOT** write the database; the human reviews the `.md`, resolves open questions, edits the `.json`, then runs `npm run import -- incoming/review/<timestamp>.json`.

The file must document the exact JSON shape (list the `reviewBottleSchema` fields, including optional `open_questions` and the variable-length `photos` array) so the emitted JSON validates against Zod on the first try.

Verify:
```bash
test -f /Users/juergen/dev/schwips/.claude/commands/import-wines.md && grep -qi "does not write" /Users/juergen/dev/schwips/.claude/commands/import-wines.md && grep -qi "deutsch\|german" /Users/juergen/dev/schwips/.claude/commands/import-wines.md && echo OK
# expected: OK
```

---

## Phase 6 — Web UI routes and form actions (SSR, German)

### Step 6.1 — Bestand list at `/`

The landing page shows all wines with in-stock bottle counts and filter/sort controls.

Create `/Users/juergen/dev/schwips/src/routes/+page.server.ts` (`load`): query all `wines` left-joined to a per-wine count of `bottles` where `status='in_stock'` (inventory = COUNT of in-stock bottles), plus each wine's grape names. Accept URL query params for filter/sort by `wine_type`, `region`, `vintage`, `color`, and `trinkreif` (drinking window includes the current year `new Date().getFullYear()`). Return the list.

Create `/Users/juergen/dev/schwips/src/routes/+page.svelte`: render the list as cards/rows showing producer, name, vintage, color, and in-stock count; each row links to `/wine/[id]`. Present filter/sort controls. All labels come from `src/lib/i18n/de.ts` (`de.inventory` as page title, enum values via `colorLabels`/`sweetnessLabels`, etc.) — **no German literals in the component**.

Verify:
```bash
npm --prefix /Users/juergen/dev/schwips run build && echo BUILD_OK  # expected: BUILD_OK
```

### Step 6.2 — Wine detail + form actions at `/wine/[id]`

The detail page shows all fields and is the write surface for consuming bottles, tasting notes, edits, and stock adjustments.

Create `/Users/juergen/dev/schwips/src/routes/wine/[id]/+page.server.ts`:
- `load`: fetch the wine, its grape composition (`wine_grapes` + `grapes` with percentages; display each as `label_name ?? grapes.name`), photos, all bottles (status/location/rating), and tasting notes joined via bottles. 404 if the wine is missing.
- `actions`:
  - `markConsumed`: set the given bottle `status='consumed'`, `consumed_date=today`.
  - `addTastingNote`: insert a `tasting_notes` row for a bottle (`tasted_on`, optional `rating` 1..5, `note`).
  - `editField`: update one `wines` field; set that field's key in `data_sources` to `'user'`; bump `updated_at`; recompute `wine_signature` via `computeSignature` if an identity field changed.
  - `addBottle`: insert a new `bottles` row (`status='in_stock'`) against this wine.
  - `removeBottle`: set a bottle `status='consumed'` or delete it (adjust stock) — one action, documented.
  All actions use the same Drizzle `db` layer.

Create `/Users/juergen/dev/schwips/src/routes/wine/[id]/+page.svelte`: render all fields (labels from `de.ts`, enum values via the label maps), grape composition, a photo gallery from `photos` rows (served from `/photos/...` — see Step 6.4), the bottle list with per-bottle "Als getrunken markieren", a tasting-note form, an edit form, and add/remove-bottle controls, each posting to the matching form action.

Verify:
```bash
npm --prefix /Users/juergen/dev/schwips run build && echo BUILD_OK  # expected: BUILD_OK
```

### Step 6.3 — Trinkfenster at `/trinkfenster`

Surfaces wines whose drinking window includes the current year, plus a section for wines past their window.

Create `/Users/juergen/dev/schwips/src/routes/trinkfenster/+page.server.ts` (`load`): compute `year = new Date().getFullYear()`; return `ready` = wines where `drink_from <= year <= drink_until` (with in-stock counts) and `past` = wines where `drink_until < year`.
Create `/Users/juergen/dev/schwips/src/routes/trinkfenster/+page.svelte`: two sections titled via `de.readyNow` and `de.pastWindow`, each linking to `/wine/[id]`; labels from `de.ts`.

Verify:
```bash
npm --prefix /Users/juergen/dev/schwips run build && echo BUILD_OK  # expected: BUILD_OK
```

### Step 6.4 — Serve the photo library

The gallery needs to load imported images from `photos/<wine_id>/`, which is outside `static/`.

Create `/Users/juergen/dev/schwips/src/routes/photos/[wine]/[file]/+server.ts`: a `GET` handler that reads `photos/<wine>/<file>` from disk (validate `wine` is numeric and `file` has no path separators / `..`), returns the bytes with the correct `Content-Type` (`image/jpeg`), or 404.

Verify:
```bash
npm --prefix /Users/juergen/dev/schwips run build && echo BUILD_OK  # expected: BUILD_OK
```

---

## Phase 7 — Auth seam (no login UI)

### Step 7.1 — Write `auth.ts`

Future single-password hosting needs only a seam now; local default is auth disabled.

Create `/Users/juergen/dev/schwips/src/lib/server/auth.ts` exporting:
- `isAuthEnabled(): boolean` — true iff `process.env.SCHWIPS_AUTH_PASSWORD` is set/non-empty (disabled when unset → local default).
- `verifySession(cookie: string | undefined): boolean` — returns whether the session cookie is valid (stub: compare against a derived token of the shared password). No users table, no login UI.

Verify:
```bash
node --input-type=module -e "import('/Users/juergen/dev/schwips/src/lib/server/auth.ts').then(m=>console.log(m.isAuthEnabled()))"
# expected: false   (SCHWIPS_AUTH_PASSWORD unset locally)
```

### Step 7.2 — Wire the hook in `hooks.server.ts`

The handle hook must be a no-op passthrough when auth is disabled and the enforcement point when enabled.

Create `/Users/juergen/dev/schwips/src/hooks.server.ts` exporting `handle`: if `!isAuthEnabled()` → `return resolve(event)` (passthrough). If enabled and the request is not the (future) login route and `verifySession(event.cookies.get('schwips_session'))` is false → redirect to `/login` (route itself out of scope for v1). Otherwise `resolve(event)`.

Verify:
```bash
npm --prefix /Users/juergen/dev/schwips run build && echo BUILD_OK  # expected: BUILD_OK
```

---

## Phase 8 — End-to-end smoke test with the real inbox photos

### Step 8.1 — Confirm the real inbox is intact

The 39 iPhone photos must still be present before running the real import.

Verify:
```bash
ls /Users/juergen/dev/schwips/incoming/IMG_51[0-4]*.jpeg | wc -l | tr -d ' '   # expected: 39
ls /Users/juergen/dev/schwips/incoming/IMG_5106.jpeg /Users/juergen/dev/schwips/incoming/IMG_5144.jpeg  # expected: both listed
```

### Step 8.2 — Run `/import-wines` to generate review artifacts

Exercise the fuzzy pipeline end-to-end (vision + clustering + research + dedup proposal) against the real `IMG_5106.jpeg`…`IMG_5144.jpeg`.

Run the Claude Code command `/import-wines` in this repo. It reads all 39 photos, clusters them into bottles, researches fields, and writes `incoming/review/<timestamp>.json` + `.md` — **without touching the DB**.

Verify:
```bash
ls /Users/juergen/dev/schwips/incoming/review/*.json /Users/juergen/dev/schwips/incoming/review/*.md >/dev/null 2>&1 && echo OK  # expected: OK
node --input-type=module -e "import('/Users/juergen/dev/schwips/src/lib/import/zod.ts').then(async m=>{const fs=await import('fs');const f=fs.readdirSync('/Users/juergen/dev/schwips/incoming/review').filter(x=>x.endsWith('.json'))[0];console.log(m.reviewFileSchema.safeParse(JSON.parse(fs.readFileSync('/Users/juergen/dev/schwips/incoming/review/'+f))).success)})"
# expected: true   (generated JSON validates against Zod)
```

### Step 8.3 — Human review, then import

The mandatory review step: inspect the `.md`, edit the `.json`, then run the deterministic importer (the only DB writer).

```bash
npm --prefix /Users/juergen/dev/schwips run import -- incoming/review/<the-timestamp>.json
```

Verify:
```bash
node -e "const D=require('/Users/juergen/dev/schwips/node_modules/better-sqlite3');const db=new D('/Users/juergen/dev/schwips/data/schwips.db');console.log('wines',db.prepare('select count(*) c from wines').get().c,'bottles',db.prepare('select count(*) c from bottles').get().c,'photos',db.prepare('select count(*) c from photos').get().c)"
# expected: wines >0, bottles >0, photos >0 (matching the confirmed review file)
ls /Users/juergen/dev/schwips/incoming/*.jpeg 2>/dev/null | wc -l | tr -d ' '   # expected: 0  (all photos moved out of incoming/)
ls -d /Users/juergen/dev/schwips/photos/*/ | head -1  # expected: at least one photos/<wine_id>/ dir exists
```

### Step 8.4 — Verify the UI renders the imported data

Confirm Bestand, wine detail, and Trinkfenster serve the imported wines with the German UI.

```bash
npm --prefix /Users/juergen/dev/schwips run dev
```

Verify:
```bash
curl -s http://localhost:5173/ | grep -qi "Bestand" && echo BESTAND_OK       # expected: BESTAND_OK
curl -s http://localhost:5173/trinkfenster | grep -qi "Trinkfenster" && echo TF_OK  # expected: TF_OK
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:5173/wine/1          # expected: 200
```
Stop the dev server (Ctrl-C) once the three checks pass.

---

## Definition of done

- `npm run dev` serves a fully German UI on localhost (Bestand `/`, wine detail `/wine/[id]`, Trinkfenster `/trinkfenster`).
- `data/schwips.db` exists with the seven-table Drizzle schema (`wines`, `grapes`, `grape_aliases`, `wine_grapes`, `bottles`, `photos`, `tasting_notes`); `npm run db:migrate` applies migrations and `npm run db:seed` loads canonical grapes/aliases.
- `/import-wines` produces `incoming/review/<ts>.json`+`.md` without any DB write.
- `npm run import -- <json>` is the only import-time DB writer: validates via Zod, writes `wines`/`bottles`/`photos` in one transaction, and moves photos into `photos/<wine_id>/`.
- Inventory count = number of `bottles` rows with `status='in_stock'`; re-import of an existing wine increments stock (new bottle row) without mutating the wine.
- `src/lib/signature.ts` is the single shared identity normalizer; `src/lib/server/db/schema.ts` is the single source of truth; auth exists only as a seam (`src/lib/server/auth.ts` + `src/hooks.server.ts`), passthrough when `SCHWIPS_AUTH_PASSWORD` is unset.
