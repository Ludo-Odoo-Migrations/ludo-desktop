import SwiftUI

/// Connection settings: pick Mock vs Live, set the BFF URL + a dev bearer token.
/// Presented as a sheet from the Sign-in screen.
struct SettingsView: View {
    @Environment(ConnectionStore.self) private var conn
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var conn = conn
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Connection").font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()

            Form {
                Picker("Backend", selection: $conn.mode) {
                    Text("Mock (offline fixtures)").tag(ConnectionStore.Mode.mock)
                    Text("Live (ludo-apps BFF)").tag(ConnectionStore.Mode.live)
                }
                .pickerStyle(.radioGroup)

                if conn.mode == .live {
                    Section("Backend") {
                        TextField("Base URL", text: $conn.baseURL)
                            .textFieldStyle(.roundedBorder)
                        SecureField("Dev bearer token", text: $conn.devToken)
                            .textFieldStyle(.roundedBorder)
                        Text("Paste a dev/superadmin JWT to reach a local BFF. Production uses the browser-redirect login (BFF endpoint pending).")
                            .font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                } else {
                    Section("Demo role") {
                        Picker("Sign in as", selection: $conn.demoRole) {
                            Text("Customer").tag("customer")
                            Text("Agency (superdev)").tag("superdev")
                        }
                        .pickerStyle(.segmented)
                        Text("Agency shows the multi-client Fleet console.")
                            .font(.caption).foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 460, height: 360)
    }
}
