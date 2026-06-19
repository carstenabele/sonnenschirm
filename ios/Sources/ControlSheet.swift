import SwiftUI

/// Collapsible bottom sheet for controlling all parasol parameters.
struct ControlSheet: View {

    @ObservedObject var state: ParasolState

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Form
                Section("Form") {
                    Picker("Form", selection: $state.shape) {
                        Text("Rund").tag(ParasolState.Shape.round)
                        Text("Rechteck").tag(ParasolState.Shape.rect)
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Abmessungen
                if state.shape == .rect {
                    Section("Abmessungen") {
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
                            label: "Drehung",
                            value: $state.yawDeg,
                            range: 0...359,
                            unit: "°",
                            format: "%.0f"
                        )
                    }
                } else {
                    Section("Abmessungen") {
                        LabeledSlider(
                            label: "Schirmfläche",
                            value: $state.area,
                            range: 1.8...28.3,
                            unit: "m²",
                            format: "%.1f"
                        )
                    }
                }

                // MARK: Aufstellung
                Section("Aufstellung") {
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
                Section("Zeit") {
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
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Schattenwerfer")
            .navigationBarTitleDisplayMode(.inline)
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
