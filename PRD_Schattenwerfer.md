# PRD — „Schattenwerfer"

**Produkt:** Schattenwerfer · Pseudo-AR-Schattensimulator für rechteckige Sonnenschirme
**Dokumentstatus:** Entwurf v0.2 · Stand 19.06.2026
**Owner:** *(zu ergänzen)* · **Beteiligte:** Entwicklung, Design
**Annahmen sind kursiv und mit *(Annahme)* markiert.**

---

## 1. Zusammenfassung

Schattenwerfer ist eine browserbasierte Web-App, mit der man vor Ort prüft, **wohin der Schatten eines rechteckigen Sonnenschirms fällt** — live über das Kamerabild gelegt, berechnet aus dem realen Sonnenstand für den aktuellen Standort und eine wählbare Uhrzeit. Der Nutzer stellt **Länge, Breite, Masthöhe, Neigung und Drehung** des Schirms ein und sieht sofort den projizierten Schatten als 3D-Overlay.

Die App läuft als Webseite in **iOS Safari/Chrome** über einen *Magic-Window*-Ansatz (Live-Kamera + Lagesensoren + GPS), da echtes WebXR-AR auf iOS nicht verfügbar ist. Ein funktionsfähiger Prototyp existiert bereits (runder Schirm); diese PRD definiert die Weiterentwicklung zum **rechteckigen Schirm** und zur ersten veröffentlichbaren Version.

---

## 2. Problem & Chance

Wer einen Sonnenschirm, ein Sonnensegel oder eine Markise kauft oder aufstellt, kann heute **nicht im Voraus sehen**, ob der Schatten zur richtigen Zeit an der richtigen Stelle liegt — etwa über dem Esstisch um 13 Uhr oder über der Café-Terrasse am Nachmittag. Die Entscheidung passiert nach Bauchgefühl; teure Fehlkäufe und falsch platzierte Fundamente sind die Folge.

**Chance:** Eine niedrigschwellige Web-App (kein App-Store-Download) macht den Schattenverlauf vor dem Kauf bzw. der Montage sichtbar und reduziert Fehlentscheidungen. Rechteckige Schirme/Segel sind im Markt verbreitet, in vorhandenen Hobby-Tools aber unterrepräsentiert.

---

## 3. Ziele & Nicht-Ziele

### 3.1 Ziele
- Den Schattenwurf eines **rechteckigen** Schirms physikalisch korrekt aus dem Sonnenstand berechnen und über das Kamerabild legen.
- Bedienung in unter 30 Sekunden vom Öffnen bis zum sichtbaren Schatten.
- Funktioniert ohne Installation in iOS-Safari/-Chrome (über HTTPS).
- Schattenverlauf über den Tag per Zeitschieber erlebbar machen.

### 3.2 Nicht-Ziele (für diese Version)
- **Keine** echte AR-Bodenerkennung/Verdeckung (kein ARKit/WebXR) — bewusst Magic-Window.
- Keine Speicherung/Konten, kein Cloud-Sync, keine Mehrbenutzer-Funktionen.
- Kein Produktkatalog/Shop, keine Kaufabwicklung.
- Kein Android-spezifisches WebXR-Feature-Set in v1 *(Annahme: Fokus iOS zuerst)*.

---

## 4. Zielgruppen / Personas

| Persona | Kontext | Kernbedarf |
|---|---|---|
| **Hausbesitzer:in „Terrasse"** | plant Schirm/Segel für Garten/Balkon | Schatten zur Mittags-/Nachmittagszeit über Sitzbereich |
| **Gastronom:in „Café"** | Außenbestuhlung, mehrere Schirme | Abdeckung der Gästetische über den ganzen Tag |
| **Garten-/Landschaftsplaner:in** | Beratung beim Kunden vor Ort | schnelle, glaubwürdige Visualisierung als Verkaufsargument |

---

## 5. User Stories

1. Als Terrassenbesitzer:in möchte ich **Länge und Breite** meines geplanten Schirms eingeben, damit der simulierte Schatten der realen Fläche entspricht.
2. Als Nutzer:in möchte ich das Telefon hochhalten und den Schatten **über dem echten Boden** sehen, damit ich die Lage sofort einschätzen kann.
3. Als Café-Betreiber:in möchte ich die **Tageszeit verschieben**, um zu sehen, ob der Schatten auch am Nachmittag noch die Tische trifft.
4. Als Nutzer:in möchte ich den rechteckigen Schirm **neigen und drehen**, weil ein Rechteck — anders als ein runder Schirm — eine Ausrichtung hat.
5. Als Planer:in möchte ich die **Schattenfläche/-länge ablesen**, um sie dem Kunden zu nennen.

---

## 6. Funktionale Anforderungen

Priorisierung: **P0** = MVP-kritisch · **P1** = erste Version · **P2** = später.

| ID | Anforderung | Prio |
|---|---|---|
| FR-1 | Rechteckiges Schirmdach mit unabhängig einstellbarer **Länge** und **Breite** | P0 |
| FR-2 | **Drehung (Yaw)** des Rechtecks um die Hochachse, 0–359° | P0 |
| FR-3 | **Neigungswinkel** 0–60° und **Neigungsrichtung** 0–359° | P0 |
| FR-4 | **Masthöhe** einstellbar | P0 |
| FR-5 | Sonnenstand (Azimut/Höhe) aus GPS + Datum/Uhrzeit korrekt berechnen | P0 |
| FR-6 | Schatten als Overlay auf simulierter Bodenebene über dem Live-Kamerabild | P0 |
| FR-7 | Szene folgt der Gerätebewegung (Lagesensoren, Magic Window) | P0 |
| FR-8 | **Zeitschieber** 00:00–23:59 + „Jetzt"-Reset | P1 |
| FR-9 | Anzeige von **Schattenlänge/-fläche** und Sonnen-Azimut/-Höhe | P1 |
| FR-10 | **Norden-Kalibrierung** per Kompass + manuelle Feinjustierung | P1 |
| FR-11 | Sonnen-Kompass-HUD (Sonne relativ zur Blickrichtung) | P1 |
| FR-12 | Zeitraffer „Schattenverlauf 9–18 Uhr" als Animation | P2 |
| FR-13 | Mehrere Schirme gleichzeitig platzieren | P2 |
| FR-14 | Materialwahl Stoff (durchscheinend vs. blickdicht → Schattenstärke) | P2 |

### 6.1 Rechteckige Geometrie (Detail zu FR-1/FR-2)
- Das Dach wird als **flaches Rechteck** (Quader mit geringer Höhe) modelliert, definiert durch **Länge L** und **Breite B** in Metern; **Fläche = L × B** wird angezeigt.
  - Wertebereich *(Annahme)*: L und B je **1,5–6,0 m**, Schrittweite 0,1 m.
- Da ein Rechteck **nicht rotationssymmetrisch** ist (anders als der bisherige runde Schirm), ist ein **eigener Drehregler (Yaw)** erforderlich, der die Längsachse relativ zu Norden ausrichtet.
- Reihenfolge der Transformationen am Mastkopf: **Yaw (um Hochachse) → Neigungsrichtung → Neigungswinkel**. Die Neigung kippt das gedrehte Rechteck als Ganzes.
- **Testbar:** Bei L=4, B=2, Yaw=90°, Neigung=0°, Sonne im Zenit muss der Bodenschatten ein achsenparalleles 2×4-Rechteck mit Fläche 8 m² sein (±5 %).

### 6.2 Schattenberechnung (Detail zu FR-5/FR-6)
- Sonnenposition über etablierten Algorithmus (NOAA/SunCalc): Azimut von Norden im Uhrzeigersinn, Höhe in Grad.
- Ein **Richtungslicht** wird gemäß Sonnenvektor positioniert; der Schatten entsteht durch Projektion des Dachs auf eine **ebene Bodenfläche** ~1,5 m unter dem Gerät *(Annahme: flacher Untergrund)*.
- Bei Sonnenhöhe ≤ 0° (Sonne unter Horizont): kein Schatten, Hinweis „Nacht/Dämmerung".
- **Testbar:** Schattenlänge des Masts ≈ Höhe ÷ tan(Sonnenhöhe), Abweichung < 5 % gegenüber Referenzrechner.

---

## 7. UX-Anforderungen

- **Onboarding-Screen** erklärt die drei Berechtigungen (Kamera, Standort, Bewegung) und startet sie über **eine Nutzer-Geste** (iOS-Pflicht für Sensorabfrage).
- **HUD-Prinzip:** Kamerabild ist der Held; Bedienelemente liegen als halbtransparente Leisten oben (Messwerte/Kompass) und unten (Regler).
- Regler unten: Länge, Breite, Drehung, Masthöhe, Neigungswinkel, Neigungsrichtung, Tageszeit, Norden-Feinjustierung; jeder mit Live-Wertanzeige.
- Klartext-Labels aus Nutzersicht („Schattenlänge", „Norden setzen"), keine Systembegriffe.
- **Quality-Floor:** responsiv bis Mobil, sichtbarer Fokus, `prefers-reduced-motion` respektiert, kein Zoom-Springen (`viewport-fit=cover`).

---

## 8. Technische Anforderungen & Constraints

- **Plattform:** Web, Single-File-`index.html`, Three.js (r128) für 3D, SunCalc-Algorithmus inline.
- **Sensorik:** `getUserMedia` (Rückkamera), `deviceorientation`/`webkitCompassHeading`, `navigator.geolocation`.
- **Harte Constraints:**
  - WebXR-AR ist auf iOS (Safari **und** Chrome/Firefox, alle WebKit) **nicht verfügbar** → Magic-Window ist Pflichtansatz, keine Bodenerkennung/Verdeckung.
  - Kamera, GPS und Lagesensoren erfordern **HTTPS** (oder `localhost`); kein `file://`.
  - iOS ≥ 13 verlangt **`requestPermission()` aus einer Nutzer-Geste** für Orientierung/Bewegung.
  - Absoluter Kompass auf iOS nur via `webkitCompassHeading`; Restabweichung ist über manuelle Feinjustierung auszugleichen.
- **Datenschutz:** Alle Berechnungen laufen lokal auf dem Gerät; **keine** Übertragung von Standort/Kamera. Im UI klar kommuniziert.
- **Performance-Ziel** *(Annahme)*: ≥ 30 fps auf iPhone der letzten ~4 Generationen.

---

## 9. Erfolgsmetriken

| Metrik | Zielwert (Vorschlag) |
|---|---|
| Time-to-first-shadow (Öffnen → sichtbarer Schatten) | < 30 s |
| Anteil Sessions mit erfolgreich gestarteter Kamera **und** GPS-Fix | > 80 % |
| Anteil Nutzer, die mind. einen Regler verändern | > 60 % |
| Anteil Nutzer, die den Zeitschieber nutzen | > 40 % |
| Berechnungsgenauigkeit Sonnenstand vs. Referenz | Abweichung < 1° |

*(Annahme: Erhebung anonym/lokal oder per einfacher, datensparsamer Telemetrie — in v1 ggf. nur qualitativ.)*

---

## 10. Release-Plan / Meilensteine

- **M0 — Prototyp (erledigt):** runder Schirm, Sonnenstand, Magic-Window, Zeit- und Norden-Regler.
- **M1 — Rechteck-MVP (P0):** FR-1 bis FR-7; runde durch rechteckige Geometrie ersetzt, Yaw-Regler ergänzt; Hosting auf HTTPS.
- **M2 — Erste Version (P1):** FR-8 bis FR-11 stabilisiert; On-Device-Test der Kompass-/Nordlogik; UX-Politur.
- **M3 — Ausbau (P2):** Zeitraffer, mehrere Schirme, Materialwahl.
- **M4 — Natives AR (optional/Zukunft):** ARKit-Pfad (Swift oder Expo/ViroReact) für echte Bodenprojektion.

---

## 11. Risiken & Gegenmaßnahmen

| Risiko | Auswirkung | Gegenmaßnahme |
|---|---|---|
| Kompass-Ausrichtung ungenau | Schatten zeigt in falsche Richtung | manuelle Feinjustierung + Kalibrier-Button; On-Device-Tuning |
| Unebener/geneigter Untergrund | Schatten-Lage stimmt nicht exakt | flacher Untergrund als Annahme dokumentieren; später Höhenkalibrierung |
| iOS-Sensor-Berechtigung abgelehnt | kein Magic Window | Fallback: manuelle Heading-Steuerung, Schatten weiter berechenbar |
| Erwartung „echtes AR" | Enttäuschung | Onboarding kommuniziert Magic-Window-Prinzip; nativen Pfad als Option benennen |
| CDN für Three.js nicht erreichbar | App lädt nicht | klarer Fehlerhinweis; optional Lib bündeln |

---

## 12. Offene Fragen

1. Soll v1 **rein iOS** sein oder Android (mit echtem WebXR) gleich mitnehmen?
2. Wertebereiche für L/B/Höhe final festlegen — am realen Produktsortiment ausrichten?
3. Brauchen wir **Sonnensegel** (frei drehbares Polygon) als eigene Form neben Rechteck/Rund?
4. Telemetrie ja/nein, und falls ja in welchem datensparsamen Umfang?
5. Distribution: GitHub Pages, eigene Domain, oder später App Clip?

---

## 13. Out of Scope / Zukunft

- Echte AR-Verdeckung und Bodenmesh (ARKit/LiDAR), Schatten auf realer 3D-Geometrie.
- Mehrtägige Sonnen-/Jahresverlaufsanalyse, Verschattung durch Gebäude/Bäume.
- Produktempfehlungen, Maße-Export, Teilen/Export von Szenen.

---

## Anhang — Glossar

- **Magic Window:** Kamerabild + Lagesensoren erzeugen ein „Fenster", das sich mit dem Gerät dreht — Pseudo-AR ohne echte Umgebungserkennung.
- **Azimut:** Himmelsrichtung der Sonne, von Norden im Uhrzeigersinn (0°=N, 90°=O, 180°=S, 270°=W).
- **Sonnenhöhe:** Winkel der Sonne über dem Horizont (0°=Horizont, 90°=Zenit).
- **Yaw:** Drehung des Schirms um die senkrechte Hochachse.
