# 🍷 Schwips

Schwips keeps track of your wine cellar: what you own, how many bottles of each, and when each one will be at its best to drink. To add a wine, you take a photo of its label; Claude Code reads it, researches anything not printed on it, and adds the bottle to your inventory. Open the app to browse your collection, filter it, and see what's ready to drink.

> The app's interface is entirely in German (you'll see "Bestand" for inventory, "Trinkreif jetzt" for ready-to-drink, and so on). This README is in English.

![The Bestand view filtered to producer "Diel", showing three Riesling wine cards with vintage, vineyard, quality tier, a ready-to-drink tag, and bottle counts.](docs/bestand-screenshot.png)

*Browsing the Bestand, filtered to a single producer — each card is one wine, with its details and how many bottles you have.*

## 🗂️ Wines and bottles

Schwips draws a clean line between a *wine* and a *bottle*, and that's what keeps your inventory tidy. A **wine** is the product: something like *2023 Diel Riesling Burg Layer Schlossberg*, with its producer, vintage, grape varieties, region and appellation, quality tier, and an estimated drinking window. A **bottle** is one physical unit of that wine sitting on your shelf.

So if you own three bottles of the same wine, you see a single wine entry with a count of 3. Drink one, mark it consumed, and the count drops to 2 — while the wine itself stays on record, so you can always look up what it was, add a tasting note, or reorder it later. One entry per wine, a live count of bottles behind it.

## 📸 How you use it, day to day

The whole loop is three steps:

1. **Take photos** of a new bottle's label — front, back, capsule, as many as you find useful. There's no fixed number and nothing to rename. Drop them into `runtime/incoming/`.
2. **Run `/import-wines` in Claude Code.** Claude looks at the photos, works out which ones belong to the same bottle, reads off the details, and researches anything the label doesn't spell out — the grape blend behind an appellation like "Chianti", a sensible drinking window, a bit of background on the producer. If it's a wine you already have, it adds to the count. Otherwise it creates a new wine entry.
3. **Open the app and browse your Bestand.** Within moments the bottle is there. Filter it, see what's ready to drink, and log a tasting note when you open something.

Each detail on a wine remembers whether it came straight off the label or was researched, so you always know what's a printed fact versus Claude's best-informed guess.

## 🍇 What it tracks for you

- **Bottle-level inventory** — how many of each wine you currently have in stock, always up to date as you add and consume.
- **Photo-driven adding** — the `/import-wines` workflow above reads producer, vintage, grapes, region, appellation, and quality classification from the label, and fills in the rest with web research.
- **Smart matching** — when a new bottle is one you already own (same producer, vintage, vineyard, grapes, and so on), Schwips recognizes it and increments the count.
- **Drinking windows** — each wine gets an estimated window based on its quality tier. A simple Gutswein is ready to enjoy soon after release, while a Großes Gewächs or grand-cru-style wine wants years to come into its own. The Bestand flags each wine as **"Trinkreif jetzt"** (ready now) or **"Noch nicht trinkreif"** (not yet).
- **Filterable inventory** — narrow your Bestand by wine type, country, region, color, producer, or quality level, with live counts of how many wines and bottles match.
- **Tasting notes** — log a note and a rating against a specific bottle, for example the evening you open and drink it.

## 🛠️ Tech stack

Schwips is a full-stack **SvelteKit** app written in TypeScript, backed by **SQLite** through the **Drizzle ORM** — a single-file datastore. Nothing external is required beyond Claude Code itself for the import step.

## 🚀 Installing

```sh
git clone <this-repo>
cd schwips
npm install

# optional but recommended: seed common grape varieties + aliases
# (e.g. so "Pinot Grigio" on a label resolves to Grauburgunder out of the box)
npm run db:seed

# start the dev server
npm run dev
```

The app runs on localhost — the exact port is printed in the terminal. All runtime data (the SQLite file, imported photos, and the photo inbox) lives under `runtime/`, is entirely gitignored, and is created automatically the first time the app starts, so there's no manual database setup. A fresh clone starts with an empty cellar.

## 📋 Useful commands

| Command | What it does |
|---|---|
| `npm run dev` | Start the dev server |
| `npm run db:generate` | Generate a Drizzle migration from schema changes |
| `npm run db:migrate` | Apply migrations to `runtime/data/schwips.db` explicitly (also runs automatically on every startup) |
| `npm run db:seed` | Seed the canonical grape-variety table |
| `npm run import -- <path>` | Import a wine data file into the database (used internally by `/import-wines`) |
| `npm run check` | Type-check the project |
