import SwiftUI

/// Chooses the backend the app talks to and builds the matching APIClient.
/// Mock = offline fixtures; Live = the ludo-apps BFF (dev bearer token for now).
@Observable
final class ConnectionStore {
    enum Mode: String, CaseIterable, Identifiable, Hashable { case mock, live; var id: String { rawValue } }

    var mode: Mode = .mock
    var baseURL: String = "http://10.0.99.1:8080"   // gateway dev port; loopback alias, not localhost
    var devToken: String = ""
    /// Mock-only: pretend to be a single customer or an agency (many accounts → Fleet).
    var demoRole: String = "customer"

    init() {
        if let r = ProcessInfo.processInfo.environment["LUDO_DEMO_ROLE"], !r.isEmpty { demoRole = r }
        // Demo-only launch flag so `open --args --agency` can show the Fleet console.
        if CommandLine.arguments.contains("--agency") { demoRole = "superdev" }
    }

    var client: APIClient {
        switch mode {
        case .mock:
            return MockAPIClient(role: demoRole)
        case .live:
            guard let url = URL(string: baseURL) else { return MockAPIClient(role: demoRole) }
            return LiveAPIClient(baseURL: url, token: devToken)
        }
    }
}
