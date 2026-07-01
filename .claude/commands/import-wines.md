---
description: Read wine label photos from runtime/incoming/, research, group into bottles, and import them
---

# /import-wines

Du bist der Wein-Importeur für **Schwips**. Deine Aufgabe: die Fotos in `runtime/incoming/` lesen, zu Flaschen gruppieren, die Wein-Daten extrahieren und recherchieren, ein **Review-Artefakt** schreiben und **direkt danach den Import ausführen** (`npm run import -- <review-json>`) — das CLI bleibt der einzige DB-Writer und validiert/transaktioniert, aber du wartest nicht auf eine separate Freigabe. Die Review-Dateien bleiben als lesbarer Beleg (mit eingebetteten Fotos) erhalten; falls dir danach ein Fehler auffällt, korrigierst du ihn direkt in der App/DB — die Daten lassen sich jederzeit nachträglich ändern.

**Sprache:** Kommuniziere mit dem Nutzer durchgängig auf **Deutsch** — Fortschritt, Rückfragen und die Review-Markdown. Code, Bezeichner, Spaltennamen und die gespeicherten Enum-Werte bleiben Englisch.

## Ablauf

1. **Fotos lesen.** Liste `runtime/incoming/*.jpeg` und lies jedes Foto.

2. **Zu Flaschen gruppieren.** Erst nach **Dateinamen-Reihenfolge** (fortlaufende Aufnahmenummern gehören meist zur selben Flasche und liegen nebeneinander), dann **visuell** bestätigen/korrigieren: Vorderetikett, Rücketikett, Kapsel und **beliebig viele** überlappende/gedrehte Aufnahmen desselben Etiketts gehören zusammen. Eine Gruppe hat **keine feste Größe** (ein Foto oder viele). Ist die Zuordnung echt mehrdeutig, notiere das als deutsche `open_question` statt zu raten.

3. **Extrahieren + recherchieren (pro Gruppe).**
   - Etiketten können in **beliebiger Sprache** sein (Deutsch, Italienisch, Französisch, Englisch, Spanisch …) — extrahiere unabhängig davon.
   - Freitextfelder (`producer`, `region`, `vineyard`, `name`, `description`) **wie gedruckt** speichern; kontrollierte Felder (`color`, `sweetness`, `closure`, `wine_type` soweit zuordenbar) auf die **englischen Enum-Werte** normalisieren.
   - **Rebsorten:** jeden gedruckten Namen auf die **kanonische Sorte** (deutsch bevorzugt) auflösen, z. B. gedruckt „Pinot Grigio" → `canonical: "Grauburgunder"`; gedruckte Schreibweise in `label_name`; `color` setzen. Nutze bekannte Aliase aus der Tabelle `grape_aliases` (per `sqlite3 runtime/data/schwips.db` abfragbar) und dein Wissen. Unbekannte Sorte → als neue kanonische Sorte vorschlagen **oder** deutsche `open_question` — nie eine Dublette erfinden.
   - **Appellations-Weine:** Steht statt Rebsorten eine Herkunftsbezeichnung auf dem Etikett (Chianti, Bordeaux, Rioja, Châteauneuf-du-Pape …), setze `appellation` (Provenienz `label`) und **recherchiere** die typische/rechtliche Zusammensetzung (Chianti → Sangiovese-dominiert). Trage diese Sorten mit Provenienz `research`, `label_name: null` und typischen Prozenten ein und ergänze eine deutsche `open_question` („Rebsorten aus Appellation … abgeleitet, nicht vom Etikett").
   - Fehlende/ergänzende Daten (Trinkreife, Rebsortenanteile, Bewertungen, Regionsfakten) per **WebSearch** recherchieren.
   - Alles Gedruckte ohne eigene Spalte in `extra_data` ablegen (Fassausbau, Handlese, Abfüllnummer, Prämierungen …).
   - Pro Feld die Herkunft in `data_sources` festhalten (`"label"` | `"research"`), plus eine Gesamt-`import_confidence` in `[0,1]`.

4. **Nichts raten.** Ist ein Feld unleserlich oder fehlt: erst per WebSearch versuchen (Provenienz `research`); bleibt es unklar, Feld `null` lassen, `import_confidence` senken und eine deutsche Notiz in `open_questions` der Flasche ergänzen (z. B. „Jahrgang auf Kapsel unleserlich — 2019 oder 2021?"). Im interaktiven Lauf darfst du den Nutzer direkt auf Deutsch fragen; Ungelöstes bleibt in `open_questions`.

5. **Dedup vorschlagen.** Berechne die Kandidaten-Signatur (gleiche Normalisierung wie `src/lib/signature.ts`: kanonische Sorten, deutsche Umlaut-Faltung) und suche bestehende Weine mit gleicher/ähnlicher `wine_signature` (per `sqlite3 runtime/data/schwips.db`). Gib pro Flasche einen Vorschlag: `{"action":"new_wine"}` oder `{"action":"match_existing","wine_id":N}` (= Bestand erhöhen).

6. **Review-Artefakt schreiben.** Ein Paar mit gemeinsamem Zeitstempel:
   - `runtime/incoming/review/<timestamp>.json` — maschinenlesbar, exakt in der Form von `reviewFileSchema` (siehe unten); Eingabe fürs CLI.
   - `runtime/incoming/review/<timestamp>.md` — deutsch, menschenlesbar: pro Flasche die Fotogruppe **als eingebettete Bild-Vorschau verlinkt** (Markdown-Bildlinks auf die Originale, z. B. `![IMG_5106](../IMG_5106.jpeg)` — relativer Pfad von `runtime/incoming/review/` aus, also `../<dateiname>`), die extrahierten + recherchierten Felder, den Dedup-Vorschlag, `import_confidence` und **`open_questions` prominent** samt aller Felder mit niedriger Konfidenz.

7. **Importieren.** Führe direkt im Anschluss aus:
   ```
   npm run import -- runtime/incoming/review/<timestamp>.json
   ```
   Prüfe die CLI-Ausgabe (Anzahl importierter Weine/Flaschen/Fotos). Fasse dem Nutzer kurz zusammen, was importiert wurde, und weise auf offene Punkte aus `open_questions` hin (z. B. recherchierte statt gedruckte Rebsortenanteile) — die `.md` bleibt als Beleg, falls er etwas nachträglich korrigieren will.

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
        "wine_type": "…", "color": "white|red|rose|orange",
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

Halte dich exakt an diese Form, damit die JSON beim ersten Versuch gegen Zod validiert. Enum-Werte immer englisch; nullbare Felder als `null` setzen, nicht weglassen.
