import SwiftUI

struct ContentView: View {

    @StateObject var state = ParasolState()
    @StateObject var loc = LocationProvider()

    var body: some View {
        ZStack(alignment: .top) {
            // Full-screen AR view as the base layer
            ARSceneView(state: state)
                .ignoresSafeArea()

            // Subtle readout strip at the top
            ReadoutStrip(state: state)

            // Reset button (re-aim & place again)
            VStack {
                HStack {
                    Spacer()
                    Button {
                        state.requestPlacementReset()
                    } label: {
                        Label("Neu platzieren", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.trailing, 14)
                    .padding(.top, 52)
                }
                Spacer()
            }
        }
        .sheet(isPresented: .constant(true)) {
            ControlSheet(state: state)
                .presentationDetents(
                    Set<PresentationDetent>([.height(120), .medium, .large])
                )
                .presentationBackgroundInteraction(PresentationBackgroundInteraction.enabled(upThrough: .medium))
                .interactiveDismissDisabled(true)
        }
        .onAppear {
            loc.start()
        }
        .onChange(of: loc.coordinate.lat) { _, newLat in
            state.lat = newLat
        }
        .onChange(of: loc.coordinate.lng) { _, newLng in
            state.lng = newLng
        }
    }
}

// MARK: - ReadoutStrip

private struct ReadoutStrip: View {

    @ObservedObject var state: ParasolState

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    private var sunValues: (azDeg: Double, altDeg: Double) {
        let s = state.sun()
        let az = s.azimuth * 180.0 / .pi
        let alt = s.altitude * 180.0 / .pi
        return (az < 0 ? az + 360 : az, alt)
    }

    private var areaM2: Double {
        state.metrics().areaM2
    }

    private var timeString: String {
        Self.timeFormatter.string(from: state.effectiveDate)
    }

    var body: some View {
        let sun = sunValues
        HStack(spacing: 16) {
            Label(timeString, systemImage: "clock")
            Label(String(format: "%.0f°", sun.azDeg), systemImage: "safari")
            Label(String(format: "%.0f°", sun.altDeg), systemImage: "sun.horizon")
            Label(String(format: "%.1f m²", areaM2), systemImage: "cube.transparent")
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 8)
    }
}
