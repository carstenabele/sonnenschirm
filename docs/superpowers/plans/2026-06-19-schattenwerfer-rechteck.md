# Schattenwerfer Rechteck-Version — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den runden-Schirm-Prototyp zu einer veröffentlichbaren Version mit rechteckigem Dach (Länge/Breite/Yaw), Form-Umschalter, Schattenflächen-Anzeige und Datumsauswahl ausbauen und auf GitHub Pages bereitstellen.

**Architecture:** Single-File `index.html` (Three.js r128, lokal gevendort) bleibt erhalten. Die reine Rechen-Mathematik (Sonnenstand, Schattenprojektion, Fläche) wird in ein DOM-/Three-freies ES-Modul `src/sun-math.mjs` ausgelagert, das sowohl die App als auch headless Node-Tests nutzen. UI baut inkrementell auf dem Prototyp auf.

**Tech Stack:** HTML/CSS/Vanilla-JS, Three.js r128 (lokal), ES-Module, Node built-in test runner (`node --test`), GitHub Pages.

## Global Constraints

- **Single-File-App:** Logik lebt in `index.html`; ausgelagert wird nur die pure Mathematik in `src/sun-math.mjs`. Kein Build-Step, kein Framework, kein Bundler.
- **Three.js r128, lokal:** `vendor/three.min.js`, keine CDN-Abhängigkeit zur Laufzeit.
- **`src/sun-math.mjs` ist pur:** keine `document`-, `window`- oder `THREE`-Referenzen. Vektoren sind einfache `{x, y, z}`-Objekte.
- **Weltachsen:** +X = Osten, +Y = oben, −Z = Norden. Winkel in Funktionsargumenten in Grad, intern Radiant.
- **Konstanten:** `EYE = 1.5` (Gerätehöhe über Boden, m), `FRONT = 4.0` (Schirmabstand nach Norden, m). Bodenebene `y = −EYE`.
- **Wertebereiche:** L, B je 1,5–6,0 m (Schritt 0,1); Yaw 0–359° (Schritt 1); Masthöhe 1,6–3,2 m (Schritt 0,05).
- **Klartext-Labels (Deutsch):** „Länge", „Breite", „Drehung", „Schattenfläche". Keine Systembegriffe im UI.
- **Tests:** `node --test` muss grün sein. Pure-Mathematik per TDD; UI per Playwright-Smoke + manueller Gerätetest.
- **Sprache:** UI-Texte und Commit-Messages auf Deutsch; Code-Kommentare wie im Prototyp (Deutsch).

---

## File Structure

| Datei | Verantwortung | Status |
|---|---|---|
| `index.html` | App: UI, Three-Szene, Sensorik, Verdrahtung | Modifizieren |
| `src/sun-math.mjs` | Pure Funktionen: Sonnenstand, Sonnenvektor, Schattenprojektion, Fläche, Mastschatten | Neu |
| `vendor/three.min.js` | Three.js r128 lokal | Neu |
| `tests/shadow.test.mjs` | Headless Node-Tests der Mathematik | Neu |
| `package.json` | `npm test` → `node --test`, `"type": "module"` | Neu |
| `.nojekyll` | Verhindert Jekyll-Filterung auf GitHub Pages | Neu |

---

## Task 1: Projektgerüst — Three.js vendoren, Pages-Dateien, npm

**Files:**
- Create: `vendor/three.min.js`, `.nojekyll`, `package.json`
- Modify: `index.html:195` (Script-Tag auf lokalen Pfad)

**Interfaces:**
- Consumes: nichts.
- Produces: lokales `vendor/three.min.js` (globales `THREE`, r128); `npm test` als Testkommando.

- [ ] **Step 1: Three.js r128 lokal herunterladen**

```bash
mkdir -p vendor
curl -sSL -o vendor/three.min.js https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js
```

- [ ] **Step 2: Download verifizieren**

Run: `head -c 200 vendor/three.min.js; echo; wc -c < vendor/three.min.js`
Expected: Three.js-Header-Kommentar mit „r128"; Dateigröße > 500000 Bytes.

- [ ] **Step 3: `.nojekyll` anlegen (leer)**

```bash
touch .nojekyll
```

- [ ] **Step 4: `package.json` anlegen**

```json
{
  "name": "schattenwerfer",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
```

- [ ] **Step 5: `index.html` auf lokales Three.js umstellen**

In `index.html` die Zeile
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
```
ersetzen durch
```html
<script src="./vendor/three.min.js"></script>
```

- [ ] **Step 6: Referenz prüfen**

Run: `grep -n "three.min.js" index.html`
Expected: genau eine Zeile, `./vendor/three.min.js`, kein `cdnjs` mehr.

- [ ] **Step 7: Commit**

```bash
git add vendor/three.min.js .nojekyll package.json index.html
git commit -m "build: Three.js r128 lokal vendoren + Pages-Gerüst"
```

---

## Task 2: Sonnenstand-Modul (`sunPosition`, `sunVector`)

**Files:**
- Create: `src/sun-math.mjs`, `tests/shadow.test.mjs`

**Interfaces:**
- Consumes: nichts.
- Produces:
  - `sunPosition(date: Date, lat: number, lng: number) → { azimuth: number, altitude: number }` (Radiant; Azimut von Norden im UZS).
  - `sunVector(azN: number, alt: number) → { x: number, y: number, z: number }` (Einheitsvektor zur Sonne; +X Ost, +Y oben, −Z Nord).
  - Export der Konstante `DEG = Math.PI / 180` und `RAD = 180 / Math.PI`.

- [ ] **Step 1: Failing test schreiben** (`tests/shadow.test.mjs`)

Physikalische Referenz: Zur Sommersonnenwende ist die Mittagshöhe der Sonne = 90 − Breite + 23,44°. Für Frankfurt (50,11°) ≈ 63,33°, Azimut ≈ 180° (Süden). Wir suchen das Tagesmaximum durch Abtasten, unabhängig von der exakten Mittagszeit.

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sunPosition, sunVector, RAD } from '../src/sun-math.mjs';

const LAT = 50.11, LNG = 8.68; // Frankfurt

function maxAltitudeOfDay(year, monthIdx, day, lat, lng) {
  let best = { altitude: -Infinity, azimuth: 0 };
  for (let m = 0; m < 1440; m += 5) {
    const date = new Date(Date.UTC(year, monthIdx, day, 0, m, 0));
    const p = sunPosition(date, lat, lng);
    if (p.altitude > best.altitude) best = p;
  }
  return best;
}

test('Sommersonnenwende: Mittagshöhe ~63.33°, Azimut ~Süden', () => {
  const peak = maxAltitudeOfDay(2026, 5, 21, LAT, LNG); // 21.06.2026
  const altDeg = peak.altitude * RAD;
  const azDeg = peak.azimuth * RAD;
  assert.ok(Math.abs(altDeg - 63.33) < 1, `Höhe ${altDeg.toFixed(2)}° != ~63.33°`);
  assert.ok(Math.abs(azDeg - 180) < 1, `Azimut ${azDeg.toFixed(2)}° != ~180°`);
});

test('Wintersonnenwende deutlich niedriger als Sommer', () => {
  const summer = maxAltitudeOfDay(2026, 5, 21, LAT, LNG).altitude * RAD;
  const winter = maxAltitudeOfDay(2026, 11, 21, LAT, LNG).altitude * RAD;
  assert.ok(summer - winter > 40, `Differenz ${(summer - winter).toFixed(1)}° zu klein`);
});

test('sunVector: Sonne im Zenit zeigt gerade nach oben', () => {
  const v = sunVector(0, Math.PI / 2);
  assert.ok(Math.abs(v.x) < 1e-9 && Math.abs(v.z) < 1e-9, 'x,z ~0');
  assert.ok(Math.abs(v.y - 1) < 1e-9, 'y ~1');
});

test('sunVector: Sonne im Osten am Horizont', () => {
  const v = sunVector(Math.PI / 2, 0); // Azimut 90° = Ost, Höhe 0
  assert.ok(Math.abs(v.x - 1) < 1e-9, 'x ~1 (Ost)');
  assert.ok(Math.abs(v.y) < 1e-9, 'y ~0');
});
```

- [ ] **Step 2: Test ausführen, Fehlschlag bestätigen**

Run: `node --test tests/shadow.test.mjs`
Expected: FAIL — Modul `../src/sun-math.mjs` existiert nicht.

- [ ] **Step 3: Minimal-Implementierung** (`src/sun-math.mjs`)

Formel aus dem Prototyp übernehmen (`index.html` Zeilen ~221–253), `THREE.Vector3` durch `{x,y,z}` ersetzen.

```javascript
// src/sun-math.mjs — pure Mathematik (kein DOM/Three)
export const DEG = Math.PI / 180;
export const RAD = 180 / Math.PI;

// Sonnenstand (kompakte NOAA/SunCalc-Variante).
// Azimut von Norden im Uhrzeigersinn, Höhe in Radiant.
export function sunPosition(date, lat, lng) {
  const dayMs = 86400000, J1970 = 2440588, J2000 = 2451545;
  const e = 23.4397 * DEG;
  const d = date.valueOf() / dayMs - 0.5 + J1970 - J2000;
  const M = (357.5291 + 0.98560028 * d) * DEG;
  const C = (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * DEG;
  const P = 102.9372 * DEG;
  const L = M + C + P + Math.PI;
  const dec = Math.asin(Math.sin(e) * Math.sin(L));
  const ra  = Math.atan2(Math.cos(e) * Math.sin(L), Math.cos(L));
  const lw  = -lng * DEG;
  const phi = lat * DEG;
  const theta = (280.16 + 360.9856235 * d) * DEG - lw;
  const H = theta - ra;
  const azS = Math.atan2(Math.sin(H), Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi));
  let azN = azS + Math.PI;
  azN = (azN % (2 * Math.PI) + 2 * Math.PI) % (2 * Math.PI);
  const alt = Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H));
  return { azimuth: azN, altitude: alt };
}

// Einheitsvektor zur Sonne. +X Ost, +Y oben, −Z Nord.
export function sunVector(azN, alt) {
  const ch = Math.cos(alt);
  return {
    x: Math.sin(azN) * ch,
    y: Math.sin(alt),
    z: -Math.cos(azN) * ch,
  };
}
```

- [ ] **Step 4: Test ausführen, Erfolg bestätigen**

Run: `node --test tests/shadow.test.mjs`
Expected: PASS (4 Tests grün).

- [ ] **Step 5: Commit**

```bash
git add src/sun-math.mjs tests/shadow.test.mjs package.json
git commit -m "feat: Sonnenstand als pures, testbares Modul"
```

---

## Task 3: Schattengeometrie (`projectToGround`, `polygonArea`, `rectCornersWorld`, `shadowMetrics`, `mastShadowLength`)

**Files:**
- Modify: `src/sun-math.mjs`, `tests/shadow.test.mjs`

**Interfaces:**
- Consumes: `sunVector` (Task 2).
- Produces:
  - `projectToGround(p: {x,y,z}, sunVec: {x,y,z}, yGround: number) → { x: number, z: number }`
  - `polygonArea(pts: Array<{x,z}>) → number` (Shoelace, immer ≥ 0).
  - `rectCornersWorld({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front }) → Array<{x,y,z}>` (4 Welt-Eckpunkte des Dachs).
  - `mastShadowLength(height: number, altitudeRad: number) → number` (m; `Infinity` wenn Höhe ≤ 0).
  - `shadowMetrics({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front, azimuthRad, altitudeRad }) → { areaM2: number, lengthM: number, isNight: boolean }`

**Transformationsreihenfolge am Mastkopf (PRD §6.1):** Yaw (um Y) → Neigungsrichtung (um Y) → Neigungswinkel (um X). Lokale Eckpunkte des flachen Rechtecks: `(±L/2, 0, ±B/2)`. Danach Rotation, dann Translation zum Mastkopf `(0, −eye + height, −front)`.

- [ ] **Step 1: Failing tests ergänzen** (`tests/shadow.test.mjs` erweitern)

```javascript
import {
  projectToGround, polygonArea, rectCornersWorld,
  shadowMetrics, mastShadowLength,
} from '../src/sun-math.mjs';

test('polygonArea: Einheitsquadrat = 1', () => {
  const sq = [{x:0,z:0},{x:1,z:0},{x:1,z:1},{x:0,z:1}];
  assert.ok(Math.abs(polygonArea(sq) - 1) < 1e-9);
});

test('projectToGround: senkrecht von oben projiziert auf gleiche x/z', () => {
  const g = projectToGround({x:2,y:3,z:-4}, {x:0,y:1,z:0}, -1.5);
  assert.ok(Math.abs(g.x - 2) < 1e-9 && Math.abs(g.z - (-4)) < 1e-9);
});

test('Ankerfall: L=4,B=2,Yaw=90,Neigung=0,Zenit → Fläche ~8 m²', () => {
  const az = 0, alt = Math.PI / 2; // Zenit
  const m = shadowMetrics({
    L: 4, B: 2, yawDeg: 90, tiltDeg: 0, tiltDirDeg: 0,
    height: 2.4, eye: 1.5, front: 4.0, azimuthRad: az, altitudeRad: alt,
  });
  assert.equal(m.isNight, false);
  assert.ok(Math.abs(m.areaM2 - 8) / 8 < 0.05, `Fläche ${m.areaM2.toFixed(2)} != ~8`);
});

test('Ankerfall: Fläche unabhängig vom Yaw (Zenit, Neigung 0)', () => {
  const base = { L:4, B:2, tiltDeg:0, tiltDirDeg:0, height:2.4, eye:1.5, front:4.0, azimuthRad:0, altitudeRad:Math.PI/2 };
  const a0 = shadowMetrics({ ...base, yawDeg: 0 }).areaM2;
  const a90 = shadowMetrics({ ...base, yawDeg: 90 }).areaM2;
  assert.ok(Math.abs(a0 - a90) / a0 < 0.05);
});

test('mastShadowLength ≈ Höhe / tan(Höhe)', () => {
  const altDeg = 30, alt = altDeg / RAD;
  const len = mastShadowLength(2.4, alt);
  const ref = 2.4 / Math.tan(alt);
  assert.ok(Math.abs(len - ref) / ref < 0.05);
});

test('Nacht: Sonne unter Horizont → isNight true', () => {
  const m = shadowMetrics({
    L:4, B:2, yawDeg:0, tiltDeg:0, tiltDirDeg:0,
    height:2.4, eye:1.5, front:4.0, azimuthRad:0, altitudeRad: -0.2,
  });
  assert.equal(m.isNight, true);
});
```

- [ ] **Step 2: Tests ausführen, Fehlschlag bestätigen**

Run: `node --test tests/shadow.test.mjs`
Expected: FAIL — Funktionen nicht exportiert.

- [ ] **Step 3: Implementierung ergänzen** (`src/sun-math.mjs` anhängen)

```javascript
// 2D-Rotation in der x/z-Ebene um Winkel a (rad), positiv im UZS um +Y.
function rotY(p, a) {
  const c = Math.cos(a), s = Math.sin(a);
  return { x: p.x * c + p.z * s, y: p.y, z: -p.x * s + p.z * c };
}
// Rotation um X-Achse um Winkel a (rad).
function rotX(p, a) {
  const c = Math.cos(a), s = Math.sin(a);
  return { x: p.x, y: p.y * c - p.z * s, z: p.y * s + p.z * c };
}

export function rectCornersWorld({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front }) {
  const yaw = yawDeg * DEG, dir = tiltDirDeg * DEG, tip = tiltDeg * DEG;
  const hx = L / 2, hz = B / 2;
  const local = [
    { x:  hx, y: 0, z:  hz },
    { x:  hx, y: 0, z: -hz },
    { x: -hx, y: 0, z: -hz },
    { x: -hx, y: 0, z:  hz },
  ];
  const topY = -eye + height;
  return local.map((p) => {
    // Reihenfolge: Yaw → Neigungsrichtung → Neigungswinkel
    let q = rotY(p, yaw);
    q = rotY(q, dir);
    q = rotX(q, tip);
    return { x: q.x, y: q.y + topY, z: q.z - front };
  });
}

export function projectToGround(p, sunVec, yGround) {
  const t = (p.y - yGround) / sunVec.y;
  return { x: p.x - sunVec.x * t, z: p.z - sunVec.z * t };
}

export function polygonArea(pts) {
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const p = pts[i], q = pts[(i + 1) % pts.length];
    a += p.x * q.z - q.x * p.z;
  }
  return Math.abs(a) / 2;
}

export function mastShadowLength(height, altitudeRad) {
  if (altitudeRad <= 0) return Infinity;
  return height / Math.tan(altitudeRad);
}

export function shadowMetrics({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front, azimuthRad, altitudeRad }) {
  if (altitudeRad <= 0) return { areaM2: 0, lengthM: Infinity, isNight: true };
  const sv = sunVector(azimuthRad, altitudeRad);
  const yGround = -eye;
  const corners = rectCornersWorld({ L, B, yawDeg, tiltDeg, tiltDirDeg, height, eye, front });
  const ground = corners.map((c) => projectToGround(c, sv, yGround));
  return {
    areaM2: polygonArea(ground),
    lengthM: mastShadowLength(height, altitudeRad),
    isNight: false,
  };
}
```

- [ ] **Step 4: Tests ausführen, Erfolg bestätigen**

Run: `node --test tests/shadow.test.mjs`
Expected: PASS (alle Tests grün, Task 2 + Task 3).

- [ ] **Step 5: Commit**

```bash
git add src/sun-math.mjs tests/shadow.test.mjs
git commit -m "feat: Schattenprojektion, Fläche und Mastschatten (getestet)"
```

---

## Task 4: `index.html` nutzt das Mathe-Modul (Refactor, runde Form unverändert)

**Files:**
- Modify: `index.html` (inline `sunPosition`/`sunVector` entfernen, Modul importieren)

**Interfaces:**
- Consumes: `sunPosition`, `sunVector` aus `./src/sun-math.mjs`.
- Produces: unveränderte App-Funktion (runder Schirm), aber Sonnenstand kommt aus dem Modul.

Hinweis: Das bestehende Inline-`sunVector` liefert `THREE.Vector3`; das Modul liefert `{x,y,z}`. An den Verwendungsstellen (`updateSun`) das Ergebnis in `new THREE.Vector3(v.x, v.y, v.z)` wrappen.

- [ ] **Step 1: Script-Block auf Modul umstellen**

In `index.html` das `<script>`-Tag mit der App-Logik von `<script>` auf `<script type="module">` ändern und am Anfang importieren:

```html
<script type="module">
"use strict";
import { sunPosition, sunVector, shadowMetrics } from './src/sun-math.mjs';
```

- [ ] **Step 2: Inline-Duplikate entfernen**

Die Inline-Funktionen `sunPosition(...)` (ca. Zeilen 221–242) und `sunVector(...)` (ca. 246–253) aus `index.html` löschen. `DEG`/`RAD`-Konstanten in `index.html` bleiben (lokal genutzt).

- [ ] **Step 3: Verwendung von `sunVector` anpassen**

In `updateSun()` die Zeile `const v = sunVector(azimuth, altitude);` ersetzen durch:

```javascript
const sv = sunVector(azimuth, altitude);
const v = new THREE.Vector3(sv.x, sv.y, sv.z);
```

- [ ] **Step 4: Statischen Server starten und Smoke-Test (Playwright)**

Run: `python3 -m http.server 8099 &` (im Repo-Root), dann mit dem Playwright-Tool `http://localhost:8099/` öffnen.
Prüfen:
- Konsole zeigt keine Fehler beim Laden (vor „Simulation starten").
- Das Onboarding-Overlay (`#veil`) ist sichtbar, Button „Simulation starten" vorhanden.
- Kein roter Three-Ladefehler im `#fine`-Text.

Danach Server stoppen: `kill %1`.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "refactor: index.html nutzt sun-math.mjs (keine Inline-Duplikate)"
```

---

## Task 5: Rechteckiges Dach + Form-Zustand + Transformationsreihenfolge

**Files:**
- Modify: `index.html` (Three-Szene: zweites Mesh, `state.shape`, `state.L/B/yawDeg`, `rebuildParasol`)

**Interfaces:**
- Consumes: nichts Neues.
- Produces: `state.shape` ∈ `{"round","rect"}` (Default `"rect"`), `state.L`, `state.B`, `state.yawDeg`; `canopyRect`-Mesh; `rebuildParasol()` berücksichtigt Form + Yaw.

- [ ] **Step 1: State erweitern**

Im `state`-Objekt ergänzen:

```javascript
shape: "rect",        // "round" | "rect"
L: 4.0, B: 2.0,       // Rechteck-Länge/-Breite (m)
yawDeg: 0,            // Drehung der Längsachse
```

- [ ] **Step 2: Rechteck-Mesh anlegen**

Nach dem bestehenden `canopy` (rund) ergänzen:

```javascript
const canopyRound = canopy; // Alias für Klarheit
const canopyRect = new THREE.Mesh(
  new THREE.BoxGeometry(1, 0.08, 1),
  canopyMat
);
canopyRect.castShadow = true;
tiltPivot.add(canopyRect);
```

- [ ] **Step 3: `rebuildParasol()` für beide Formen + Yaw**

`rebuildParasol()` ersetzen durch:

```javascript
function rebuildParasol() {
  const h = state.height;
  pole.scale.set(1, h, 1);
  pole.position.set(0, h / 2, 0);
  tiltPivot.position.set(0, h, 0);

  const isRect = state.shape === "rect";
  canopyRound.visible = !isRect;
  canopyRect.visible = isRect;

  if (isRect) {
    canopyRect.scale.set(state.L, 1, state.B); // L entlang X, B entlang Z
    canopyRect.position.set(0, 0.04, 0);
  } else {
    const radius = Math.sqrt(state.area / Math.PI);
    canopyRound.scale.set(radius, 1 + radius * 0.18, radius);
    canopyRound.position.set(0, 0.16 * (1 + radius * 0.18), 0);
    finial.position.set(0, 0.34 * (1 + radius * 0.18), 0);
  }
  finial.visible = !isRect;

  // Reihenfolge: Yaw → Neigungsrichtung → Neigungswinkel
  const yaw = (isRect ? state.yawDeg : 0) * DEG;
  const dir = state.tiltDirDeg * DEG;
  const ang = state.tiltDeg * DEG;
  const qYaw = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -yaw);
  const qDir = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(0, 1, 0), -dir);
  const qTip = new THREE.Quaternion().setFromAxisAngle(new THREE.Vector3(1, 0, 0), ang);
  tiltPivot.quaternion.copy(qYaw).multiply(qDir).multiply(qTip);
}
```

- [ ] **Step 4: Smoke-Test (Playwright)**

Run: `python3 -m http.server 8099 &`, Seite öffnen, „Simulation starten" tippen (Kamera/GPS schlagen headless fehl, werden aber abgefangen). Prüfen: keine unbehandelten Konsolenfehler; Canvas rendert (kein Throw in `rebuildParasol`). Server stoppen: `kill %1`.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: rechteckiges Dach + Form-Zustand + Yaw-Transformation"
```

---

## Task 6: UI — Form-Umschalter, Länge/Breite/Drehung-Regler, Flächen-Chip

**Files:**
- Modify: `index.html` (HTML-Dock, CSS für Toggle, `bindSliders`, `updateSun` für Flächenanzeige)

**Interfaces:**
- Consumes: `state.shape/L/B/yawDeg`, `rebuildParasol`, `shadowMetrics`.
- Produces: Bedienelemente + sichtbarer Flächen-Readout.

- [ ] **Step 1: Form-Toggle + Flächen-Chip ins HTML (`.dockbar`)**

In `index.html` die `.dockbar` so erweitern (vor den Buttons):

```html
<div class="seg" id="shapeToggle" role="group" aria-label="Schirmform">
  <button class="seg-btn" data-shape="round">Rund</button>
  <button class="seg-btn active" data-shape="rect">Rechteck</button>
</div>
<span class="chip">Schatten <b id="chipLen">—</b></span>
<span class="chip">Fläche <b id="chipArea">—</b></span>
<span class="spacer"></span>
```

(Den bisherigen `<span class="chip">Schatten …</span>` durch diese beiden Chips ersetzen; doppelte vermeiden.)

- [ ] **Step 2: CSS für Segmented-Control ergänzen** (im `<style>`)

```css
.seg{display:inline-flex;border:1px solid var(--line);border-radius:999px;overflow:hidden}
.seg-btn{font-family:var(--sans);font-size:11.5px;font-weight:600;color:var(--muted);
  background:transparent;border:none;padding:6px 12px;cursor:pointer}
.seg-btn.active{background:var(--sun);color:#1a1206}
```

- [ ] **Step 3: Regler ins Grid (Länge, Breite, Drehung)**

Im `.grid` den „Schirmfläche"-`.ctrl` ersetzen/ergänzen. Drei neue `.ctrl`-Blöcke für Rechteck plus den bestehenden Flächen-Block (für Rund). Jeder `.ctrl` bekommt eine `id`-Hülle zum Ein-/Ausblenden:

```html
<div class="ctrl" id="ctrlLength" data-shape="rect">
  <div class="row"><label>Länge</label><span class="val" id="vLength">4.0 m</span></div>
  <input type="range" id="length" min="1.5" max="6" step="0.1" value="4.0">
</div>
<div class="ctrl" id="ctrlWidth" data-shape="rect">
  <div class="row"><label>Breite</label><span class="val" id="vWidth">2.0 m</span></div>
  <input type="range" id="width" min="1.5" max="6" step="0.1" value="2.0">
</div>
<div class="ctrl" id="ctrlYaw" data-shape="rect">
  <div class="row"><label>Drehung</label><span class="val" id="vYaw">Nord–Süd · 0°</span></div>
  <input type="range" id="yaw" min="0" max="359" step="1" value="0">
</div>
<div class="ctrl" id="ctrlArea" data-shape="round">
  <div class="row"><label>Schirmfläche</label><span class="val" id="vArea">7.1 m²</span></div>
  <input type="range" id="area" min="1" max="20" step="0.1" value="7.1">
</div>
```

- [ ] **Step 4: Sichtbarkeitslogik + Bindings in `bindSliders()`**

Ergänzen:

```javascript
function applyShapeVisibility() {
  const isRect = state.shape === "rect";
  document.querySelectorAll('[data-shape]').forEach((el) => {
    if (el.classList.contains('seg-btn')) {
      el.classList.toggle('active', el.dataset.shape === state.shape);
    } else {
      el.classList.toggle('hidden', el.dataset.shape !== state.shape);
    }
  });
  rebuildParasol();
  updateSun();
}

document.getElementById('shapeToggle').addEventListener('click', (e) => {
  const btn = e.target.closest('.seg-btn'); if (!btn) return;
  state.shape = btn.dataset.shape;
  applyShapeVisibility();
});

$("length").addEventListener("input", e => {
  state.L = +e.target.value; $("vLength").textContent = state.L.toFixed(1) + " m";
  rebuildParasol(); updateSun();
});
$("width").addEventListener("input", e => {
  state.B = +e.target.value; $("vWidth").textContent = state.B.toFixed(1) + " m";
  rebuildParasol(); updateSun();
});
$("yaw").addEventListener("input", e => {
  state.yawDeg = +e.target.value;
  $("vYaw").textContent = `${axisLabel(state.yawDeg)} · ${state.yawDeg}°`;
  rebuildParasol(); updateSun();
});
```

Und eine Hilfsfunktion für die Längsachsen-Beschriftung (bei `dirLabel` ergänzen):

```javascript
function axisLabel(deg){
  const a = ((deg % 180) + 180) % 180;
  if (a < 22.5 || a >= 157.5) return "Nord–Süd";
  if (a < 67.5) return "NO–SW";
  if (a < 112.5) return "Ost–West";
  return "NW–SO";
}
```

Am Ende von `bindSliders()` initiale Labels + Sichtbarkeit setzen:

```javascript
$("length").dispatchEvent(new Event("input"));
$("width").dispatchEvent(new Event("input"));
$("yaw").dispatchEvent(new Event("input"));
applyShapeVisibility();
```

- [ ] **Step 5: Flächenanzeige in `updateSun()`**

In `updateSun()` nach der Mastschatten-Längenberechnung ergänzen:

```javascript
if (state.shape === "rect" && altitude > 0) {
  const m = shadowMetrics({
    L: state.L, B: state.B, yawDeg: state.yawDeg,
    tiltDeg: state.tiltDeg, tiltDirDeg: state.tiltDirDeg,
    height: state.height, eye: EYE, front: FRONT,
    azimuthRad: azimuth, altitudeRad: altitude,
  });
  $("chipArea").textContent = (m.areaM2 > 999 ? ">999" : m.areaM2.toFixed(1)) + " m²";
} else {
  $("chipArea").textContent = altitude > 0 ? "—" : "Nacht";
}
```

- [ ] **Step 6: Smoke-Test (Playwright)**

Run: `python3 -m http.server 8099 &`, Seite öffnen, „Simulation starten" tippen. Prüfen:
- Toggle „Rund/Rechteck" schaltet die sichtbaren Regler um (Länge/Breite/Drehung ↔ Schirmfläche).
- Regler Länge/Breite/Drehung verändern die Wertanzeigen.
- `#chipArea` zeigt einen Zahlenwert (sofern Sonne über Horizont; sonst „Nacht").
- Keine Konsolenfehler.
Server stoppen: `kill %1`.

- [ ] **Step 7: Commit**

```bash
git add index.html
git commit -m "feat: Form-Umschalter, Länge/Breite/Drehung-Regler, Flächenanzeige"
```

---

## Task 7: Datumsauswahl

**Files:**
- Modify: `index.html` (Datumsfeld, `state.simDate`, `currentDate`, „Jetzt"-Reset)

**Interfaces:**
- Consumes: `currentDate`, `updateSun`.
- Produces: `state.simDate` (ISO `YYYY-MM-DD` oder `null` = heute), Datumsfeld `#datein`.

- [ ] **Step 1: State + HTML**

State ergänzen: `simDate: null,` (null = heute).
In `.dockbar` (nach dem Form-Toggle) ein Datumsfeld einfügen:

```html
<input type="date" id="datein" class="datein" aria-label="Datum">
```

CSS ergänzen:

```css
.datein{font-family:var(--mono);font-size:11.5px;color:var(--text);
  background:rgba(255,255,255,.08);border:1px solid var(--line);
  border-radius:8px;padding:5px 8px}
```

- [ ] **Step 2: `currentDate()` kombiniert Datum + Uhrzeit**

`currentDate()` ersetzen:

```javascript
function currentDate() {
  const base = state.simDate ? new Date(state.simDate + "T00:00:00") : new Date();
  if (!state.manualClock && !state.simDate) return new Date();
  const d = new Date(base);
  d.setHours(0, 0, 0, 0);
  d.setMinutes(state.manualClock ? state.clockMin :
    (new Date().getHours() * 60 + new Date().getMinutes()));
  return d;
}
```

- [ ] **Step 3: Datums-Binding + „Jetzt"-Reset erweitern**

In `bindSliders()`:

```javascript
$("datein").addEventListener("change", e => {
  state.simDate = e.target.value || null;
  updateSun();
});
```

Den bestehenden `btnNow`-Handler erweitern, sodass er Datum **und** Uhrzeit zurücksetzt:

```javascript
$("btnNow").addEventListener("click", () => {
  state.manualClock = false; state.simDate = null;
  $("datein").value = "";
  $("vClock").textContent = "jetzt";
  const now = new Date(); $("clock").value = now.getHours()*60 + now.getMinutes();
  updateSun(); toast("Aktuelles Datum & Uhrzeit");
});
```

- [ ] **Step 4: Smoke-Test (Playwright)**

Run: `python3 -m http.server 8099 &`, Seite öffnen, „Simulation starten". Prüfen:
- Datum auf `2026-12-21` setzen → `#roEl` (Höhe) sinkt deutlich gegenüber `2026-06-21`.
- „Jetzt" leert das Datumsfeld und setzt `#vClock` auf „jetzt".
- Keine Konsolenfehler.
Server stoppen: `kill %1`.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: Datumsauswahl zusätzlich zum Tageszeit-Schieber"
```

---

## Task 8: Veröffentlichung auf GitHub Pages

**Files:**
- Keine Code-Änderung; Repo-Konfiguration + Push.

**Interfaces:**
- Consumes: alle vorigen Tasks (Repo-Root enthält `index.html`, `vendor/`, `src/`, `.nojekyll`).
- Produces: Live-URL `https://carstenabele.github.io/sonnenschirm/`.

- [ ] **Step 1: Gesamte Testsuite grün**

Run: `npm test`
Expected: alle Tests PASS.

- [ ] **Step 2: Alles committen und pushen**

```bash
git status
git push origin main
```

- [ ] **Step 3: GitHub Pages aktivieren (gh CLI)**

```bash
gh api -X POST repos/carstenabele/sonnenschirm/pages \
  -f "source[branch]=main" -f "source[path]=/" 2>&1 || \
gh api -X PUT repos/carstenabele/sonnenschirm/pages \
  -f "source[branch]=main" -f "source[path]=/"
```

(Falls `gh` nicht authentifiziert: manuell unter Repo → Settings → Pages → Source „Deploy from a branch" → `main` / `/ (root)`.)

- [ ] **Step 4: Deployment prüfen**

Run (nach ~1–2 Min):
```bash
gh api repos/carstenabele/sonnenschirm/pages --jq '.html_url, .status'
curl -sI https://carstenabele.github.io/sonnenschirm/ | head -1
```
Expected: `status: built`; HTTP `200`.

- [ ] **Step 5: Hinweis an Nutzer (Gerätetest)**

Kamera, Kompass und Magic Window sind nur am echten iPhone (iOS Safari/Chrome, HTTPS) verifizierbar. Nutzer bitten, die Live-URL auf dem iPhone zu öffnen und Sensor-/AR-Verhalten zu prüfen (PRD-M2).

---

## Self-Review

**Spec-Abdeckung:**
- FR-1 (L/B): Task 5+6 ✓ · FR-2 (Yaw): Task 5+6 ✓ · §6.1 Reihenfolge: Task 5 ✓
- FR-9 (Fläche/Länge): Task 3 (Mathe) + Task 6 (Anzeige) ✓
- Form-Umschalter: Task 5+6 ✓ · Datum: Task 7 ✓
- Three lokal vendoren: Task 1 ✓ · Pure Mathe-Modul: Task 2+3 ✓
- Tests (Sonnenstand <1°, Ankerfall 8 m² ±5 %, Mastschatten <5 %, Nacht): Task 2+3 ✓
- GitHub Pages: Task 8 ✓
- Unverändert übernommen (FR-3/4/6/7/8/10/11): Prototyp, durch Refactor Task 4 nicht gebrochen ✓

**Platzhalter:** keine offenen TODO/TBD; alle Code-Schritte vollständig.

**Typkonsistenz:** `shadowMetrics`-Felder (`L,B,yawDeg,tiltDeg,tiltDirDeg,height,eye,front,azimuthRad,altitudeRad`) identisch in Task 3 (Definition), Task 3-Tests und Task 6 (Aufruf). `state`-Felder (`shape,L,B,yawDeg,simDate`) konsistent in Task 5/6/7.
