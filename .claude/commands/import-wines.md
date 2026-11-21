---
description: Read wine label photos from runtime/incoming/, research, group into bottles, and import them
---

# /import-wines

Du bist der Wein-Importeur für **Schwips**. Deine Aufgabe: die Fotos in `runtime/incoming/` lesen, zu Flaschen gruppieren, die Wein-Daten extrahieren und recherchieren, ein **Review-Artefakt** schreiben. Den Import macht die **Mac-App Schwips**: Sie beobachtet `runtime/incoming/review/`, importiert jede neue Review-JSON genau einmal (alles oder nichts) und verschiebt die Fotos erst danach in ihren Speicher. Die App ist der einzige DB-Writer; du schreibst nie in ihre Datenbank und wartest nicht auf eine separate Freigabe. Die Review-Dateien bleiben als lesbarer Beleg (mit eingebetteten Fotos) erhalten; falls dir danach ein Fehler auffällt, korrigiert der Nutzer ihn in der App (Doppelklick auf das Feld).

## Die Datenbank der App (nur lesen)

Lies den Bestand ausschließlich **read-only** mit `sqlite3 -readonly` (ohne `-readonly` kann eine Schreibsperre die App blockieren):

```
DB="$HOME/Library/Containers/de.juergenalbertsen.schwips/Data/Library/Application Support/Schwips/Schwips.store"
sqlite3 -readonly "$DB" "…"
```

Beim ersten Zugriff fragt macOS, ob das Terminal auf Daten anderer Apps zugreifen darf; der Nutzer erlaubt das einmal. Die Tabellen (SwiftData/Core Data): `ZWINE` (Weine; `ZNUMBER` ist die **Weinnummer** für `match_existing` und Links, `ZSIGNATURE` der Abgleichschlüssel, Felder wie `ZPRODUCER`, `ZNAME`, `ZVINTAGE`, `ZWINETYPERAW`, `ZQUALITYLEVEL`, `ZAPPELLATION`, `ZVINEYARD`), `ZBOTTLE` (`ZWINE` → `ZWINE.Z_PK`, `ZSTATUSRAW` = `in_stock`/`consumed`/`gifted`), `ZWINEGRAPE` (`ZWINE`, `ZGRAPE` → `ZGRAPE.Z_PK`, `ZLABELNAME`, `ZPERCENTAGE`), `ZGRAPE` (`ZNAME` kanonisch, `ZCOLORRAW`), `ZGRAPEALIAS` (`ZALIAS`, `ZGRAPE`), `ZIMPORTRECORD` (Import-Protokoll je Datei: `ZFILENAME`, `ZSTATUSRAW` = `imported`/`failed`/`skipped`, `ZMESSAGE`, `ZBOTTLECOUNT`, `ZNEWWINENUMBERS`, `ZMATCHEDWINENUMBERS`, `ZOPENQUESTIONCOUNT`). Datumswerte sind Sekunden seit 2001-01-01: `datetime(Z… + 978307200, 'unixepoch')`.

**Sprache:** Kommuniziere mit dem Nutzer durchgängig auf **Deutsch** — Fortschritt, Rückfragen und die Review-Markdown. Code, Bezeichner, Spaltennamen und die gespeicherten Enum-Werte bleiben Englisch.

## Ablauf

1. **Fotos lesen.** Liste `runtime/incoming/*.jpeg` und lies jedes Foto.

2. **Zu Flaschen gruppieren.** Erst nach **Dateinamen-Reihenfolge** (fortlaufende Aufnahmenummern gehören meist zur selben Flasche und liegen nebeneinander), dann **visuell** bestätigen/korrigieren: Vorderetikett, Rücketikett, Kapsel und **beliebig viele** überlappende/gedrehte Aufnahmen desselben Etiketts gehören zusammen. Eine Gruppe hat **keine feste Größe** (ein Foto oder viele). Ist die Zuordnung echt mehrdeutig, notiere das als deutsche `open_question` statt zu raten.

3. **Extrahieren + recherchieren (pro Gruppe).**
   - Etiketten können in **beliebiger Sprache** sein (Deutsch, Italienisch, Französisch, Englisch, Spanisch …) — extrahiere unabhängig davon.
   - Freitextfelder (`producer`, `region`, `vineyard`, `name`, `description`) **wie gedruckt** speichern; kontrollierte Felder (`color`, `sweetness`, `closure`, `wine_type`) auf die **englischen Enum-Werte** normalisieren.
   - **`wine_type`** ist eine grobe Kategorie mit genau vier Werten: `"kabinett"` (deutsches Prädikat „Kabinett" auf dem Etikett) > `"champagne"` (Appellation Champagne) > `"sparkling"` (jeder andere Sekt/Crémant/Spumante/Cava …) > `"wine"` (alles andere, still). Prüfe in dieser Reihenfolge. Feinere Angaben (GG, Lagenwein, „Rotwein trocken" …) gehören nicht hierhin, sondern in `quality_level`/`description`/`extra_data`.
   - **Rebsorten:** jeden gedruckten Namen auf die **kanonische Sorte** (deutsch bevorzugt) auflösen, z. B. gedruckt „Pinot Grigio" → `canonical: "Grauburgunder"`; gedruckte Schreibweise in `label_name`; `color` setzen. Nutze bekannte Aliase aus `ZGRAPEALIAS` (z. B. `sqlite3 -readonly "$DB" "SELECT a.ZALIAS, g.ZNAME FROM ZGRAPEALIAS a JOIN ZGRAPE g ON g.Z_PK = a.ZGRAPE"`) und dein Wissen. Unbekannte Sorte → als neue kanonische Sorte vorschlagen **oder** deutsche `open_question` — nie eine Dublette erfinden.
   - **Appellations-Weine:** Steht statt Rebsorten eine Herkunftsbezeichnung auf dem Etikett (Chianti, Bordeaux, Rioja, Châteauneuf-du-Pape …), setze `appellation` (Provenienz `label`) und **recherchiere** die typische/rechtliche Zusammensetzung (Chianti → Sangiovese-dominiert). Trage diese Sorten mit Provenienz `research`, `label_name: null` und typischen Prozenten ein und ergänze eine deutsche `open_question` („Rebsorten aus Appellation … abgeleitet, nicht vom Etikett").
   - Fehlende/ergänzende Daten (Trinkreife, Rebsortenanteile, Bewertungen, Regionsfakten) per **WebSearch** recherchieren.
   - **Preis recherchieren.** Suche per WebSearch nach dem aktuellen Verkaufspreis (Erzeuger-Shop, Fachhändler) für genau diesen Wein/Jahrgang und trage ihn als `bottle.current_value` ein (nicht `purchase_price` — der bleibt `null`, sofern der Nutzer nicht explizit sagt, was er bezahlt hat). Findest du keinen belastbaren Preis, lass `current_value` `null` und ergänze eine `open_question`.
   - Alles Gedruckte ohne eigene Spalte in `extra_data` ablegen (Fassausbau, Handlese, Abfüllnummer, Prämierungen …).
   - Pro Feld die Herkunft in `data_sources` festhalten (`"label"` | `"research"`), plus eine Gesamt-`import_confidence` in `[0,1]`.

4. **Nichts raten.** Ist ein Feld unleserlich oder fehlt: erst per WebSearch versuchen (Provenienz `research`); bleibt es unklar, Feld `null` lassen, `import_confidence` senken und eine deutsche Notiz in `open_questions` der Flasche ergänzen (z. B. „Jahrgang auf Kapsel unleserlich — 2019 oder 2021?"). Im interaktiven Lauf darfst du den Nutzer direkt auf Deutsch fragen; Ungelöstes bleibt in `open_questions`.

5. **Dedup vorschlagen.** Berechne die Kandidaten-Signatur (gleiche Normalisierung wie `app/Sources/SchwipsCore/Logic/Signature.swift`: kanonische Sorten, deutsche Umlaut-Faltung zuerst, dann übrige Akzente entfernt) und suche bestehende Weine mit gleicher/ähnlicher `ZSIGNATURE` in `ZWINE`. Gib pro Flasche einen Vorschlag: `{"action":"new_wine"}` oder `{"action":"match_existing","wine_id":N}` (= Bestand erhöhen), wobei `N` die **Weinnummer** `ZNUMBER` ist, nicht `Z_PK`. Bei `new_wine` gleicht die App zusätzlich selbst über den Schlüssel ab.

6. **Review-Artefakt schreiben.** Ein Paar mit gemeinsamem Zeitstempel:
   - `runtime/incoming/review/<timestamp>.json` — maschinenlesbar, exakt in der Form von `reviewFileSchema` (siehe unten); Eingabe fürs CLI.
   - `runtime/incoming/review/<timestamp>.md` — deutsch, menschenlesbar: pro Flasche die Fotogruppe **als eingebettete Bild-Vorschau verlinkt** (Markdown-Bildlinks auf die Originale, z. B. `![IMG_5106](../IMG_5106.jpeg)` — relativer Pfad von `runtime/incoming/review/` aus, also `../<dateiname>`), die extrahierten + recherchierten Felder, den Dedup-Vorschlag, `import_confidence` und **`open_questions` prominent** samt aller Felder mit niedriger Konfidenz.

7. **Import durch die App abwarten.** Schreibe die JSON zuletzt (nach der `.md`), damit die App nur fertige Paare sieht. Warte dann bis zu 30 Sekunden (alle 3 Sekunden prüfen), bis die App die Datei protokolliert hat:
   ```
   sqlite3 -readonly "$DB" "SELECT ZSTATUSRAW, ZMESSAGE, ZBOTTLECOUNT, ZNEWWINENUMBERS, ZMATCHEDWINENUMBERS, ZOPENQUESTIONCOUNT FROM ZIMPORTRECORD WHERE ZFILENAME = '<timestamp>.json'"
   ```
   - `imported`: Fasse dem Nutzer kurz zusammen, was importiert wurde (Flaschen, neue Weine mit Nummern, Flaschen zu bestehenden Weinen), und weise auf offene Punkte aus `open_questions` hin.
   - `failed`: Nenne die Meldung aus `ZMESSAGE`, korrigiere die JSON und schreibe sie neu (geänderte Dateien importiert die App erneut). Die Fotos liegen dann noch in `runtime/incoming/`.
   - Kein Eintrag nach 30 Sekunden (oder `pgrep -x Schwips` findet nichts): „Schwips läuft nicht — der Import startet beim nächsten Öffnen der App."

## JSON-Form (`reviewFileSchema`)

```jsonc
{
  "generated_at": "<ISO-Zeitstempel>",
  "bottles": [
    {
      "photos": ["IMG_5106.jpeg", "IMG_5107.jpeg"], // beliebig viele
      "dedup": { "action": "new_wine" },              // oder { "action": "match_existing", "wine_id": N }
      "confidence": 0.0,                               // 0..1
      "open_questions": ["deutsche Notiz …"],          // optional
      "wine": {
        "producer": "…", "name": null, "vintage": 2021,
        "wine_type": "wine|sparkling|champagne|kabinett", "color": "white|red|rose|orange",
        "sweetness": "dry|off-dry|medium|sweet|noble-sweet",
        "quality_level": "…", "region": "…", "country": "…",
        "appellation": null, "vineyard": null,
        "abv": 12.5, "residual_sugar_gl": null, "acidity_gl": null,
        "drink_from": 2024, "drink_until": 2035,
        "description": "…", "food_pairing": "…",
        "serving_temp_c": "10-12", "closure": "cork|screwcap|glass|crown",
        "is_organic": false, "is_vegan": false,
        "external_links": ["https://…"],
        "extra_data": {},
        "data_sources": { "producer": "label", "drink_until": "research" },
        "import_confidence": 0.0,
        "grapes": [
          { "canonical": "Grauburgunder", "label_name": "Pinot Grigio", "color": "white", "percentage": null }
        ]
      },
      "bottle": {
        "bottle_size_ml": 750, "location": null,
        "purchase_date": null, "purchase_price": null, "purchase_vendor": null,
        "current_value": null, "status": "in_stock",
        "consumed_date": null, "personal_rating": null
      }
    }
  ]
}
```

Halte dich exakt an diese Form, damit die App die JSON beim ersten Versuch annimmt (sie prüft sie wie `app/Sources/SchwipsCore/Import/ReviewFile.swift`). Enum-Werte immer englisch; nullbare Felder als `null` setzen, nicht weglassen.
