# Design — Schattenwerfer: Rechteck-Version + Veröffentlichung

**Stand:** 2026-06-19 · **Status:** Freigegeben (Brainstorming)
**Bezug:** `PRD_Schattenwerfer.md` (Meilenstein M1 + Teile M2)

---

## 1. Ziel & Umfang

Den bestehenden Prototyp (runder Schirm, Single-File `index.html`) zur ersten
veröffentlichbaren Version weiterentwickeln und auf GitHub Pages bereitstellen.

**In Scope (v1):**

- Rechteckiges Dach mit getrennter **Länge (L)** und **Breite (B)** (FR-1).
- **Drehung/Yaw** des Rechtecks um die Hochachse (FR-2).
- Form-**Umschalter** rund ↔ rechteckig.
- **Schattenfläche/-länge** numerisch anzeigen (FR-9).
- **Datumsauswahl** zusätzlich zum vorhandenen Tageszeit-Schieber.
- Transformationsreihenfolge Yaw → Neigungsrichtung → Neigungswinkel (§6.1).
- Three.js lokal vendoren (CDN-Risiko entschärfen).
- Deployment auf GitHub Pages (HTTPS).

**Out of Scope (v1):** Zeitraffer-Animation (FR-12), mehrere Schirme (FR-13),
Materialwahl (FR-14), Sonnensegel-Polygon, Telemetrie, echtes AR/WebXR.

**Bereits im Prototyp vorhanden (unverändert übernommen):** Sonnenstand,
Magic Window/Lagesensoren, Masthöhe (FR-4), Neigungswinkel + -richtung (FR-3),
Tageszeit-Schieber + „Jetzt" (FR-8), Norden setzen + Feinjustierung (FR-10),
Sonnen-Kompass-HUD (FR-11), visueller Schattenwurf via ShadowMap (FR-6/FR-7).

---

## 2. Architektur

- **Single-File-Prinzip bleibt:** Eine `index.html` an Repo-Root, Three.js r128,
  SunCalc-Mathematik inline/als Modul. Kein Build-Step (GitHub-Pages-freundlich).
- **Inkrementell auf dem Prototyp aufbauen**, nicht neu schreiben.
- **Three.js lokal vendoren:** `vendor/three.min.js` statt CDN-Abhängigkeit
  (PRD-Risiko §11 „CDN nicht erreichbar"). `index.html` lädt lokal.
- **Testbare Mathematik isolieren:** Reine Funktionen ohne DOM-/Three-Abhängigkeit
  in `src/sun-math.mjs` (ES-Modul). `index.html` bindet es per
  `<script type="module">` ein; das Node-Testskript importiert dieselbe Quelle —
  kein dupliziertes Rechen-Codestück.

### Dateien

| Datei | Zweck |
|---|---|
| `index.html` | App (UI, Three-Szene, Sensorik, Verdrahtung) |
| `src/sun-math.mjs` | Pure Funktionen: Sonnenstand, Sonnenvektor, Schattenprojektion, Fläche |
| `vendor/three.min.js` | Three.js r128, lokal |
| `.nojekyll` | verhindert Jekyll-Filterung auf Pages |
| `tests/shadow.test.mjs` | headless Node-Tests der Mathematik |

---

## 3. Geometrie & Form-Umschalter

- Neuer Zustand `state.shape` ∈ `{"round","rect"}`, Standard **`"rect"`**.
- Form-Toggle (segmented control „Rund | Rechteck") in der `dockbar`.
- **Zwei Dach-Meshes** am `tiltPivot`, jeweils nur eines `visible`:
  - `canopyRound`: bestehende `ConeGeometry` (unverändert).
  - `canopyRect`: neuer flacher Quader (`BoxGeometry`), L entlang X, B entlang Z,
    Dicke ~0,08 m (flach, damit der Schattenwurf der Fläche entspricht).
- `rebuildParasol()` skaliert nur das aktive Mesh.

### Transformationen am Mastkopf (PRD §6.1)

Reihenfolge **Yaw → Neigungsrichtung → Neigungswinkel**:

```
tiltPivot.quaternion = qYaw · qTiltDir · qTilt
```

- `qYaw`: Drehung um Welt-Y (Hochachse), aus `state.yawDeg`.
- `qTiltDir`, `qTilt`: wie im Prototyp (Richtung um Y, Kippen um X).
- Yaw wirkt fachlich nur auf das Rechteck; bei „Rund" wird der Yaw-Regler
  ausgeblendet (rotationssymmetrisch).

### Wertebereiche

| Größe | Bereich | Schritt |
|---|---|---|
| Länge L | 1,5–6,0 m | 0,1 m |
| Breite B | 1,5–6,0 m | 0,1 m |
| Yaw | 0–359° | 1° |
| Masthöhe | 1,6–3,2 m | 0,05 m (wie Prototyp) |
| Schirmfläche (rund) | wie Prototyp | wie Prototyp |

---

## 4. Schattenberechnung

### Visuell (unverändert)

Three.js-ShadowMap projiziert beliebige Geometrie (auch den Quader) auf die
Bodenebene `y = −EYE`. Keine Änderung nötig.

### Numerisch (FR-9) — in `src/sun-math.mjs`

1. 4 Eckpunkte des Dach-Rechtecks in Weltkoordinaten ermitteln (nach Yaw/Neigung).
2. Jede Ecke entlang des Sonnenvektors auf die Bodenebene projizieren:
   `P_boden = P − sonnenVektor · (P.y − y_boden) / sonnenVektor.y`.
3. **Fläche** des projizierten Vierecks per Shoelace-Formel.
4. **Länge** = maximale Ausdehnung (größte Diagonale/Kante) des Schattenpolygons.
5. Sonnenhöhe ≤ 0° → kein Schatten, Status „Nacht".

Funktionen (pure, DOM-/Three-frei; nutzen einfache `{x,y,z}`-Vektoren):

- `sunPosition(date, lat, lng) → {azimuth, altitude}` (Radiant) — aus Prototyp übernommen.
- `sunVector(azN, alt) → {x,y,z}`
- `rectCornersWorld({L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye}) → [{x,y,z}×4]`
- `projectToGround(point, sunVec, yGround) → {x,z}`
- `polygonArea(points2D) → number` (Shoelace)
- `shadowMetrics(...) → {areaM2, lengthM, isNight}`

### Anzeige

- Bestehender Chip „Schatten <Länge>" bleibt.
- Zweiter Chip „Fläche <X> m²" daneben.
- Bei Nacht: „Nacht".

---

## 5. Zeit & Datum

- Neuer Zustand `state.simDate` (Jahr/Monat/Tag); Uhrzeit weiter aus `clockMin`.
- Natives Datumsfeld (`<input type="date">`) in der `dockbar`.
- `currentDate()` kombiniert gewähltes Datum + gewählte Uhrzeit.
- **„Jetzt"** setzt Datum **und** Uhrzeit auf aktuell; Label „jetzt", wenn
  heute + aktuelle Zeit aktiv.

---

## 6. UI-Änderungen (Dock)

- `dockbar`: Form-Toggle „Rund | Rechteck", Datumsfeld, zweiter Flächen-Chip,
  bestehende Buttons „Norden setzen" / „Jetzt".
- Regler-Grid kontextabhängig:
  - **Rechteck:** Länge, Breite, Drehung (Yaw) sichtbar; „Schirmfläche" verborgen.
  - **Rund:** Schirmfläche sichtbar; Yaw verborgen.
  - Immer: Masthöhe, Neigungswinkel, Neigungsrichtung, Tageszeit, Norden feinjustieren.
- Klartext-Labels (PRD §7): „Länge", „Breite", „Drehung". Yaw zeigt Klartext-
  Richtung der Längsachse (analog Neigungsrichtung).
- Erhalten bleiben: `prefers-reduced-motion`, sichtbarer Fokus, `viewport-fit=cover`,
  Live-Wertanzeige je Regler.

---

## 7. Tests (headless, Node)

`tests/shadow.test.mjs` importiert `src/sun-math.mjs`:

1. **Sonnenstand-Genauigkeit:** fixes Datum + Uhrzeit + Ort (z. B. 21.06.2026
   12:00, Frankfurt) gegen Referenzwert → Abweichung < 1° (PRD §9).
2. **Ankerfall Geometrie:** L=4, B=2, Yaw=90°, Neigung=0°, Sonne im Zenit →
   projizierte Fläche 8 m² ±5 % (PRD §6.1).
3. **Mastschatten-Länge:** ≈ Höhe ÷ tan(Sonnenhöhe), < 5 % (PRD §6.2).
4. **Nacht:** Sonnenhöhe ≤ 0° → `isNight === true`, kein Schatten.

**Nicht headless prüfbar (am Gerät, PRD-M2):** Kamera, Kompass/`webkitCompassHeading`,
Magic-Window-Tracking, iOS-Permission-Flow.

---

## 8. Deployment (GitHub Pages)

- Statisch vom Branch `main`, Ordner `/ (root)`.
- Dateien an Root: `index.html`, `vendor/three.min.js`, `src/sun-math.mjs`, `.nojekyll`.
- Pages-Source aktivieren (per `gh` CLI oder manuell in den Repo-Settings).
- Ergebnis-URL: `https://carstenabele.github.io/sonnenschirm/` (HTTPS → Kamera/GPS/
  Sensoren freigeschaltet, PRD §8).

---

## 9. Risiken / offene Punkte

- Sensorik nur am echten iPhone verifizierbar (akzeptiert, PRD-M2).
- `<input type="date">`-Darstellung auf iOS Safari: nativ, ausreichend.
- Three.js r128 lokal: Dateigröße ~600 KB im Repo — akzeptabel für Robustheit.
