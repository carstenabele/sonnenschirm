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

    func testShadowOutlineRectAnchorCase() {
        // Same anchor case as area test: zenith → outline is the 4×2 footprint, area ~8.
        let outline = SunMath.shadowGroundOutline(
            shape: .rect, L: 4, B: 2, area: 0,
            yawDeg: 90, tiltDeg: 0, tiltDirDeg: 0, reach: 0,
            height: 2.4, eye: 0, front: 0,
            azimuth: 0, altitude: .pi / 2, segments: 4)
        XCTAssertEqual(outline.count, 4)
        XCTAssertEqual(SunMath.polygonArea(outline), 8, accuracy: 8 * 0.05)
    }

    func testShadowOutlineRoundSegmentsAndArea() {
        // Round, zenith → outline is the disc projected straight down: area ≈ π r² = `area`.
        let area = 7.1
        let outline = SunMath.shadowGroundOutline(
            shape: .round, L: 0, B: 0, area: area,
            yawDeg: 0, tiltDeg: 0, tiltDirDeg: 0, reach: 0,
            height: 2.4, eye: 0, front: 0,
            azimuth: 0, altitude: .pi / 2, segments: 48)
        XCTAssertEqual(outline.count, 48)
        XCTAssertEqual(SunMath.polygonArea(outline), area, accuracy: area * 0.05)
    }

    func testShadowOutlineNightEmpty() {
        let outline = SunMath.shadowGroundOutline(
            shape: .rect, L: 4, B: 2, area: 0,
            yawDeg: 0, tiltDeg: 0, tiltDirDeg: 0, reach: 0,
            height: 2.4, eye: 0, front: 0,
            azimuth: 0, altitude: -0.2, segments: 4)
        XCTAssertTrue(outline.isEmpty)
    }

    func testCantileverAreaInvariantAndOffset() {
        // Cantilever at zenith: reach is a pure translation → area stays L×B = 8,
        // and the footprint centroid is offset by ~reach along +X (yaw 0).
        let reach = 1.5
        let outline = SunMath.shadowGroundOutline(
            shape: .cantilever, L: 4, B: 2, area: 0,
            yawDeg: 0, tiltDeg: 0, tiltDirDeg: 0, reach: reach,
            height: 2.4, eye: 0, front: 0,
            azimuth: 0, altitude: .pi / 2, segments: 4)
        XCTAssertEqual(outline.count, 4)
        XCTAssertEqual(SunMath.polygonArea(outline), 8, accuracy: 8 * 0.05)
        let cx = outline.map(\.x).reduce(0, +) / Double(outline.count)
        XCTAssertEqual(cx, reach, accuracy: 0.05)
    }
}
