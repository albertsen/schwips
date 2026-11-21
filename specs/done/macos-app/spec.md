# macOS App

Schwips as a native Mac app: the same cellar, filters, wine detail and bottles as the web app, plus search, sorting, editing in place and undo, in English and German, built so an iOS app can follow later.

Design: https://claude.ai/artifact/Ft8pitJVYTVNA1BVrwbzM4 (canvas "Schwips design", all artboards)

## Problem

1. Schwips only runs as a dev server on `localhost`. Looking up a bottle means starting `npm run dev` and opening a browser tab.
2. The web app cannot grow into an iPhone app. Checking the cellar in a shop or at the shelf needs a native app with data that can later sync through iCloud.
3. The web app cannot search, sort or fix a wrong field, and a mistaken click (Mark as Drunk, Remove Bottle) cannot be undone.

## Experience

### Getting the app

In `app/`, `make app` builds `build/Schwips.app`, a sandboxed Mac app signed with the user's development certificate. `make install` copies it to `/Applications/Schwips.app`. The app needs macOS 27.

The app keeps its cellar in its own container: `~/Library/Containers/de.juergenalbertsen.schwips/Data/Library/Application Support/Schwips/`. Photos live in the same store. Nothing syncs in this spec, but the data follows iCloud's rules, so a later spec can turn on sync and add the iOS app without changing the data's shape.

The web app moves to `webapp/` and stays otherwise unchanged; the Swift package for the Mac app (and the later iOS app) lives in `app/`. `runtime/` stays at the repository root, shared by both. After the Mac app has copied the cellar, imports go only to the Mac app, and the web app's data is no longer updated.

### Languages

The whole UI exists in English and German and follows the system language, or Schwips' own language in System Settings. Dates, prices and numbers follow the language: "21 Nov 2026" / "21.11.2026", "€26.00" / "26,00 €", "12.5 %" / "12,5 %". Counts use plural rules: "1 bottle", "2 bottles" / "1 Flasche", "2 Flaschen". Wine data (winery, descriptions, regions, food pairings) is never translated.

To check German, start the app with:

```
open build/Schwips.app --args -AppleLanguages '(de)' -AppleLocale de_DE
```

### First launch

The first launch opens the "Welcome to Schwips" / "Willkommen bei Schwips" sheet (design: First launch). It explains: "Schwips adds new bottles from the review files that /import-wines writes. Choose your Schwips runtime folder, the one that holds incoming/ and data/." The field shows "No folder chosen" / "Kein Ordner ausgewählt" and `Choose Folder…` / `Ordner auswählen…`. `Continue` / `Weiter` stays disabled until a folder is chosen. `Later` / `Später` closes the sheet; the main window then shows the empty cellar, and Settings offers the folder choice.

The chosen folder is remembered between launches. A folder without an `incoming/` subfolder is refused with "This folder has no incoming/ folder. Choose the runtime folder of your Schwips checkout." / "Dieser Ordner hat keinen Ordner incoming/. Wähle den runtime-Ordner deines Schwips-Checkouts."

When the chosen folder contains the web app's cellar (`data/schwips.db`), the sheet shows "The web app's cellar is in this folder" / "Der Keller der Web-App liegt in diesem Ordner" with its counts ("39 wines · 70 bottles · 121 photos") and "Copying leaves the web app's files as they are." / "Beim Kopieren bleiben die Dateien der Web-App unverändert." The buttons are `Start Empty` / `Leer beginnen` and `Copy Cellar` / `Keller kopieren`.

`Copy Cellar` copies every wine with all its fields and provenance, every bottle (size, location, purchase data, price, status, drunk date), every grape with its aliases and percentages, every rating and every photo. Each wine keeps its number from the web app. While it runs, a sheet shows "Copying your cellar…" / "Dein Keller wird kopiert…" with a progress bar and "24 of 39 wines" / "24 von 39 Weinen". When it is done, a banner above the list says "Copied 39 wines, 70 bottles and 121 photos from the web app." / "39 Weine, 70 Flaschen und 121 Fotos aus der Web-App kopiert."

The copy is all or nothing. When it fails, "Couldn't copy the cellar" / "Keller konnte nicht kopiert werden" names the cause (for example "data/schwips.db can't be read: file is not a database.") and says "Nothing was copied." / "Es wurde nichts kopiert." with `Start Empty` and `Try Again` / `Erneut versuchen`. A missing photo file does not fail the copy; the banner then adds "3 photos were missing and were skipped." / "3 Fotos fehlten und wurden übersprungen."

The copy is offered only while the Schwips cellar is empty. Review files that are already in `incoming/review/` when the folder is chosen count as imported, because the web app imported them.

### The main window

One window with three columns: sidebar, wine list, detail (design: Main window, German). The system font is used throughout. Wine names use the serif New York. One accent colour, a burgundy, marks the selection and the primary buttons. Stars are gold.

**Sidebar.** The section "Cellar" / "Keller" holds four lists, each with an icon and its number of wines:

| List | English | German | Holds |
|---|---|---|---|
| In Stock | `In Stock` | `Im Bestand` | wines with at least one bottle in stock |
| Ready to Drink | `Ready to Drink` | `Trinkreif` | wines in stock whose drinking window contains the current year |
| Drunk | `Drunk` | `Getrunken` | wines with at least one drunk bottle, in stock or not |
| All Wines | `All Wines` | `Alle Weine` | every wine |

The app opens on In Stock the first time. Counts update as soon as anything changes.

Below the lists, "Filters" / "Filter" holds eight pop-ups, each with its title in a fixed column and the pop-up filling the rest, so all pop-ups have the same width: Colour / Farbe, Type / Weintyp, Grape / Rebsorte, Country / Land, Region / Region, Winery / Weingut, Price / Preis (in 10-euro steps, "20–30 €"), Rating / Bewertung (1–5 stars). Each starts at "All" / "Alle". A pop-up with a value is drawn in the accent colour. Each pop-up offers only values that still give results with the other filters, the selected list and the search. `Reset` / `Zurücksetzen` sets all filters back to All; it shows only while a filter is set. With an empty cellar, the section shows "Filters appear once there are wines." / "Filter erscheinen, sobald Weine da sind."

At the bottom of the sidebar: "Last import 21 Nov, 14:02" / "Letzter Import 21. Nov., 14:02", or "Import folder not found" / "Import-Ordner nicht gefunden" in red when the chosen folder is gone. Clicking that line opens Settings.

**Toolbar.** The list's name and its counts: "36 wines · 58 bottles" / "36 Weine · 58 Flaschen", and while a filter or search is active "9 of 36 wines · 11 of 58 bottles" / "9 von 36 Weinen · 11 von 58 Flaschen". Bottles count only bottles in stock. Then the Sort pop-up and the search field ("Search" / "Suchen").

**Wine list.** Each row shows:

- Winery and wine name (name in the serif), the price on the right.
- Type in small capitals, grapes, vintage: "WINE · Riesling · 2023". A wine without a vintage shows "NV" / "o. J.".
- Name or appellation, otherwise region, then the quality tier: "Dorsheimer Eierfels · VDP.Ortswein".
- A colour chip (White, Red, Rosé, Orange / Weiß, Rot, Rosé, Orange), "Ready to Drink" / "Trinkreif jetzt" or "Not Ready Yet" / "Noch nicht trinkreif", the stars when rated, and the number of bottles in stock ("2 bottles" / "2 Flaschen").

Clicking a row selects the wine and shows it in the detail. The arrow keys move the selection.

### Sorting

The Sort pop-up names the current field ("Sort: Winery" / "Sortieren: Weingut") and offers:

| Field | English | German | Directions |
|---|---|---|---|
| Winery | Winery | Weingut | A to Z / Z to A |
| Vintage | Vintage | Jahrgang | Oldest first / Newest first |
| Price | Price | Preis | Lowest first / Highest first |
| Rating | Rating | Bewertung | Lowest first / Highest first |
| Drinking window | Drinking Window | Trinkreife | Soonest first / Latest first (by the drink-from year) |
| Date added | Date Added | Hinzugefügt | Oldest first / Newest first |

The default is Winery, A to Z. One sort applies to all four lists and is remembered between launches. Wines that are equal in the chosen field are sorted by winery, then name, then vintage. Wines without a value for the field come last in either direction. Text compares with German collation, ignoring case and accents: Ä sorts with A, "Sérilhan" with "Serilhan".

### Search

The search field filters the selected list as the user types, on top of the filters. It matches winery, name, vintage, grapes (the canonical name and the name as printed, so "Pinot Grigio" finds a Grauburgunder labelled that way), appellation, region, country, vineyard, quality tier and food pairing. It ignores case and accents: "serilhan" finds Château Sérilhan. It does not search the description. `⌘F` puts the cursor in the field; `Esc` clears it.

When nothing matches, the list shows "No wines match "lagrein"" / "Keine Weine passen zu „lagrein"", the line "with the filters Colour: Red, Winery: Diel." / "mit den Filtern Farbe: Rot, Weingut: Diel." when filters are set, and `Reset Filters and Search` / `Filter und Suche zurücksetzen` (design: Empty cellar · no matches). Without a search, the title reads "No wines match these filters" / "Keine Weine passen zu diesen Filtern".

### The empty cellar

With no wines, the list area shows "Your cellar is empty" / "Dein Keller ist leer", "Put label photos in incoming/ and run /import-wines in Claude Code. New bottles appear here by themselves." / "Lege Etikettfotos in incoming/ und führe /import-wines in Claude Code aus. Neue Flaschen erscheinen hier von selbst." and `Show Incoming Folder` / `Eingangsordner zeigen`, which opens `incoming/` in the Finder. Without a chosen folder the button reads `Choose Folder…` and opens the folder choice. A list that is empty while the cellar is not (for example Drunk before any bottle was drunk) shows "No wines in this list" / "Keine Weine in dieser Liste".

### The wine detail

The detail shows the selected wine (design: Main window):

- The winery, then the name in the serif with the vintage, then one line with grapes · quality tier · region, country.
- Five stars to click. Clicking a star sets the rating; clicking the current rating's star again clears it. Accessibility labels read "Rated 4 of 5" / "Mit 4 von 5 bewertet".
- The colour chip, the readiness chip and, for a wine with no bottle in stock, "Not in stock" / "Nicht im Bestand".
- The facts in two columns, each only when it has a value: Type / Weintyp, Taste / Geschmack, Quality / Qualitätsstufe, Grapes / Rebsorten (with percentages when known: "Merlot 60 %"), Appellation / Herkunftsbezeichnung, Region / Region, Vineyard / Lage, Alcohol / Alkohol, Price / Preis, Residual sugar / Restzucker, Acidity / Säure, Drinking window / Trinkreife ("2026–2033"), Serving temp. / Trinktemperatur ("10–12 °C"), Closure / Verschluss, Food pairing / Speiseempfehlung, Organic / Bio, Vegan / Vegan.
- The description, then "Notes" / "Notizen": the user's own notes (see below), then the links found during research.
- The photos as thumbnails, the primary photo first.
- Bottles (see below) and the history of drunk bottles, oldest first: "Drunk on 14 Nov 2026" / "Getrunken am 14.11.2026", with the location when it has one.

With no wine selected, the detail shows "No wine selected" / "Kein Wein ausgewählt".

### Photos

Clicking a thumbnail, or `Space` on a selected thumbnail, opens the photo viewer (design: Label photos): a window titled "Diel Eierfels 2023 — IMG_5107" with "2 of 3" / "2 von 3", the photo fitted to the window, previous and next buttons and a strip of the wine's photos. `←` and `→` step through the photos, `Esc` or `Space` closes the viewer. The window can be resized; a pinch zooms.

### Bottles

The section "Bottles · 2 in stock" / "Flaschen · 2 vorrätig" ("none in stock" / "keine vorrätig") lists every bottle, in-stock ones first (design: Bottles). Each row shows the size ("750 ml"), the location or "No location" / "Kein Lagerort", and the status.

- **`Mark as Drunk…` / `Als getrunken markieren…`** on an in-stock bottle opens a popover "Mark as Drunk" / "Als getrunken markieren" with a date field "Drunk on" / "Getrunken am", today by default, and `Cancel` / `Abbrechen` and `Mark as Drunk` / `Als getrunken markieren`. The bottle becomes drunk on that date and the wine's count drops by one. A date in the future is refused at the field.
- **`Remove…` / `Entfernen…`** on an in-stock bottle asks "Remove this bottle?" / "Diese Flasche entfernen?" with "Diel Eierfels 2023, 750 ml. Remove a bottle that was added by mistake. To record a bottle you opened, use Mark as Drunk." / "Diel Eierfels 2023, 750 ml. Entferne eine Flasche, die versehentlich hinzugefügt wurde. Für eine geöffnete Flasche nutze „Als getrunken markieren"." and `Cancel` / `Remove Bottle` / `Flasche entfernen`. The bottle is deleted. Drunk bottles cannot be removed; they keep the history.
- **A drunk bottle** shows "Drunk on" / "Getrunken am" with its date in an editable date field. A changed date is saved at once.
- **`+ Add Bottle` / `+ Flasche hinzufügen`** adds one 750 ml bottle in stock with the wine's price. A wine with none in stock goes back into In Stock.

A wine whose last bottle is drunk stays in All Wines and Drunk with its history and rating, and leaves In Stock and Ready to Drink.

### Editing in place

Double-clicking a fact in the detail edits it in place (design: Editing in place). Hovering a fact shows where its value came from and how to edit it: "From the label · Double-click to edit" / "Vom Etikett · Zum Bearbeiten doppelklicken", "From research" / "Aus Recherche", "Entered by you" / "Von dir eingegeben".

- **Text and number fields:** winery, name, vintage, quality tier, appellation, region, country, vineyard, alcohol, drinking window (from and until), serving temperature, food pairing, description. The description edits in a multi-line field. `Return` or clicking elsewhere saves, `Esc` restores the old value. An empty field removes the value, except the winery, which cannot be empty.
- **Choice fields** open a pop-up: Type (Wine, Sparkling, Champagne, Kabinett / Wein, Sekt, Champagner, Kabinett), Colour, Taste (Dry, Off-dry, Medium, Sweet, Noble sweet / trocken, halbtrocken, lieblich, süß, edelsüß), Closure (Cork, Screw cap, Glass stopper, Crown cap / Kork, Schraubverschluss, Glasstopfen, Kronkorken). Taste and Closure also offer "None" / "Keine Angabe".
- **Price** edits the price of every bottle of the wine, since all bottles of a wine share one price.
- **Bottle location** edits in place in the bottle row.
- **Invalid values** keep the field open with a red outline and a message below it: a vintage must be a year between 1900 and the current year ("Enter a year between 1900 and 2026, or leave it empty for a wine without vintage." / "Gib ein Jahr zwischen 1900 und 2026 ein oder lass das Feld für einen Wein ohne Jahrgang leer."); alcohol 0–25; drinking-window years 1900–2100 with from not after until; prices not negative.

An edited field is marked as entered by the user, and its hover text says so. When a field that identifies the wine changes (winery, name, vintage, type, quality tier, appellation, vineyard), the wine's match key is recomputed, so a later import of the same wine still finds it. Grapes and photos cannot be edited in this spec.

### Notes

Every wine can carry the user's own notes, for example "Zum Geburtstag öffnen" or "Passt zu Spargel". The section "Notes" / "Notizen" shows them under the description. While a wine has none, the section shows only `Add Note…` / `Notiz hinzufügen…`, which opens a multi-line field. Double-clicking existing notes edits them in place, like any fact: clicking elsewhere saves, `Esc` restores, an empty field removes the notes. Notes are undoable ("Undo Edit Notes"), marked as entered by the user, and `/recommend` reads them. They are not searched.

### Undo

`⌘Z` undoes and `⇧⌘Z` redoes every change made in the app: rating, field edits, notes, Add Bottle, Remove Bottle, Mark as Drunk, a changed drunk date and a changed location. Each action is one step, and the Edit menu names it: "Undo Mark as Drunk" / "„Als getrunken markieren" widerrufen". An import and the copy from the web app are not undoable.

### Importing new bottles

The workflow stays: photos go into `incoming/`, `/import-wines` reads them, researches and writes a review pair to `incoming/review/` (the JSON and the Markdown record). The Mac app does the import.

The app watches `incoming/review/` while it runs and checks it at every launch. Each `.json` file that is new since the folder was chosen is imported once. The import keeps the web app's rules: it checks the whole file first, imports all of it or nothing, adds a bottle to an existing wine when the review says so (by the wine's number) or when the match key matches, creates new grape varieties when needed, and moves the photos out of `incoming/` into the store only after the import succeeded. New wines get the next free number.

A banner above the list shows the import (design: Import):

- **Importing:** "Importing review of 21 Nov, 14:02… 3 bottles, 7 photos" / "Review vom 21. Nov., 14:02 wird importiert… 3 Flaschen, 7 Fotos".
- **Imported:** "Imported 3 bottles: 2 new wines, 1 more bottle of Diel Eierfels 2023. 2 open questions." / "3 Flaschen importiert: 2 neue Weine, 1 weitere Flasche Diel Eierfels 2023. 2 offene Fragen." with `Show New Wines` / `Neue Weine zeigen` (switches to All Wines, clears filters and selects the first new wine) and `Open Review` / `Review öffnen` (opens the Markdown file in the default app). New wines carry a "NEW" / "NEU" mark in the list until the app quits. The banner stays until closed with ×.
- **Failed:** "Couldn't import the review of 21 Nov, 14:02" / "Review vom 21. Nov., 14:02 konnte nicht importiert werden" with the first problem ("Bottle 2: "vintage" must be a whole number.") and "Nothing was imported; the photos stay in incoming/." / "Es wurde nichts importiert; die Fotos bleiben in incoming/." with `Show in Finder` / `Im Finder zeigen` and `Try Again` / `Erneut versuchen`. A failed file is imported again only through Try Again or when the file changes.

Several new files are imported one after the other, oldest first, and the banner shows the last one.

`/import-wines` writes the pair, then waits up to 30 seconds for the app's import and reads the store to report in German what came in. When the app does not run or nothing arrives in time, the command says so ("Schwips läuft nicht — der Import startet beim nächsten Öffnen der App."). It no longer runs `npm run import`.

### Claude Code reads the cellar

`/import-wines` (for grape aliases and match keys) and `/recommend` (for the stock) read the app's store directly with `sqlite3`, read-only. The first time, macOS asks whether the terminal may access data from other apps; the user allows it once. Both commands keep answering in German.

`/recommend` links each recommended wine as `schwips://wine/38`. Clicking the link opens Schwips (or brings it to the front), switches to All Wines, clears filters and search, and selects the wine. An unknown number shows "Wine 38 isn't in your cellar." / "Wein 38 ist nicht in deinem Keller."

### Settings

`⌘,` opens Settings with one pane, "General" / "Allgemein" (design: Settings):

- "Schwips folder:" / "Schwips-Ordner:" with the path, `Choose…` / `Auswählen…`, "Schwips watches incoming/review/ in this folder and imports each new review file once, with its photos from incoming/." / "Schwips beobachtet incoming/review/ in diesem Ordner und importiert jede neue Review-Datei einmal, mit ihren Fotos aus incoming/." and `Show in Finder`.
- "Last import:" / "Letzter Import:" with date, time and bottle count, or "None yet" / "Noch keiner".

When the folder is gone, the path is outlined in red with "This folder can't be found. Choose it again to keep importing." / "Dieser Ordner wurde nicht gefunden. Wähle ihn erneut aus, um weiter zu importieren." Choosing a different folder counts the review files already in it as imported. The copy from the web app is offered in Settings too, as `Copy Cellar from Web App…` / `Keller aus Web-App kopieren…`, but only while the cellar is empty.

### Window and keys

The window remembers its size and position, the selected list, the filters, the sort and the selected wine between launches. The search starts empty.

| Key | Action |
|---|---|
| `⌘F` | Focus the search field |
| `Esc` (in search) | Clear the search |
| `⌥⌘S` | Show or hide the sidebar |
| `⌘,` | Settings |
| `⌘Z` / `⇧⌘Z` | Undo / Redo |
| `⌘D` | Mark as Drunk… for the first in-stock bottle of the selected wine |
| `⇧⌘N` | Add Bottle to the selected wine |
| `Space` | Open the photo viewer on the first photo of the selected wine |
| `←` / `→` (viewer) | Previous / next photo |

The "Wine" / "Wein" menu holds Mark as Drunk…, Add Bottle and Show Photos, disabled without a selection.

## Goals

- In `app/`, `make app` builds `build/Schwips.app`; `open build/Schwips.app` starts it. `swift test` runs the core tests.
- On first launch, the Welcome sheet asks for the runtime folder. Choosing `~/dev/schwips/runtime` shows the web app's counts; `Copy Cellar` copies all 39 wines, 70 bottles and 121 photos, and `/wine/38` in the web app and `schwips://wine/38` show the same wine. The web app's files are unchanged afterwards.
- The sidebar shows In Stock, Ready to Drink, Drunk and All Wines with the same wine counts that a `sqlite3` query on the web app's database gives for those rules.
- Setting Winery to Diel shows only Diel's wines, the toolbar reads "<shown> of <list total> wines · <shown> of <list total> bottles" with numbers that match the list, and the other pop-ups offer only values that Diel's wines have. `Reset` clears every filter.
- Typing "serilhan" finds Château Sérilhan; "pinot grigio" finds wines whose label prints that name. `⌘F` focuses the field, `Esc` clears it. With no match, the list shows "No wines match …" and the reset button.
- Each sort field orders the list in both directions; wines without a value come last. The sort is the same after relaunching.
- `Mark as Drunk…` with today's date moves one bottle to the history and lowers the counts in the list, sidebar and toolbar. `⌘Z` brings it back, `⇧⌘Z` repeats it.
- `Remove…` asks first and deletes only an in-stock bottle. `+ Add Bottle` adds one in stock.
- Double-clicking Vineyard, typing a new value and pressing Return saves it; the hover then says "Entered by you". Typing "20x3" as vintage keeps the field open with the red message. Changing the winery of a wine and then importing a review of the same wine under the new winery adds a bottle to it instead of creating a second wine.
- A review JSON that `/import-wines` writes to `incoming/review/` while the app runs appears within 5 seconds: the banner names the bottles, the new wines carry NEW, the photos are gone from `incoming/` and show in the detail. A broken JSON shows the failure banner, imports nothing and leaves the photos in `incoming/`.
- Review files that were in `incoming/review/` before the folder was chosen are never imported.
- A review written while the app is closed is imported at the next launch.
- `/recommend` reads the stock from the app's store and its `schwips://wine/<number>` links select the wine in the app.
- `Add Note…` on a wine without notes opens a field; the typed notes show under "Notes" after relaunching, and `⌘Z` removes them again.
- All eight filter pop-ups in the sidebar have the same width.
- Started with `-AppleLanguages '(de)' -AppleLocale de_DE`, every label, button, menu item, message and accessibility label is German, and prices, dates and counts use German formats ("26,00 €", "14.11.2026", "2 Flaschen").
- Wines, bottles, ratings, edits, photos and the window state are still there after quitting and relaunching.

## Non-goals

- No iCloud sync and no iOS app in this spec. Only the data's shape is prepared for them.
- No reading of label photos inside the app; `/import-wines` in Claude Code stays the way bottles arrive.
- No editing of grapes, no adding, deleting or reordering photos.
- No deleting a whole wine.
- No lists beyond the four (no Not Ready Yet, no Past Its Best).
- No undo of an import or of the copy from the web app.
- No removal of the web app, Drizzle or the npm scripts; the web app is no longer updated after the copy.
- No export file of the cellar; Claude Code reads the store.
- No App Store or TestFlight build, no notarization.
- No tasting notes beyond the rating and drunk dates the web app has.
