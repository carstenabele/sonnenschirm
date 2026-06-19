import Foundation
import Combine
import SunMathKit

/// Observable state model for the parasol (Sonnenschirm).
final class ParasolState: ObservableObject {

    // MARK: - Shape

    enum Shape {
        case round, rect
    }

    // MARK: - Published properties

    @Published var shape: Shape = .rect

    /// Length of the parasol in metres (1.5–6.0 m)
    @Published var length: Double = 4.0

    /// Width of the parasol in metres (1.5–6.0 m)
    @Published var width: Double = 2.0

    /// Effective area in m² (used for round shapes; ignored when rect uses L×B)
    @Published var area: Double = 7.1

    /// Horizontal rotation in degrees (0–359°)
    @Published var yawDeg: Double = 0.0

    /// Tilt angle in degrees (0–60°)
    @Published var tiltDeg: Double = 0.0

    /// Direction of tilt in degrees (0–359°)
    @Published var tiltDirDeg: Double = 0.0

    /// Mast height in metres (1.6–3.2 m)
    @Published var height: Double = 2.4

    /// Manually selected date/time (used when useNow == false)
    @Published var date: Date = Date()

    /// When true, effectiveDate returns Date() (current time)
    @Published var useNow: Bool = true

    /// Latitude in decimal degrees (Frankfurt default)
    @Published var lat: Double = 50.11

    /// Longitude in decimal degrees (Frankfurt default)
    @Published var lng: Double = 8.68

    // MARK: - Derived

    /// The date used for sun calculations
    var effectiveDate: Date {
        useNow ? Date() : date
    }

    // MARK: - SunMath interface

    /// Returns the sun position (azimuth and altitude in radians) for the current state.
    func sun() -> (azimuth: Double, altitude: Double) {
        SunMath.position(date: effectiveDate, lat: lat, lng: lng)
    }

    /// Returns shadow metrics for the current parasol configuration.
    func metrics() -> (areaM2: Double, lengthM: Double, isNight: Bool) {
        let s = sun()
        return SunMath.shadowMetrics(
            L: length,
            B: width,
            yawDeg: yawDeg,
            tiltDeg: tiltDeg,
            tiltDirDeg: tiltDirDeg,
            height: height,
            eye: 0,
            front: 0,
            azimuth: s.azimuth,
            altitude: s.altitude
        )
    }
}
