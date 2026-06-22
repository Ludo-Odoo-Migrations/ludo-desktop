import SwiftUI

/// Backend surface the app consumes (Contract A + Contract B events).
/// `MockAPIClient` runs offline with fixtures; `LiveAPIClient` talks to ludo-apps.
protocol APIClient {
    // Scope-selection (existing click-dummy flow)
    func inventory() -> Inventory
    func resolveScope(_ inventory: Inventory) -> ResolvedScope

    // Mission-control + agency (live)
    func listAccounts() async throws -> [Account]
    func listMigrations(accountId: String?) async throws -> [Migration]
    func getMigration(id: String) async throws -> Migration
    func approve(id: String) async throws -> Migration
    func resume(id: String) async throws -> Migration
    /// Contract B event stream for one migration (NDJSON SSE upstream).
    func streamEvents(migrationId: String) -> AsyncStream<SessionEvent>
}

/// Offline fixtures. `role` decides whether the roster looks like an agency
/// (many accounts → Fleet) or a single customer.
struct MockAPIClient: APIClient {
    var role: String = "customer"

    func inventory() -> Inventory { MockData.inventory }
    func resolveScope(_ inventory: Inventory) -> ResolvedScope { ScopeResolver.resolve(inventory) }

    func listAccounts() async throws -> [Account] {
        role == "superdev" ? MockData.accounts : [Account(id: "acct_acme", name: "Acme GmbH", type: "customer")]
    }

    func listMigrations(accountId: String?) async throws -> [Migration] {
        let all = role == "superdev" ? MockData.migrations : [MockData.migrations[0]]
        guard let accountId else { return all }
        return all.filter { $0.accountId == accountId }
    }

    func getMigration(id: String) async throws -> Migration {
        MockData.migrations.first { $0.id == id } ?? Migration(id: id)
    }

    func approve(id: String) async throws -> Migration {
        var m = try await getMigration(id: id)
        m.stateIndex = max(m.stateIndex, 2); m.ludoSessionId = "s_9f3a21"; m.paid = true
        return m
    }

    func resume(id: String) async throws -> Migration { try await getMigration(id: id) }

    func streamEvents(migrationId: String) -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let task = Task {
                for ev in MockData.liveScript() {
                    if Task.isCancelled { break }
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    continuation.yield(ev)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
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
