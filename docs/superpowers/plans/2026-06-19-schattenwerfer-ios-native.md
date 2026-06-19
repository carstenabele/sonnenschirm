# Schattenwerfer native iOS — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Native iOS-App (SwiftUI + ARKit + RealityKit) bauen, die einen rechteckigen Sonnenschirm per Tippen auf den real erkannten Boden platziert, per Ziehen verschiebt und den geografisch korrekten Schatten wirft — mit aufgeräumtem Bottom-Sheet-UI.

**Architecture:** XcodeGen-generiertes Xcode-Projekt unter `ios/`. Reine Sonnen-/Schatten-Mathematik (Port aus `src/sun-math.mjs`) ist DOM-/RealityKit-frei und per XCTest geprüft. AR-Welt nordausgerichtet (`.gravityAndHeading`), Schirm an einem plane-Anchor, Sonnenlicht aus dem berechneten Sonnenvektor.

**Tech Stack:** Swift 6, SwiftUI, RealityKit, ARKit, CoreLocation, XcodeGen, xcodebuild, iOS 17+.

## Global Constraints

- **Projektort:** Alles unter `ios/`. Web-App im Repo-Root bleibt unverändert.
- **Projektgenerierung:** ausschließlich über `ios/project.yml` (XcodeGen). Kein handgepflegtes `.xcodeproj`. Nach jeder `project.yml`-Änderung neu generieren: `cd ios && xcodegen generate`.
- **Bundle-ID:** `it.ravensburg.schattenwerfer`. Deployment-Target iOS 17.0.
- **`SunMath` ist pur:** nur `Foundation`/`simd`, kein UIKit/SwiftUI/RealityKit. Vektoren als `SIMD3<Double>`. Winkel-Argumente in Grad, intern Radiant. Liegt im SwiftPM-Paket `ios/SunMathKit` (nur für `swift test`). **Das App-Target kompiliert dieselbe Quelle direkt mit** (project.yml `sources` enthält `SunMathKit/Sources/SunMathKit`), daher **KEIN `import SunMathKit`** im App-Code — `SunMath` ist im selben Modul direkt verfügbar.
- **Weltachsen (RealityKit, .gravityAndHeading):** +X = Osten, +Y = oben, −Z = Norden (gleiche Konvention wie `sun-math.mjs`).
- **Konstanten:** Schirmmaße L,B 1,5–6,0 m (Schritt 0,1); Yaw 0–359°; Masthöhe 1,6–3,2 m; Neigung 0–60°.
- **Sprache:** UI-Texte + Commit-Messages Deutsch.
- **Git-Disziplin:** NIE den Branch wechseln. Auf `feat/ios-native` bleiben und dort committen. Kein `git checkout`/`switch`/`reset` anderer Branches.
- **Umgebungs-Constraint (wichtig):** Dieses System hat den iOS-26.5-Simulator-SDK, aber KEINE lauffähige iOS-26.5-Runtime. Für den Simulator lässt sich daher **kompilieren**, aber **nichts ausführen** (kein `xcodebuild test`, kein App-Start/Screenshot im Simulator).
- **Build-Verifikation (nur Compile):**
  `xcodebuild -project ios/Schattenwerfer.xcodeproj -target Schattenwerfer -sdk iphonesimulator26.5 -configuration Debug build`
  → muss `** BUILD SUCCEEDED **` ausgeben.
- **Mathematik-Test-Verifikation:** reine Mathematik im SwiftPM-Paket, host-nativ getestet:
  `cd ios/SunMathKit && swift test` → alle Tests grün (kein Simulator nötig).
- **Ehrlichkeit:** ARKit (Kamera/Bodenerkennung/echte Schatten) und jeder Simulator-Laufzeittest sind hier NICHT möglich. App-/AR-/UI-Tasks werden nur auf „kompiliert sauber" geprüft; Laufzeit-/AR-Verhalten verifiziert der Nutzer am Gerät.

---

## File Structure

| Datei | Verantwortung | Task |
|---|---|---|
| `ios/project.yml` | XcodeGen: App- + Test-Target, Plist, Capabilities | 1 |
| `ios/Resources/Info.plist` | Kamera-/Standort-Texte, ARKit required | 1 |
| `ios/Sources/SchattenwerferApp.swift` | `@main` App-Entry | 1 |
| `ios/Sources/ContentView.swift` | AR-Ansicht + Readouts + Sheet-Host | 1 (Stub), 6 |
| `ios/SunMathKit/Package.swift` | SwiftPM-Paket für die reine Mathematik | 2 |
| `ios/SunMathKit/Sources/SunMathKit/SunMath.swift` | Pure Sonnen-/Schatten-Mathematik | 2 |
| `ios/SunMathKit/Tests/SunMathKitTests/SunMathTests.swift` | XCTest der PRD-Fälle (host-nativ) | 2 |
| `ios/Sources/ParasolState.swift` | `ObservableObject` Einstellungen | 3 |
| `ios/Sources/LocationProvider.swift` | CoreLocation-Wrapper | 3 |
| `ios/Sources/ParasolEntity.swift` | RealityKit-Schirmmodell (Mast + Dach) | 4 |
| `ios/Sources/ARSceneView.swift` | `ARView`, Platzierung, Sonnenlicht, Schatten | 5 |
| `ios/Sources/ControlSheet.swift` | Regler im Bottom-Sheet | 6 |

---

## Task 1: XcodeGen-Gerüst — App kompiliert & startet im Simulator

**Files:** Create `ios/project.yml`, `ios/Resources/Info.plist`, `ios/Sources/SchattenwerferApp.swift`, `ios/Sources/ContentView.swift`

**Interfaces:**
- Produces: lauffähiges Xcode-Projekt `ios/Schattenwerfer.xcodeproj` mit Scheme `Schattenwerfer`; minimaler SwiftUI-Screen.

- [ ] **Step 1: `ios/project.yml` anlegen**

```yaml
name: Schattenwerfer
options:
  bundleIdPrefix: it.ravensburg
  deploymentTarget:
    iOS: "17.0"
settings:
  base:
    MARKETING_VERSION: "1.0"
    CURRENT_PROJECT_VERSION: "1"
    GENERATE_INFOPLIST_FILE: NO
    SWIFT_VERSION: "6.0"
    DEVELOPMENT_TEAM: ""
    CODE_SIGN_STYLE: Automatic
targets:
  Schattenwerfer:
    type: application
    platform: iOS
    sources:
      - Sources
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: it.ravensburg.schattenwerfer
        INFOPLIST_FILE: Resources/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
  SchattenwerferTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests
    dependencies:
      - target: Schattenwerfer
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: it.ravensburg.schattenwerfer.tests
schemes:
  Schattenwerfer:
    build:
      targets:
        Schattenwerfer: all
        SchattenwerferTests: [test]
    test:
      targets:
        - SchattenwerferTests
```

- [ ] **Step 2: `ios/Resources/Info.plist` anlegen**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>UILaunchScreen</key>
  <dict/>
  <key>NSCameraUsageDescription</key>
  <string>Für das Live-Kamerabild, über das der Schatten gelegt wird.</string>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Zur Berechnung des Sonnenstands an deinem Standort.</string>
  <key>UIRequiredDeviceCapabilities</key>
  <array>
    <string>arkit</string>
  </array>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 3: `ios/Sources/SchattenwerferApp.swift` anlegen**

```swift
import SwiftUI

@main
struct SchattenwerferApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 4: `ios/Sources/ContentView.swift` als Stub anlegen**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Schattenwerfer")
                .foregroundStyle(.white)
                .font(.title2)
        }
    }
}
```

- [ ] **Step 5: Projekt generieren**

Run: `cd ios && xcodegen generate`
Expected: „Created project at .../ios/Schattenwerfer.xcodeproj".

- [ ] **Step 6: Build im Simulator**

Run: `xcodebuild -project ios/Schattenwerfer.xcodeproj -scheme Schattenwerfer -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: `.gitignore` für Xcode-Output ergänzen + Commit**

Ergänze in `.gitignore` (Repo-Root):
```
ios/Schattenwerfer.xcodeproj/
ios/build/
ios/DerivedData/
```
(Das `.xcodeproj` ist generierbar; nur `project.yml` + Quellen werden versioniert.)

```bash
git add ios/project.yml ios/Resources ios/Sources .gitignore
git commit -m "feat(ios): XcodeGen-Gerüst, App baut im Simulator"
```

---

## Task 2: `SunMathKit` SwiftPM-Paket + Tests (Port der Mathematik, TDD) + ins App-Target einbinden

**Files:** Create `ios/SunMathKit/Package.swift`, `ios/SunMathKit/Sources/SunMathKit/SunMath.swift`, `ios/SunMathKit/Tests/SunMathKitTests/SunMathTests.swift`; Modify `ios/project.yml` (lokale Package-Abhängigkeit), Delete unbenutztes `ios/Tests/` + Test-Target aus `project.yml`.

**Wichtig:** `SunMath` lebt in einem SwiftPM-Paket, damit es host-nativ mit `swift test` (ohne Simulator-Runtime) geprüft werden kann. Das App-Target hängt per XcodeGen-`packages` davon ab und nutzt `import SunMathKit`. Alle Typen/Funktionen sind `public`.

**Interfaces:**
- Produces (alle pur + `public`, `public enum SunMath`):
  - `SunMath.position(date: Date, lat: Double, lng: Double) -> (azimuth: Double, altitude: Double)` (Radiant)
  - `SunMath.vector(azimuth: Double, altitude: Double) -> SIMD3<Double>`
  - `SunMath.rectCornersWorld(L:B:yawDeg:tiltDeg:tiltDirDeg:height:eye:front:) -> [SIMD3<Double>]`
  - `SunMath.projectToGround(_ p: SIMD3<Double>, sun: SIMD3<Double>, yGround: Double) -> SIMD2<Double>` (x,z)
  - `SunMath.polygonArea(_ pts: [SIMD2<Double>]) -> Double`
  - `SunMath.mastShadowLength(height: Double, altitude: Double) -> Double`
  - `SunMath.shadowMetrics(L:B:yawDeg:tiltDeg:tiltDirDeg:height:eye:front:azimuth:altitude:) -> (areaM2: Double, lengthM: Double, isNight: Bool)`

- [ ] **Step 0: `ios/SunMathKit/Package.swift` anlegen**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SunMathKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [.library(name: "SunMathKit", targets: ["SunMathKit"])],
    targets: [
        .target(name: "SunMathKit"),
        .testTarget(name: "SunMathKitTests", dependencies: ["SunMathKit"]),
    ]
)
```

- [ ] **Step 1: Failing tests schreiben** (`ios/SunMathKit/Tests/SunMathKitTests/SunMathTests.swift`)

Referenzen identisch zur Web-Version (`tests/shadow.test.mjs`).

```swift
import XCTest
import simd
@testable import SunMathKit

final class SunMathTests: XCTestCase {
    let lat = 50.11, lng = 8.68 // Frankfurt
    let rad = 180.0 / Double.pi

    private func maxAltitudeOfDay(_ y: Int, _ m: Int, _ d: Int) -> (azimuth: Double, altitude: Double) {
        var best = (azimuth: 0.0, altitude: -Double.infinity)
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        for minute in stride(from: 0, to: 1440, by: 1) {
            comps.hour = minute / 60; comps.minute = minute % 60
            let date = cal.date(from: comps)!
            let p = SunMath.position(date: date, lat: lat, lng: lng)
            if p.altitude > best.altitude { best = p }
        }
        return best
    }

    func testSummerSolsticeNoonAltitude() {
        let peak = maxAltitudeOfDay(2026, 6, 21)
        XCTAssertEqual(peak.altitude * rad, 63.33, accuracy: 1.0)
        XCTAssertEqual(peak.azimuth * rad, 180.0, accuracy: 1.0)
    }

    func testWinterMuchLowerThanSummer() {
        let s = maxAltitudeOfDay(2026, 6, 21).altitude * rad
        let w = maxAltitudeOfDay(2026, 12, 21).altitude * rad
        XCTAssertGreaterThan(s - w, 40.0)
    }

    func testSunVectorZenith() {
        let v = SunMath.vector(azimuth: 0, altitude: .pi / 2)
        XCTAssertEqual(v.x, 0, accuracy: 1e-9)
        XCTAssertEqual(v.z, 0, accuracy: 1e-9)
        XCTAssertEqual(v.y, 1, accuracy: 1e-9)
    }

    func testPolygonAreaUnitSquare() {
        let sq: [SIMD2<Double>] = [[0,0],[1,0],[1,1],[0,1]]
        XCTAssertEqual(SunMath.polygonArea(sq), 1, accuracy: 1e-9)
    }

    func testAnchorCaseArea8() {
        let m = SunMath.shadowMetrics(L: 4, B: 2, yawDeg: 90, tiltDeg: 0, tiltDirDeg: 0,
                                      height: 2.4, eye: 1.5, front: 4.0,
                                      azimuth: 0, altitude: .pi / 2)
        XCTAssertFalse(m.isNight)
        XCTAssertEqual(m.areaM2, 8, accuracy: 8 * 0.05)
    }

    func testMastShadowLength() {
        let alt = 30.0 / rad
        let len = SunMath.mastShadowLength(height: 2.4, altitude: alt)
        let ref = 2.4 / tan(alt)
        XCTAssertEqual(len, ref, accuracy: ref * 0.05)
    }

    func testNight() {
        let m = SunMath.shadowMetrics(L: 4, B: 2, yawDeg: 0, tiltDeg: 0, tiltDirDeg: 0,
                                      height: 2.4, eye: 1.5, front: 4.0,
                                      azimuth: 0, altitude: -0.2)
        XCTAssertTrue(m.isNight)
    }
}
```

- [ ] **Step 2: Tests ausführen → Fehlschlag (SunMath fehlt)**

Run: `cd ios/SunMathKit && swift test`
Expected: Compile/Test schlägt fehl — `SunMath` unbekannt.

- [ ] **Step 3: `ios/SunMathKit/Sources/SunMathKit/SunMath.swift` implementieren**

Port von `src/sun-math.mjs` (gleiche Formeln/Konventionen). **Alle Deklarationen `public`** (Enum + jede Funktion), sonst sieht der Test-/App-Code sie nicht:

```swift
import Foundation
import simd

public enum SunMath {
    public static let deg = Double.pi / 180

    static func position(date: Date, lat: Double, lng: Double) -> (azimuth: Double, altitude: Double) {
        let dayMs = 86_400_000.0, j1970 = 2_440_588.0, j2000 = 2_451_545.0
        let e = 23.4397 * deg
        let d = date.timeIntervalSince1970 * 1000.0 / dayMs - 0.5 + j1970 - j2000
        let m = (357.5291 + 0.98560028 * d) * deg
        let c = (1.9148 * sin(m) + 0.02 * sin(2 * m) + 0.0003 * sin(3 * m)) * deg
        let p = 102.9372 * deg
        let l = m + c + p + .pi
        let dec = asin(sin(e) * sin(l))
        let ra = atan2(cos(e) * sin(l), cos(l))
        let lw = -lng * deg
        let phi = lat * deg
        let theta = (280.16 + 360.9856235 * d) * deg - lw
        let h = theta - ra
        let azS = atan2(sin(h), cos(h) * sin(phi) - tan(dec) * cos(phi))
        var azN = azS + .pi
        azN = (azN.truncatingRemainder(dividingBy: 2 * .pi) + 2 * .pi).truncatingRemainder(dividingBy: 2 * .pi)
        let alt = asin(sin(phi) * sin(dec) + cos(phi) * cos(dec) * cos(h))
        return (azN, alt)
    }

    static func vector(azimuth: Double, altitude: Double) -> SIMD3<Double> {
        let ch = cos(altitude)
        return SIMD3(sin(azimuth) * ch, sin(altitude), -cos(azimuth) * ch)
    }

    private static func rotY(_ p: SIMD3<Double>, _ a: Double) -> SIMD3<Double> {
        let c = cos(a), s = sin(a)
        return SIMD3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c)
    }
    private static func rotX(_ p: SIMD3<Double>, _ a: Double) -> SIMD3<Double> {
        let c = cos(a), s = sin(a)
        return SIMD3(p.x, p.y * c - p.z * s, p.y * s + p.z * c)
    }

    static func rectCornersWorld(L: Double, B: Double, yawDeg: Double, tiltDeg: Double,
                                 tiltDirDeg: Double, height: Double, eye: Double, front: Double) -> [SIMD3<Double>] {
        let yaw = yawDeg * deg, dir = tiltDirDeg * deg, tip = tiltDeg * deg
        let hx = L / 2, hz = B / 2
        let local = [SIMD3(hx,0,hz), SIMD3(hx,0,-hz), SIMD3(-hx,0,-hz), SIMD3(-hx,0,hz)]
        let topY = -eye + height
        return local.map { p in
            var q = rotY(p, yaw); q = rotY(q, dir); q = rotX(q, tip)
            return SIMD3(q.x, q.y + topY, q.z - front)
        }
    }

    static func projectToGround(_ p: SIMD3<Double>, sun: SIMD3<Double>, yGround: Double) -> SIMD2<Double> {
        let t = (p.y - yGround) / sun.y
        return SIMD2(p.x - sun.x * t, p.z - sun.z * t)
    }

    static func polygonArea(_ pts: [SIMD2<Double>]) -> Double {
        var a = 0.0
        for i in 0..<pts.count {
            let p = pts[i], q = pts[(i + 1) % pts.count]
            a += p.x * q.y - q.x * p.y   // SIMD2: .x=x, .y=z
        }
        return abs(a) / 2
    }

    static func mastShadowLength(height: Double, altitude: Double) -> Double {
        altitude <= 0 ? .infinity : height / tan(altitude)
    }

    static func shadowMetrics(L: Double, B: Double, yawDeg: Double, tiltDeg: Double, tiltDirDeg: Double,
                              height: Double, eye: Double, front: Double,
                              azimuth: Double, altitude: Double) -> (areaM2: Double, lengthM: Double, isNight: Bool) {
        if altitude <= 0 { return (0, .infinity, true) }
        let sv = vector(azimuth: azimuth, altitude: altitude)
        let corners = rectCornersWorld(L: L, B: B, yawDeg: yawDeg, tiltDeg: tiltDeg,
                                       tiltDirDeg: tiltDirDeg, height: height, eye: eye, front: front)
        let ground = corners.map { projectToGround($0, sun: sv, yGround: -eye) }
        return (polygonArea(ground), mastShadowLength(height: height, altitude: altitude), false)
    }
}
```

- [ ] **Step 4: Tests ausführen → grün**

Run: `cd ios/SunMathKit && swift test`
Expected: alle 7 Tests grün („Test Suite 'All tests' passed"), Ausgabe ohne Warnungen.

- [ ] **Step 5: Paket ins App-Target einbinden + altes Test-Target entfernen**

In `ios/project.yml`: oberhalb von `targets:` einen `packages:`-Block ergänzen und die App-Abhängigkeit setzen; das ungenutzte `SchattenwerferTests`-Target und seinen Scheme-Eintrag entfernen, da iOS-Tests hier nicht lauffähig sind:

```yaml
packages:
  SunMathKit:
    path: SunMathKit
targets:
  Schattenwerfer:
    type: application
    platform: iOS
    sources:
      - Sources
    dependencies:
      - package: SunMathKit
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: it.ravensburg.schattenwerfer
        INFOPLIST_FILE: Resources/Info.plist
        TARGETED_DEVICE_FAMILY: "1"
schemes:
  Schattenwerfer:
    build:
      targets:
        Schattenwerfer: all
```
Außerdem `ios/Tests/` (leeres altes XCTest-Verzeichnis) löschen.

- [ ] **Step 6: Projekt neu generieren + App baut mit Paket**

Run: `cd ios && xcodegen generate` danach (aus Repo-Root)
`xcodebuild -project ios/Schattenwerfer.xcodeproj -target Schattenwerfer -sdk iphonesimulator26.5 -configuration Debug build`
Expected: `** BUILD SUCCEEDED **` (App linkt `SunMathKit`).

- [ ] **Step 7: Commit**

```bash
git add ios/SunMathKit ios/project.yml
git rm -r --cached ios/Tests 2>/dev/null; rm -rf ios/Tests
git add -A ios/Tests 2>/dev/null
git commit -m "feat(ios): Sonnen-/Schatten-Mathematik als SwiftPM-Paket + getestet"
```

---

## Task 3: `ParasolState` + `LocationProvider`

**Files:** Create `ios/Sources/ParasolState.swift`, `ios/Sources/LocationProvider.swift`

**Interfaces:**
- Produces:
  - `final class ParasolState: ObservableObject` mit `@Published`: `shape: Shape` (`enum Shape { case round, rect }`), `length`, `width`, `area`, `yawDeg`, `tiltDeg`, `tiltDirDeg`, `height` (Double), `date: Date`, `useNow: Bool`, `lat`, `lng: Double`. Methode `sun() -> (azimuth: Double, altitude: Double)` und `metrics() -> (areaM2, lengthM, isNight)` via `SunMath`.
  - `final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate` mit `@Published var coordinate: (lat: Double, lng: Double)` (Default Frankfurt) und `start()`.

- [ ] **Step 1: `ParasolState.swift` implementieren**

Anforderungen: `import SunMathKit`. Defaults `shape=.rect, length=4, width=2, area=7.1, yawDeg=0, tiltDeg=0, tiltDirDeg=0, height=2.4, useNow=true, lat=50.11, lng=8.68`. `effectiveDate`: bei `useNow==true` → `Date()`, sonst `date`. `sun()` ruft `SunMath.position(date: effectiveDate, lat:, lng:)`. `metrics()` ruft `SunMath.shadowMetrics(...)` mit `eye: 0` und `front: 0` (Position ist im AR egal — Fläche ist translationsinvariant; `eye`/`front` nur als Bezug, hier 0/0 ausreichend, Boden y=0). Wertebereiche siehe Global Constraints.

- [ ] **Step 2: `LocationProvider.swift` implementieren**

Anforderungen: `CLLocationManager`, `requestWhenInUseAuthorization()`, `desiredAccuracy = kCLLocationAccuracyHundredMeters`, bei Update `coordinate` setzen. Fallback Frankfurt bleibt bis zum ersten Fix.

- [ ] **Step 3: Build**

Run: `xcodebuild ... build` (siehe Global Constraints).
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add ios/Sources/ParasolState.swift ios/Sources/LocationProvider.swift
git commit -m "feat(ios): Zustands-Modell + Standort-Provider"
```

---

## Task 4: `ParasolEntity` (RealityKit-Schirmmodell)

**Files:** Create `ios/Sources/ParasolEntity.swift`

**Interfaces:**
- Consumes: `ParasolState`.
- Produces: `final class ParasolEntity: Entity` mit `func update(from state: ParasolState)`, das Mast + Dach (rund/rechteckig) aufbaut/aktualisiert und die Transformreihenfolge Yaw→Neigungsrichtung→Neigung am Mastkopf-Pivot anwendet.

- [ ] **Step 1: `ParasolEntity.swift` implementieren**

Anforderungen:
- Mast: `MeshResource.generateCylinder(height: Float(state.height), radius: 0.03)`, mittig auf halber Höhe, Basis bei y=0 (Entity-Ursprung = Bodenpunkt).
- Pivot-`Entity` am Mastkopf (y = height).
- Dach rechteckig: `MeshResource.generateBox(size: SIMD3(Float(state.length), 0.08, Float(state.width)))`. Dach rund: flacher Zylinder, Radius = `sqrt(area/π)`, Höhe 0,1.
- Material: `SimpleMaterial(color: .init(red:0.84,green:0.29,blue:0.25,alpha:1), isMetallic: false)`; Mast grau.
- `GroundingShadowComponent(castsShadow: true)` an Dach + Mast (für Geräte-Schatten; finale Technik in Task 5).
- Pivot-Orientierung: `simd_quatf` aus Yaw (um +Y), dann Neigungsrichtung (um +Y), dann Neigung (um +X) — Reihenfolge multiplizieren wie in der Web-Logik.
- `update(from:)` ist idempotent (vorhandene Kinder neu konfigurieren oder neu aufbauen).

- [ ] **Step 2: Build**

Run: `xcodebuild ... build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/ParasolEntity.swift
git commit -m "feat(ios): RealityKit-Schirmmodell (Mast + Dach, Transformreihenfolge)"
```

---

## Task 5: `ARSceneView` (ARView, Platzieren/Verschieben, Sonnenlicht, Schatten)

**Files:** Create `ios/Sources/ARSceneView.swift`

**Interfaces:**
- Consumes: `ParasolState`, `ParasolEntity`, `SunMath`.
- Produces: `struct ARSceneView: UIViewRepresentable` (SwiftUI), das eine `ARView` aufbaut und mit `ParasolState` synchronisiert.

- [ ] **Step 1: `ARSceneView.swift` implementieren**

Anforderungen:
- `makeUIView`: `ARView(frame: .zero)`, `ARWorldTrackingConfiguration` mit `planeDetection = [.horizontal]`, `worldAlignment = .gravityAndHeading`, `environmentTexturing = .automatic`; `session.run(config)`. `ARCoachingOverlayView` (goal `.horizontalPlane`) hinzufügen.
- Ein `AnchorEntity` für den Schirm (zunächst nicht platziert). `ParasolEntity` als Kind. Default-Platzierung erst nach Bodenerkennung/Tap.
- **Tap-Geste:** `arView.raycast(from: point, allowing: .estimatedPlane, alignment: .horizontal)` → erster Treffer setzt die `AnchorEntity`-Welttransform (oder erzeugt `ARAnchor`). Wenn noch kein Anker platziert: platzieren; sonst: an neuen Punkt verschieben.
- **Pan-Geste:** fortlaufendes Raycasten und Anker-Position aktualisieren (verschieben).
- **Sonnenlicht:** `DirectionalLight`-Entity; Ausrichtung aus `SunMath.vector(...)`: Licht „schaut" entlang `-sunVector` (von der Sonne weg). `light.light.intensity = altitude > 0 ? <hell> : 0`. Schattenkomponente aktivieren (`light.shadow = .init()`), sofern verfügbar.
- **Schatten auf realem Boden:** beim Platzieren eine große Plane (`MeshResource.generatePlane(width: 8, depth: 8)`) mit `OcclusionMaterial()` als Kind des Ankers auf y=0 — empfängt den Schatten und zeigt das Kamerabild. (Falls OcclusionMaterial keinen gerichteten Schatten zeigt: `GroundingShadowComponent` an den Schirmteilen ist der Fallback aus Task 4.)
- `updateUIView`: bei Änderung von `ParasolState` `parasolEntity.update(from:)` aufrufen und Sonnenlicht/Intensität neu setzen. (Coordinator hält Referenzen.)
- Robustheit: Wenn ARKit nicht verfügbar (`ARWorldTrackingConfiguration.isSupported == false`, z. B. Simulator), nicht abstürzen — leere View + Log.

- [ ] **Step 2: Build**

Run: `xcodebuild ... build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add ios/Sources/ARSceneView.swift
git commit -m "feat(ios): AR-Szene mit Platzieren/Verschieben + Sonnenlicht"
```

---

## Task 6: UI — `ContentView` (vollflächig) + `ControlSheet` (Bottom-Sheet)

**Files:** Modify `ios/Sources/ContentView.swift`; Create `ios/Sources/ControlSheet.swift`

**Interfaces:**
- Consumes: `ARSceneView`, `ParasolState`, `LocationProvider`.
- Produces: vollständige App-Oberfläche.

- [ ] **Step 1: `ContentView.swift` ausbauen**

Anforderungen:
- `@StateObject var state = ParasolState()`, `@StateObject var loc = LocationProvider()`.
- `ZStack`: `ARSceneView(state: state).ignoresSafeArea()` als Basis.
- Oben: dezenter Readout-Streifen (Zeit, Azimut, Höhe, Schattenfläche) aus `state.sun()`/`state.metrics()`.
- `.sheet(isPresented: .constant(true))` mit `ControlSheet(state: state)`, `presentationDetents([.height(120), .medium, .large])`, `presentationBackgroundInteraction(.enabled(upThrough: .medium))`, `interactiveDismissDisabled(true)`.
- `loc.start()` in `.onAppear`; `loc.coordinate` → `state.lat/lng` via `.onChange`.

- [ ] **Step 2: `ControlSheet.swift` implementieren**

Anforderungen:
- `@ObservedObject var state: ParasolState`.
- Form-Picker (Rund/Rechteck, segmentiert).
- Bei Rechteck: Slider Länge (1,5–6), Breite (1,5–6), Drehung (0–359). Bei Rund: Slider Schirmfläche.
- Immer: Masthöhe (1,6–3,2), Neigungswinkel (0–60), Neigungsrichtung (0–359).
- DatePicker (Datum + Uhrzeit) + Button „Jetzt" (`state.useNow = true`); jede Slider-Änderung aktualisiert `@Published` → Live-Update der Szene.
- Klartext-Labels mit Live-Wertanzeige.

- [ ] **Step 3: Build (nur Compile — Simulator-Laufzeit hier nicht möglich)**

Run: `xcodebuild -project ios/Schattenwerfer.xcodeproj -target Schattenwerfer -sdk iphonesimulator26.5 -configuration Debug build`
Expected: `** BUILD SUCCEEDED **`. (App-Start/Screenshot im Simulator ist hier nicht möglich — keine iOS-26.5-Runtime; UI prüft der Nutzer am Gerät.)

- [ ] **Step 4: Commit**

```bash
git add ios/Sources/ContentView.swift ios/Sources/ControlSheet.swift
git commit -m "feat(ios): vollflächige AR-Ansicht + Bottom-Sheet-Bedienung"
```

---

## Task 7: Abschluss — Gesamtbuild, Tests, Geräte-Anleitung

**Files:** Create `ios/README.md`

**Interfaces:** Consumes alle vorigen Tasks.

- [ ] **Step 1: Mathematik-Tests + App-Build grün**

Run: `cd ios/SunMathKit && swift test` → alle Tests grün.
Run: `xcodebuild -project ios/Schattenwerfer.xcodeproj -target Schattenwerfer -sdk iphonesimulator26.5 -configuration Debug build` → `** BUILD SUCCEEDED **`.

- [ ] **Step 2: `ios/README.md` mit Geräte-Anleitung schreiben**

Inhalt: Projekt generieren (`cd ios && xcodegen generate`), in Xcode öffnen, unter „Signing & Capabilities" das eigene Team (Apple-ID) wählen, iPhone anschließen, ausführen. Hinweis: ARKit nur am Gerät; Bodenfläche einscannen, dann tippen zum Platzieren, ziehen zum Verschieben.

- [ ] **Step 3: Commit**

```bash
git add ios/README.md
git commit -m "docs(ios): Geräte-Build- und Nutzungsanleitung"
```

---

## Self-Review

**Spec-Abdeckung:**
- ARKit + RealityKit, .gravityAndHeading: Task 5 ✓ · Bodenerkennung/Tap/Pan-Platzierung: Task 5 ✓
- Rechteck/rund + Maße + Transformreihenfolge: Task 4 ✓ · Sonnenstand/Schatten-Mathematik: Task 2 ✓
- Sonnenlicht aus Sonnenvektor + Schatten: Task 5 ✓ · Standort/Zeit: Task 3 + Task 6 ✓
- Aufgeräumtes UI / Bottom-Sheet: Task 6 ✓ · XcodeGen-Projekt: Task 1 ✓
- Tests (PRD-Fälle): Task 2 ✓ · Geräte-/Signing-Anleitung: Task 7 ✓

**Platzhalter:** Deterministische Teile (project.yml, Info.plist, SunMath + Tests) sind vollständiger Code. RealityKit/SwiftUI-Tasks geben exakte Interfaces + API-Aufrufe + Akzeptanzkriterien vor; idiomatische Swift-Umsetzung durch den jeweiligen Subagenten, Review nach jeder Task.

**Typkonsistenz:** `ParasolState`-Felder (shape, length, width, area, yawDeg, tiltDeg, tiltDirDeg, height, date, useNow, lat, lng) konsistent in Task 3/4/5/6. `SunMath`-Signaturen konsistent zwischen Task-2-Definition, Tests und `ParasolState.metrics()`/`ARSceneView`.
```
