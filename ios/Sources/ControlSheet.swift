import SwiftUI

/// Collapsible bottom sheet for controlling all parasol parameters.
struct ControlSheet: View {

    @ObservedObject var state: ParasolState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: Form
                VStack(alignment: .leading, spacing: 8) {
                    Text("Form")
                        .font(.headline)
                    Picker("Form", selection: $state.shape) {
                        Text("Rund").tag(ParasolState.Shape.round)
                        Text("Rechteck").tag(ParasolState.Shape.rect)
                        Text("Ampel").tag(ParasolState.Shape.cantilever)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Abmessungen
                VStack(alignment: .leading, spacing: 8) {
                    Text("Abmessungen")
                        .font(.headline)
                    if state.shape == .round {
                        LabeledSlider(
                            label: "Schirmfläche",
                            value: $state.area,
                            range: 1.8...28.3,
                            unit: "m²",
                            format: "%.1f"
                        )
                    } else {
                        // Rechteck und Ampelschirm: rechteckiges Dach (L×B) + Drehung
                        LabeledSlider(
                            label: "Länge",
                            value: $state.length,
                            range: 1.5...6.0,
                            unit: "m",
                            format: "%.1f"
                        )
                        LabeledSlider(
                            label: "Breite",
                            value: $state.width,
                            range: 1.5...6.0,
                            unit: "m",
                            format: "%.1f"
                        )
                        LabeledSlider(
                            label: state.shape == .cantilever ? "Ausrichtung" : "Drehung",
                            value: $state.yawDeg,
                            range: 0...359,
                            unit: "°",
                            format: "%.0f"
                        )
                        if state.shape == .cantilever {
                            LabeledSlider(
                                label: "Ausladung",
                                value: $state.reach,
                                range: 0.5...3.0,
                                unit: "m",
                                format: "%.1f"
                            )
                        }
                    }
                }

                // MARK: Aufstellung
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aufstellung")
                        .font(.headline)
                    LabeledSlider(
                        label: "Masthöhe",
                        value: $state.height,
                        range: 1.6...3.2,
                        unit: "m",
                        format: "%.1f"
                    )
                    LabeledSlider(
                        label: "Neigungswinkel",
                        value: $state.tiltDeg,
                        range: 0...60,
                        unit: "°",
                        format: "%.0f"
                    )
                    LabeledSlider(
                        label: "Neigungsrichtung",
                        value: $state.tiltDirDeg,
                        range: 0...359,
                        unit: "°",
                        format: "%.0f"
                    )
                }

                // MARK: Zeit
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zeit")
                        .font(.headline)
                    DatePicker(
                        "Datum & Uhrzeit",
                        selection: Binding(
                            get: { state.date },
                            set: { newDate in
                                state.date = newDate
                                state.useNow = false
                            }
                        ),
                        displayedComponents: [.date, .hourAndMinute]
                    )

                    HStack {
                        Spacer()
                        Button {
                            state.useNow = true
                            state.date = Date()
                        } label: {
                            Label("Jetzt", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(state.useNow ? .accentColor : .secondary)
                        Spacer()
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - LabeledSlider

private struct LabeledSlider: View {

    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unit: String
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(String(format: format, value) + " " + unit)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range)
        }
        .padding(.vertical, 2)
    }
}
