# 🍷 Schwips

Schwips is a **Mac app** that keeps track of your wine cellar: what you own, how many bottles of each, and when each one will be at its best to drink. To add a wine, you take a photo of its label; Claude Code reads it, researches anything not printed on it, and Schwips adds the bottle to your inventory. Open the app to browse your collection, search, filter and sort it, and see what's ready to drink.

> The app speaks English and German and follows your system language (in German you'll see "Im Bestand" for in stock, "Trinkreif jetzt" for ready to drink, and so on). There is no iPhone or iPad app yet, but Schwips is built so one can follow and share the same cellar.

![The Schwips window in German: the sidebar with the lists Im Bestand, Trinkreif, Getrunken and Alle Weine and the eight filters; the wines in stock, red and white, sorted by date added, each with its grapes, vintage, appellation, tags and bottle count; and the detail of Tenuta Trerose Palio della Rosa Riserva 2021 with its facts, description, notes, label photos and one bottle in stock.](docs/screenshot.png)

*Your cellar at a glance: the wines in stock on the left, one wine open with its facts, description, label photos and bottles.*

## 🗂️ Wines and bottles

Schwips draws a clean line between a *wine* and a *bottle*, and that's what keeps your inventory tidy. A **wine** is the product: something like *2023 Diel Riesling Burg Layer Schlossberg*, with its producer, vintage, grape varieties, region and appellation, quality tier, and an estimated drinking window. A **bottle** is one physical unit of that wine sitting on your shelf.

So if you own three bottles of the same wine, you see a single wine entry with a count of 3. Drink one, mark it as drunk, and the count drops to 2 — while the wine itself stays on record, so you can always look up what it was, rate it, jot down a note, or reorder it later. One entry per wine, a live count of bottles behind it.

## 📸 How you use it, day to day

The whole loop is three steps:

1. **Take photos** of a new bottle's label — front, back, capsule, as many as you find useful. There's no fixed number and nothing to rename. Drop them into `runtime/incoming/`.
2. **Run `/import-wines` in Claude Code.** Claude looks at the photos, works out which ones belong to the same bottle, reads off the details, and researches anything the label doesn't spell out — the grape blend behind an appellation like "Chianti", a sensible drinking window, a bit of background on the producer. It writes a review file next to the photos, and Schwips picks it up by itself: if it's a wine you already have, it adds to the count; otherwise it creates a new wine entry.
3. **Look in the app.** Within moments a banner says what came in, and new wines are marked NEW. Filter, see what's ready to drink, and mark a bottle as drunk when you open it. Spotted a wrong detail? Double-click it and fix it; ⌘Z undoes any change.

Each detail on a wine remembers whether it came straight off the label or was researched, so you always know what's a printed fact versus Claude's best-informed guess.

## 🍽️ What goes with what

Not sure which bottle to open? **Run `/recommend` in Claude Code** and describe the dish or occasion — "Lachsquiche", "pasta amatriciana", "Grillabend mit Freunden". Claude reads your actual in-stock bottles from the database, reasons about the pairing (acidity, tannin, sweetness, body — not just a keyword match on a pairing field), and recommends one to three wines with a short rationale, bottle counts, and a `schwips://` link that opens each wine in the app. Your own notes on a wine ("too young", "great with asparagus") count too. It only ever suggests wines you actually own.

## 🍇 What it tracks for you

- **Bottle-level inventory** — how many of each wine you currently have in stock, always up to date as you add and drink.
- **Photo-driven adding** — the `/import-wines` workflow above reads producer, vintage, grapes, region, appellation, and quality classification from the label, and fills in the rest with web research.
- **Smart matching** — when a new bottle is one you already own (same producer, vintage, vineyard, grapes, and so on), Schwips recognizes it and increments the count.
- **Drinking windows** — each wine gets an estimated window based on its quality tier. A simple Gutswein is ready to enjoy soon after release, while a Großes Gewächs or grand-cru-style wine wants years to come into its own. Each wine is flagged **Ready to Drink** or **Not Ready Yet**, and the Ready to Drink list shows only what's ready now.
- **Lists, search, filters, sorting** — In Stock, Ready to Drink, Drunk and All Wines; search by name, grape, region or food pairing; filter by colour, type, grape, country, region, winery, price or rating; sort by winery, vintage, price, rating, drinking window or date added.
- **Ratings, notes and history** — rate a wine with one to five stars, keep your own notes on it, and see when you drank each bottle.
- **Label photos** — every bottle's label photos stay with the wine; click one to see it large.
- **Pairing recommendations** — the `/recommend` workflow above suggests wines from your own stock for a given dish or occasion, with reasoning and links.

## 💻 System requirements

- **To run it:** a Mac with Apple silicon on **macOS 27** or later. Your cellar stays on that Mac; there's no iCloud sync yet.
- **To add bottles and get recommendations:** [Claude Code](https://claude.com/claude-code), which runs `/import-wines` and `/recommend` in this repository.
- **To build it:** **Xcode 27.2** (Swift 6.4) and an Apple Development signing certificate, which Xcode creates for your Apple account under *Settings › Accounts*. There's no download; you build the app yourself.
- **Disk space:** label photos are stored shrunk to about 0.8 MB each, so a cellar of 50 wines with a few photos per wine takes around 100 MB.

## 🛠️ Tech stack

Schwips is a native **SwiftUI** app for macOS 27, written in Swift 6 with **SwiftData** as its store, structured so iCloud sync and an iOS app can be added later. Nothing external is required beyond Claude Code itself for the import step.

## 🚀 Installing

See the system requirements above.

```sh
git clone <this-repo>
cd schwips/app
make app            # builds build/Schwips.app
make install        # optional: copies it to /Applications
open build/Schwips.app
```

On first launch Schwips asks for the `runtime` folder of this checkout (it's gitignored; create `runtime/incoming/` in a fresh clone). That's where your label photos and Claude's review files go. If the folder still holds the cellar of the old Schwips web app (`runtime/data/schwips.db`), Schwips offers to copy it — wines, bottles, ratings, drunk dates and photos — and leaves the old files untouched.

## 📋 Useful commands

Run these in `app/`:

| Command | What it does |
|---|---|
| `make app` | Build and sign `build/Schwips.app` |
| `make install` | Copy the app to `/Applications` |
| `make test` | Run the tests |
| `make strings` | Collect new texts into the English/German string catalog |
| `make icon` | Redraw the app icon |
