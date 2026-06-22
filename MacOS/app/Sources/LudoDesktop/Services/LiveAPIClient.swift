import Foundation

/// Talks to the ludo-apps BFF (Contract A REST + Contract B NDJSON SSE).
/// Auth is a bearer token (dev-token paste for now; production browser-redirect
/// login is tracked as a BFF dependency). Scope-selection still uses mock data.
struct LiveAPIClient: APIClient {
    let baseURL: URL
    let token: String

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // Scope inventory isn't wired to the live BFF yet (#94) — keep mock.
    func inventory() -> Inventory { MockData.inventory }
    func resolveScope(_ inventory: Inventory) -> ResolvedScope { ScopeResolver.resolve(inventory) }

    // MARK: Contract A

    func listAccounts() async throws -> [Account] {
        try await getList("/accounts", key: "items")
    }

    func listMigrations(accountId: String?) async throws -> [Migration] {
        var path = "/migrations"
        if let accountId { path += "?account_id=\(accountId)" }
        return try await getList(path, key: "items")
    }

    func getMigration(id: String) async throws -> Migration {
        try await send("/migrations/\(id)", method: "GET")
    }

    func approve(id: String) async throws -> Migration {
        _ = try await sendRaw("/migrations/\(id)/approve", method: "PATCH")
        return try await getMigration(id: id)
    }

    func resume(id: String) async throws -> Migration {
        _ = try await sendRaw("/migrations/\(id)/resume", method: "PATCH")
        return try await getMigration(id: id)
    }

    // MARK: Contract B — NDJSON event stream (one JSON envelope per line)

    func streamEvents(migrationId: String) -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let task = Task {
                var backoff: UInt64 = 1_000_000_000   // 1s, doubles up to 8s
                while !Task.isCancelled {
                    do {
                        let req = request("/migrations/\(migrationId)/events", method: "GET")
                        let (bytes, response) = try await URLSession.shared.bytes(for: req)
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                        backoff = 1_000_000_000
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }
                            guard let data = line.data(using: .utf8), !line.isEmpty else { continue }
                            if let ev = try? Self.decoder.decode(SessionEvent.self, from: data) {
                                continuation.yield(ev)
                                if ev.type == "session_end" { continuation.finish(); return }
                            }
                        }
                    } catch {
                        if Task.isCancelled { break }
                        try? await Task.sleep(nanoseconds: backoff)
                        backoff = min(backoff * 2, 8_000_000_000)   // reconnect with backoff
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Plumbing

    /// Joins base + path (path always starts with "/"; preserves any query string).
    private func url(_ path: String) -> URL {
        let base = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        return URL(string: base + path) ?? baseURL
    }

    private func request(_ path: String, method: String) -> URLRequest {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        return req
    }

    private func sendRaw(_ path: String, method: String) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request(path, method: method))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func send<T: Decodable>(_ path: String, method: String) async throws -> T {
        try Self.decoder.decode(T.self, from: try await sendRaw(path, method: method))
    }

    private func getList<T: Decodable>(_ path: String, key: String) async throws -> [T] {
        let data = try await sendRaw(path, method: "GET")
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let itemsData = try JSONSerialization.data(withJSONObject: obj?[key] ?? [])
        return try Self.decoder.decode([T].self, from: itemsData)
    }
}
