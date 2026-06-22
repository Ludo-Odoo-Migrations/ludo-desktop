import SwiftUI

/// App entry. Holds the long-lived services and forwards the OAuth
/// `ludo-desktop://` callback (browser-redirect login) to `AuthService`.
@main
struct LudoDesktopApp: App {
    // Default login mode is .mock for instant click-through. Flip to .live
    // on the Sign-in screen to exercise the real browser redirect.
    @State private var auth = AuthService(mode: .mock)
    @State private var app = AppState()
    private let api: APIClient = MockAPIClient()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(app)
                .environment(\.apiClient, api)
                .frame(minWidth: 980, minHeight: 660)
                // Browser-redirect callback: ludo-desktop://auth/callback?code=...
                .onOpenURL { url in auth.handleCallback(url) }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1080, height: 760)
    }
}
