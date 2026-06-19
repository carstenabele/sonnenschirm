# Design — Schattenwerfer native iOS (ARKit + RealityKit)

**Stand:** 2026-06-19 · **Status:** Freigegeben (Brainstorming)
**Bezug:** `PRD_Schattenwerfer.md` (Meilenstein M4 „Natives AR"), bestehende Web-App (`index.html`, `src/sun-math.mjs`)

---

## 1. Ziel & Motivation

Die Web-App leidet an überladenem HUD; Platzierung des Schirms ist auf dem Telefon
unpraktisch, und Magic-Window ohne Tracking macht den Schatten oft unsichtbar.
Eine **native iOS-App mit echtem ARKit** löst beides:

- **Echte Bodenerkennung** → Tippen platziert den Schirm stabil auf dem realen Boden, Ziehen verschiebt ihn.
- **`worldAlignment = .gravityAndHeading`** richtet die AR-Welt automatisch nach echtem Norden aus → geografisch korrekter Sonnenstand **ohne** manuelle Nord-Kalibrierung.
- **Aufgeräumtes UI**: Kamerabild vollflächig, Regler in einem ausklappbaren Bottom-Sheet.

Die Web-App bleibt unverändert im Repo; die native App entsteht parallel unter `ios/`.

---

## 2. Stack & Umgebung

- **SwiftUI + RealityKit + ARKit**, iOS 17+ Deployment, Swift 6.
- **XcodeGen 2.45.4** erzeugt `.xcodeproj` aus `ios/project.yml` (kein handgepflegtes pbxproj).
- Build/Test/Sim hier verfügbar (Xcode 26.5, iPhone-16-Simulatoren). Signing aktuell leer.

### Verifizierbarkeit (ehrlich)

- **Hier (Simulator/Headless):** `xcodebuild build` (kompiliert), `xcodebuild test`
  (reine Mathematik), Simulator-Start (UI/Sheet ohne Crash).
- **Nur am Gerät (Nutzer):** Kamera-Passthrough, Horizontalebenen-Erkennung,
  AR-Stabilität, echte Schattenprojektion. ARKit läuft **nicht** im Simulator.
- **Signing:** Nutzer richtet einmalig automatische Signierung mit Apple-ID +
  persönlichem Team in Xcode ein. Bundle-ID `it.ravensburg.schattenwerfer`.

---

## 3. Dateistruktur (`ios/`)

| Datei | Verantwortung |
|---|---|
| `project.yml` | XcodeGen-Definition (App-Target, Test-Target, Plist, Capabilities) |
| `Resources/Info.plist` | NSCameraUsageDescription, NSLocationWhenInUseUsageDescription, ARKit required |
| `Sources/SunMath.swift` | Pure Mathematik: Sonnenstand, Sonnenvektor, Schattenprojektion/-fläche (Port von `sun-math.mjs`) |
| `Sources/ParasolState.swift` | `ObservableObject` mit allen Einstellungen (shape, L, B, yaw, tilt, tiltDir, height, Datum/Zeit, lat/lng) |
| `Sources/LocationProvider.swift` | CoreLocation-Wrapper (lat/lng, Fallback Frankfurt) |
| `Sources/ARSceneView.swift` | `UIViewRepresentable` für `ARView`: Konfiguration, Coaching, Tap/Pan-Platzierung, Schirm-Entity, Sonnenlicht, Schatten |
| `Sources/ParasolEntity.swift` | Aufbau/Update des Schirm-Modells (Mast + Dach, Transformreihenfolge, Maße) |
| `Sources/ContentView.swift` | Vollflächige AR-Ansicht + Readout-Overlay + Bottom-Sheet-Host |
| `Sources/ControlSheet.swift` | Regler im ausklappbaren Sheet |
| `Sources/SchattenwerferApp.swift` | App-Entry (`@main`) |
| `Tests/SunMathTests.swift` | XCTest der PRD-Genauigkeitsfälle |

---

## 4. Mathematik (`SunMath.swift`)

1:1-Port der bewährten Funktionen aus `src/sun-math.mjs`, als pure Swift-Funktionen
(kein UIKit/RealityKit), damit unter XCTest prüfbar:

- `sunPosition(date:lat:lng:) -> (azimuth: Double, altitude: Double)` (Radiant, Azimut von Norden im UZS)
- `sunVector(azimuth:altitude:) -> SIMD3<Double>` (+X Ost, +Y oben, −Z Nord)
- `rectCornersWorld(...)`, `projectToGround(...)`, `polygonArea(...)`, `mastShadowLength(...)`, `shadowMetrics(...)` analog zur JS-Version.

**Testfälle (identisch zur Web-Version):** Sommersonnenwende Mittagshöhe ≈ 63,33°
(±1°, Azimut ≈ 180°); Wintersonnenwende deutlich niedriger; Ankerfall L=4,B=2,Zenit →
Fläche 8 m² (±5 %); Mastschatten ≈ Höhe/tan(Höhe) (<5 %); Nacht → kein Schatten.

---

## 5. AR-Szene (`ARSceneView.swift`, `ParasolEntity.swift`)

- `ARView` mit `ARWorldTrackingConfiguration`: `planeDetection = [.horizontal]`,
  `worldAlignment = .gravityAndHeading`, `environmentTexturing = .automatic`.
- `ARCoachingOverlayView` (Ziel `.horizontalPlane`) führt zur Bodenerkennung.
- **Platzieren:** Tap → `arView.raycast(query: .existingPlaneGeometry/.estimatedPlane)` →
  Treffer setzt/bewegt einen `AnchorEntity`. Der Schirm ist Kind dieses Ankers (weltstabil).
- **Verschieben:** Pan-Geste raycastet fortlaufend und versetzt den Anker.
- **Schirm-Entity:**
  - Mast: `MeshResource.generateCylinder(height:radius:)`.
  - Dach Rechteck: `MeshResource.generateBox(size:[L, 0.08, B])`; Dach rund:
    flacher Zylinder (Radius aus Fläche). Form-Umschalter wie Web.
  - Transformreihenfolge am Mastkopf: **Yaw → Neigungsrichtung → Neigungswinkel**
    (Quaternionen, identisch zur Web-Logik).
- **Sonnenlicht:** `DirectionalLight` (RealityKit), Ausrichtung aus `sunVector`
  (Welt ist nordausgerichtet, daher direkt anwendbar). Intensität 0 bei Sonne ≤ 0°.
- **Schatten auf realem Boden:** große Plane mit `OcclusionMaterial` am Anker-/Bodenniveau
  empfängt die gerichtete Schattenprojektion; Schirm-Entities werfen Schatten
  (`DirectionalLightComponent.Shadow` bzw. `GroundingShadowComponent` als Fallback).
  Die exakte Schatten-Technik wird im Plan festgelegt und am Gerät verifiziert.

---

## 6. Standort & Zeit

- `LocationProvider` (CoreLocation, „When In Use") liefert lat/lng; Fallback Frankfurt (50.11, 8.68).
- Datum + Uhrzeit über Picker im Sheet; „Jetzt" setzt beides auf aktuell.
- Sonnenstand wird bei Änderung von Zeit/Datum/Ort/Standort neu berechnet und auf Licht + Readouts angewandt.

---

## 7. UI (`ContentView.swift`, `ControlSheet.swift`)

- Kamerabild vollflächig (AR-Ansicht). Oben dezenter Readout-Streifen: Zeit, Azimut, Höhe, Schattenfläche.
- **Bottom-Sheet** (`.presentationDetents([.height(120), .medium, .large])`,
  `.presentationBackgroundInteraction(.enabled)`) — Kamerabild bleibt antippbar/platzierbar, während das Sheet klein ist.
- Im Sheet: Form-Umschalter; Slider Länge, Breite, Drehung, Masthöhe, Neigungswinkel,
  Neigungsrichtung; Datum + Uhrzeit; „Jetzt". Klartext-Labels (Deutsch).
- Hinweis-Banner bis ein Boden erkannt/Schirm platziert ist.

---

## 8. Out of Scope (v1 nativ)

- Mehrere Schirme, Materialwahl, Zeitraffer-Animation.
- iPad-spezifisches Layout, Lokalisierung außer Deutsch.
- App-Store-Distribution/TestFlight (nur lokaler Geräte-Build).

---

## 9. Risiken

- **AR nicht hier testbar** → Mathematik + Build + Sim verifizieren; AR-Verhalten am Gerät (Nutzer).
- **Schatten-Technik in RealityKit:** OcclusionMaterial-Schattenempfang kann je nach
  iOS-Version variieren → am Gerät prüfen, ggf. GroundingShadow als Fallback.
- **Signing:** ohne Apple-ID kein Gerätebuild → Nutzer richtet automatisches Signing ein.
- **Heading-Genauigkeit:** `.gravityAndHeading` hängt vom Magnetkompass ab; Restfehler möglich (am Gerät bewerten).
