import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        @Bindable var auth = auth
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 4) {
                (Text("LU").foregroundStyle(Theme.textPrimary)
                 + Text("DO").foregroundStyle(Theme.accent))
                    .font(.system(size: 44, weight: .heavy))
                Text("Odoo Migration · for Mac")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.bottom, 36)

                Button(action: auth.signIn) {
                    HStack(spacing: 9) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                        Text(auth.isAuthenticating ? "Waiting for browser…" : "Sign in with GitHub")
                            .fontWeight(.semibold)
                    }
                    .frame(width: 300, height: 30)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x1B1F24))
                .disabled(auth.isAuthenticating)

                Text("Authentication via GitHub OAuth.\nNo password is stored on this device.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 16)

                if let err = auth.lastError {
                    Text(err).font(.caption).foregroundStyle(Theme.badPillText).padding(.top, 6)
                }

                // Dummy-only: switch the login fidelity.
                Picker("Login mode", selection: $auth.mode) {
                    Text("Mock (instant)").tag(AuthService.Mode.mock)
                    Text("Live (browser redirect)").tag(AuthService.Mode.live)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 320)
                .padding(.top, 28)
            }
            Spacer()
            Text("v0.2 · connects to ludo.euroblaze.de")
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
