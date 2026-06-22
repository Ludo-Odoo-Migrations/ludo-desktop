import SwiftUI

/// Routes between sign-in and the post-auth steps; bootstraps role + roster on login.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var app
    @Environment(\.apiClient) private var api

    var body: some View {
        Group {
            if !auth.isSignedIn {
                SignInView()
            } else {
                switch app.step {
                case .fleet:     FleetView()
                case .discovery: DiscoveryView()
                case .scope:     ScopePickerView()
                case .review:    ReviewView()
                case .monitor:   MonitorView()
                }
            }
        }
        .task(id: auth.isSignedIn) {
            if auth.isSignedIn && app.accounts.isEmpty {
                await app.bootstrap(client: api)
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .animation(.default, value: app.step)
    }
}
