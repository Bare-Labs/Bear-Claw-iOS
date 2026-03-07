import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @State private var pairingInput = ""
    @State private var pairingStatus: String?
    @State private var pairingStatusIsError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("BearClaw Gateway") {
                    TextField("https://example.com", text: $settings.apiBaseURL)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    SecureField("Bearer token", text: $settings.authToken)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    TextField("Pinned cert SHA256", text: $settings.pinnedCertFingerprint)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                }

                Section("Pairing") {
                    TextField("Paste pairing JSON or tardi1: code", text: $pairingInput, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                    Button("Import Pairing Payload") {
                        importPairing()
                    }
                    if let pairingStatus {
                        Text(pairingStatus)
                            .font(.footnote)
                            .foregroundStyle(pairingStatusIsError ? .red : .green)
                    }
                }

                Section("Status") {
                    LabeledContent("Chat Mode", value: settings.isConfigured ? "Live API" : "Preview")
                    if !settings.isConfigured && !settings.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Use HTTPS for remote gateways. HTTP is only allowed for localhost.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func importPairing() {
        do {
            try settings.applyPairingPayload(pairingInput)
            pairingStatus = "Pairing applied. Endpoint, token, and cert pin updated."
            pairingStatusIsError = false
            pairingInput = ""
        } catch {
            pairingStatus = "Invalid pairing payload."
            pairingStatusIsError = true
        }
    }
}

#Preview {
    SettingsView(settings: AppSettingsStore())
}
