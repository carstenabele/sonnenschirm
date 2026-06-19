# Schattenwerfer — iOS native App

**Schattenwerfer** ist eine native iOS-App (SwiftUI + ARKit + RealityKit), die den Schatten eines rechteckigen oder runden Sonnenschirms in echtem AR über den real erkannten Boden legt. Der Sonnenstand wird aus dem Gerätestandort und der aktuellen Datum/Uhrzeit berechnet.

---

## Projektstruktur

```
ios/
├── project.yml                  # XcodeGen-Projektdefinition
├── Sources/                     # SwiftUI-App + ARScene
│   ├── SchattenwerferApp.swift
│   ├── ContentView.swift
│   ├── ARSceneView.swift        # ARKit + RealityKit
│   ├── ParasolState.swift       # Daten-/Logikmodell
│   ├── ParasolEntity.swift      # RealityKit-3D-Modelle
│   ├── ControlSheet.swift       # Bottom-Sheet UI
│   └── LocationProvider.swift   # CLLocationManager
├── SunMathKit/                  # Sonnenstand-Mathematik (SPM-Paket)
│   ├── Sources/SunMathKit/
│   │   └── SunMath.swift
│   └── Tests/SunMathKitTests/
│       └── SunMathTests.swift
├── Resources/                   # Info.plist, Assets
└── Schattenwerfer.xcodeproj/    # Generiertes Xcode-Projekt (gitignored)
```

---

## Voraussetzungen

- **Xcode 15+** (mindestens 16+ empfohlen für Swift 6)
- **xcodegen** (zum Generieren des `.xcodeproj` aus `project.yml`)
  ```bash
  brew install xcodegen
  ```
- **iOS 17+** Deployment Target
- **Apple-ID** für Signing (kostenloses Personal Team genügt)
- **Echtes iOS-Gerät** für AR-Tests (Simulator hat keine Kamera, kein ARKit)

---

## Projekt generieren

Das `.xcodeproj` wird aus `project.yml` generiert und ist in `.gitignore` eingetragen. **Vor dem Öffnen in Xcode immer neu generieren:**

```bash
cd /Users/cabele/claudeprojects/sonnenschirm/ios
xcodegen generate
```

Dies erzeugt `Schattenwerfer.xcodeproj` mit korrekten Build Settings für die App und SunMathKit.

---

## In Xcode öffnen und Signieren

```bash
open Schattenwerfer.xcodeproj
```

1. **Zielgerät:** Wähle links oben eine Apple-ID / Development Team:
   - Gehe zu **Schattenwerfer** (Target) → **Signing & Capabilities**
   - **Team** → Deine Apple-ID wählen (oder kostenloses Personal Team)
   - **Bundle Identifier:** `it.ravensburg.schattenwerfer` — ggf. eindeutig anpassen, falls schon vergeben

2. **Gerät auswählen:**
   - Verbinde ein iPhone via Kabel mit dem Mac
   - Oben neben dem „Play"-Button: Schema-Dropdown → Dein iPhone auswählen
   - Xcode wird automatisch Provisioning Profiles einrichten

---

## Auf dem iPhone bauen und ausführen

1. **Berechtigungen erkennen:** Beim ersten Start fragt die App nach:
   - **Kamera** (für Live-AR)
   - **Standort** (für Sonnenstand-Berechnung)
   - **Bewegungssensoren** (für Gerät-Ausrichtung)
   - Alle zulassen für volle Funktionalität

2. **App starten:**
   - In Xcode oben links: **Play-Button** drücken (oder `Cmd + R`)
   - App wird auf dem echten Gerät gebaut, installiert und gestartet

3. **ARKit braucht echtes Licht:**
   - Simulator hat **keine Kamera, kein AR** — nur auf echten Geräten testen
   - Braucht ausreichend Beleuchtung zum Erkennen der Bodenebene

---

## Bedienung

### Schirm platzieren und verschieben

1. **Boden einscannen:**
   - Halte das Gerät in einem ~30–45°-Winkel zum Boden
   - Langsam in der Gegend bewegen: ARKit scannt die Bodenebene
   - Oben erscheint ein **Coaching-Overlay** (grüner Boden + Text)
   - Sobald eine Fläche erkannt ist, erscheint ein Preview-Quadrat

2. **Tippen zum Platzieren:**
   - Tippe auf eine beliebige Stelle des erkannten Bodens
   - Der Schirm wird dort platziert (transparent grau)

3. **Ziehen zum Verschieben:**
   - Mit dem Finger auf dem Schirm **ziehen**, um ihn zu verschieben
   - Der Schatten folgt der Position

### Bottom-Sheet: Schirm-Einstellungen

Schiebe die **Griff-Leiste** unten nach oben auf, um das Control-Sheet zu öffnen:

| Feld | Bereich | Beschreibung |
|------|---------|-------------|
| **Form** | Rund / Rechteckig | Geometrie des Daches |
| **Länge** | 1,5–6,0 m | Längsachse (nur bei Rechteckig) |
| **Breite** | 1,5–6,0 m | Querachse (nur bei Rechteckig) |
| **Drehung** | 0–359° | Yaw um die Hochachse; richtet die Längsachse aus |
| **Masthöhe** | 0,5–4,0 m | Höhe vom Boden bis Dachkante |
| **Neigung** | 0–60° | Kipp-Winkel des Dachs |
| **Neigungsrichtung** | 0–359° | Wohin das Dach geneigt wird (relativ zur Drehung) |
| **Datum / Uhrzeit** | Schieber | Verschiebt die Tageszeit zur Schattensimulation |
| **Jetzt** | Button | Setzt auf Echtzeit zurück |

Die **Schattenfläche** und der **Sonnenstand** (Azimut, Höhe) werden in Echtzeit angezeigt.

---

## Tests (Sonnenlicht-Mathematik)

Die Kern-Mathematik für den Sonnenstand ist getestet. Host-Tests (auf dem Mac) ohne Simulator:

```bash
cd /Users/cabele/claudeprojects/sonnenschirm/ios/SunMathKit
swift test
```

Testet Szenarien wie:
- Sonnenstand für bekannte Datum/Uhrzeit/Koordinaten
- Schattenlänge des Masts (~Höhe ÷ tan(Sonnenhöhe))
- Bodenschatten-Geometrie bei bekannten Eingaben

---

## Umgebung & Limitierungen

### AR-Verhalten

- **Echtes Gerät erforderlich:** ARKit (Bodenerkennung, .gravityAndHeading) funktioniert nur auf echten iPhones
- **Gute Beleuchtung nötig:** Helle, strukturierte Böden (Fliesen, Straße, Grün) werden besser erkannt
- **Stabilität:** Langsame, ruhige Bewegungen helfen der Erkennung
- **Draußen optimal:** Sonnenlicht + natürliche Textur = beste AR-Erkennung

### Compile-Verifikation

In diesem Repo ist die App **syntaktisch korrekt und gegen den Simulator-SDK compiliert**, aber:
- AR-Bodenerkennung, Kamera-Streams und reale Sensoren sind am Simulator nicht verfügbar
- Echte AR-Tests nur am Gerät möglich

---

## Troubleshooting

### Projekt generiert nicht

```bash
xcodegen --version  # Check if installed
which xcodegen      # Should be /usr/local/bin/xcodegen
```

Falls nicht gefunden:
```bash
brew install xcodegen
brew link xcodegen
```

### Signing-Fehler bei Build

- **Team nicht verfügbar:** Gehe zu **Signing & Capabilities** → wähle Deine Apple-ID/Team
- **Bundle-ID Konflikt:** Ändere in `project.yml` unter `targets.Schattenwerfer.settings.base.PRODUCT_BUNDLE_IDENTIFIER` zu etwas Eindeutigem (z. B. `it.ravensburg.schattenwerfer.<deinname>`) und regeneriere

### ARKit findet keinen Boden

- Stelle sicher, **Kamera + Bewegungszugriff** ist erlaubt (Einstellungen → Schattenwerfer)
- Versuche outdoor mit natürlichem Licht
- Bewege das Gerät langsam in einem großen Bogen über den Boden (20–30 Sekunden)

### Tests schlagen fehl

Stelle sicher, im richtigen Verzeichnis zu sein:
```bash
cd ios/SunMathKit
swift test --configuration debug
```

---

## Weitere Ressourcen

- **PRD:** `PRD_Schattenwerfer.md` (im Root)
- **SunMath Spec:** `ios/SunMathKit/Sources/SunMathKit/SunMath.swift`
- **Apple ARKit Docs:** https://developer.apple.com/arkit/
- **RealityKit:** https://developer.apple.com/realitykit/

---

**Version:** 1.0  
**Stand:** Juni 2026
