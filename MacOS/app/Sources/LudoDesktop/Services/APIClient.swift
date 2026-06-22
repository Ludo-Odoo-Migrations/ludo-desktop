import SwiftUI

/// Backend surface the app consumes (Contract A — see issue euroblaze/ludo-flywheel#94).
/// The click-dummy uses `MockAPIClient`; `LiveAPIClient` is the drop-in for real wiring.
protocol APIClient {
    func inventory() -> Inventory
    func resolveScope(_ inventory: Inventory) -> ResolvedScope
    func eventScript() -> [MigrationEventItem]
    func initialProgress() -> [ModelProgress]
}

/// Returns the static Acme GmbH fixture; resolve mirrors the server closure.
struct MockAPIClient: APIClient {
    func inventory() -> Inventory { MockData.inventory }
    func resolveScope(_ inventory: Inventory) -> ResolvedScope { ScopeResolver.resolve(inventory) }
    func eventScript() -> [MigrationEventItem] { MockData.eventScript }
    func initialProgress() -> [ModelProgress] { MockData.progress }
}

/// TODO(#94): implement against the ludo-apps BFF:
///   GET  /estimates/{id}/inventory
///   POST /estimates/{id}/resolve-scope
///   POST /migrations  +  GET /migrations/{id}/events (SSE)
/// Currently delegates to mock data so the app stays runnable.
struct LiveAPIClient: APIClient {
    let baseURL: URL
    let token: String
    func inventory() -> Inventory { MockData.inventory }
    func resolveScope(_ inventory: Inventory) -> ResolvedScope { ScopeResolver.resolve(inventory) }
    func eventScript() -> [MigrationEventItem] { MockData.eventScript }
    func initialProgress() -> [ModelProgress] { MockData.progress }
}

// Inject via the environment so screens stay backend-agnostic.
private struct APIClientKey: EnvironmentKey {
    static let defaultValue: APIClient = MockAPIClient()
}
extension EnvironmentValues {
    var apiClient: APIClient {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}
