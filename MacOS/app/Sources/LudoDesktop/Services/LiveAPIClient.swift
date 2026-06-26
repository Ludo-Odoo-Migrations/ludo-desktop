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
                var backoff: UInt64 = 1_000_000_000   // 1s, doubles up to 8s
                var lastEventID: Int? = nil           // JetStream seq -> resume on reconnect
                while !Task.isCancelled {
                    do {
                        let req = request("/migrations/\(migrationId)/events", method: "GET",
                                          accept: "text/event-stream", lastEventID: lastEventID)
                        let (bytes, response) = try await URLSession.shared.bytes(for: req)
                        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                        backoff = 1_000_000_000

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
