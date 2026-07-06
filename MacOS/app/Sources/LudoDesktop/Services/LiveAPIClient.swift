import Foundation

/// Talks to the gateway (Contract A REST + Contract B SSE event stream).
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

    // MARK: Contract B — SSE event stream (`id:`/`event:`/`data:` frames; resumable)

    func streamEvents(migrationId: String) -> AsyncStream<SessionEvent> {
        AsyncStream { continuation in
            let task = Task {
                // Cluster reconnect policy (agentix#9 / ludo-cli omg client):
                // exponential base 0.5s, cap 30s, full jitter, transient-status
                // filter. The stream reconnects forever *by design* (a live
                // event feed), but jittered so restarts don't herd the gateway.
                var attempt = 0
                var lastEventID: Int? = nil           // JetStream seq -> resume on reconnect
                while !Task.isCancelled {
                    do {
                        let req = request("/migrations/\(migrationId)/events", method: "GET",
                                          accept: "text/event-stream", lastEventID: lastEventID)
                        let (bytes, response) = try await URLSession.shared.bytes(for: req)
                        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                        if status != 200 {
                            // Non-transient client errors (auth/gone) won't fix
                            // themselves — stop rather than hammer. 429 + 5xx are
                            // transient: fall through to jittered reconnect.
                            if (400..<500).contains(status) && status != 429 { continuation.finish(); return }
                            throw URLError(.badServerResponse)
                        }
                        attempt = 0

                        // SSE framing: accumulate `data:` lines until the blank-line boundary,
                        // then decode the joined body as one Contract B envelope. `id:` is the
                        // resumable sequence; `event:` is ignored (the envelope carries `type`).
                        var dataBuf: [String] = []
                        for try await line in bytes.lines {
                            if Task.isCancelled { break }
                            if line.isEmpty {                       // frame boundary -> dispatch
                                guard !dataBuf.isEmpty else { continue }
                                let body = dataBuf.joined(separator: "\n")
                                dataBuf.removeAll(keepingCapacity: true)
                                if let data = body.data(using: .utf8),
                                   let ev = try? Self.decoder.decode(SessionEvent.self, from: data) {
                                    continuation.yield(ev)
                                    if ev.type == "session_end" { continuation.finish(); return }
                                }
                                continue
                            }
                            if line.hasPrefix("id:") {
                                lastEventID = Int(line.dropFirst(3).trimmingCharacters(in: .whitespaces)) ?? lastEventID
                            } else if line.hasPrefix("data:") {
                                var value = line.dropFirst(5)
                                if value.first == " " { value = value.dropFirst() }
                                dataBuf.append(String(value))
                            }
                        }
                    } catch {
                        if Task.isCancelled { break }
                        try? await Task.sleep(nanoseconds: Self.backoffDelay(attempt: attempt))
                        attempt += 1
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Plumbing

    /// The gateway mounts Contract A/B routers under `/api/v1`
    /// (auth/system/health stay unprefixed). Centralised here so every call
    /// site passes the bare resource path.
    private static let apiPrefix = "/api/v1"

    // Reconnect backoff (cluster client policy — agentix#9 / ludo-cli).
    static let backoffBaseNs: UInt64 = 500_000_000     // 0.5s
    static let backoffCapNs: UInt64 = 30_000_000_000   // 30s

    /// Full-jittered exponential backoff for reconnect attempt `attempt`
    /// (0-based). Delay is a random draw in `[base/2, min(base·2^attempt, cap)]`
    /// — jitter breaks the thundering-herd after a gateway restart; the floor
    /// avoids a busy-loop.
    static func backoffDelay(attempt: Int) -> UInt64 {
        let ceiling = min(backoffBaseNs << UInt64(min(attempt, 6)), backoffCapNs)
        let floor = min(backoffBaseNs / 2, ceiling)
        return UInt64.random(in: floor...ceiling)
    }

    /// Joins base + path (path always starts with "/"; preserves any query
    /// string). Prepends the `/api/v1` prefix for Contract A/B resource paths;
    /// `/auth`, `/system`, `/health` (and anything already prefixed) pass through.
    private func url(_ path: String) -> URL {
        let base = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        let unprefixed = path.hasPrefix("/api/") || path.hasPrefix("/auth/")
            || path.hasPrefix("/system") || path.hasPrefix("/health")
        let full = unprefixed ? path : Self.apiPrefix + path
        return URL(string: base + full) ?? baseURL
    }

    private func request(_ path: String, method: String,
                         accept: String = "application/json", lastEventID: Int? = nil) -> URLRequest {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        if !token.isEmpty { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        req.setValue(accept, forHTTPHeaderField: "Accept")
        if let lastEventID { req.setValue(String(lastEventID), forHTTPHeaderField: "Last-Event-ID") }
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
