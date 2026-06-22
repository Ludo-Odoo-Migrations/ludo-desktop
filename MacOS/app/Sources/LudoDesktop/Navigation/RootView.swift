import SwiftUI

/// Routes between sign-in and the four post-auth steps.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(AppState.self) private var app

    var body: some View {
        Group {
            if !auth.isSignedIn {
                SignInView()
            } else {
                switch app.step {
                case .discovery: DiscoveryView()
                case .scope:     ScopePickerView()
                case .review:    ReviewView()
                case .monitor:   MonitorView()
                }
            }
        }
        .animation(.default, value: auth.isSignedIn)
        .animation(.default, value: app.step)
    }
}
