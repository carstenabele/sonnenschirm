import Foundation
import simd

public enum SunMath {
    public static let deg = Double.pi / 180

    public static func position(date: Date, lat: Double, lng: Double) -> (azimuth: Double, altitude: Double) {
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

    public static func vector(azimuth: Double, altitude: Double) -> SIMD3<Double> {
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

    public static func rectCornersWorld(L: Double, B: Double, yawDeg: Double, tiltDeg: Double,
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

    /// World-space rim points of a round canopy (radius `radius`) at the mast
    /// top, after tilt-direction and tilt. Yaw is irrelevant for a disc.
    public static func roundRimWorld(radius: Double, tiltDeg: Double, tiltDirDeg: Double,
                                     height: Double, eye: Double, front: Double, segments: Int) -> [SIMD3<Double>] {
        let dir = tiltDirDeg * deg, tip = tiltDeg * deg
        let topY = -eye + height
        let n = max(3, segments)
        return (0..<n).map { i in
            let a = 2 * Double.pi * Double(i) / Double(n)
            let local = SIMD3(radius * cos(a), 0, radius * sin(a))
            var q = rotY(local, dir); q = rotX(q, tip)
            return SIMD3(q.x, q.y + topY, q.z - front)
        }
    }

    /// Projected ground outline (x,z) of the canopy's shadow for the given sun.
    /// Returns an empty array at night (altitude ≤ 0). For round canopies the
    /// radius is derived from `area`; `segments` controls the round resolution.
    public static func shadowGroundOutline(isRound: Bool, L: Double, B: Double, area: Double,
                                           yawDeg: Double, tiltDeg: Double, tiltDirDeg: Double,
                                           height: Double, eye: Double, front: Double,
                                           azimuth: Double, altitude: Double, segments: Int) -> [SIMD2<Double>] {
        if altitude <= 0 { return [] }
        let sv = vector(azimuth: azimuth, altitude: altitude)
        let worldPts: [SIMD3<Double>]
        if isRound {
            let r = (area / Double.pi).squareRoot()
            worldPts = roundRimWorld(radius: r, tiltDeg: tiltDeg, tiltDirDeg: tiltDirDeg,
                                     height: height, eye: eye, front: front, segments: segments)
        } else {
            worldPts = rectCornersWorld(L: L, B: B, yawDeg: yawDeg, tiltDeg: tiltDeg,
                                        tiltDirDeg: tiltDirDeg, height: height, eye: eye, front: front)
        }
        return worldPts.map { projectToGround($0, sun: sv, yGround: -eye) }
    }

    public static func projectToGround(_ p: SIMD3<Double>, sun: SIMD3<Double>, yGround: Double) -> SIMD2<Double> {
        let t = (p.y - yGround) / sun.y
        return SIMD2(p.x - sun.x * t, p.z - sun.z * t)
    }

    public static func polygonArea(_ pts: [SIMD2<Double>]) -> Double {
        var a = 0.0
        for i in 0..<pts.count {
            let p = pts[i], q = pts[(i + 1) % pts.count]
            a += p.x * q.y - q.x * p.y   // SIMD2: .x=x, .y=z
        }
        return abs(a) / 2
    }

    public static func mastShadowLength(height: Double, altitude: Double) -> Double {
        altitude <= 0 ? .infinity : height / tan(altitude)
    }

    public static func shadowMetrics(L: Double, B: Double, yawDeg: Double, tiltDeg: Double, tiltDirDeg: Double,
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
