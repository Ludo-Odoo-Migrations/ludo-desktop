import SwiftUI

/// Flow + selection + live-monitor state. Drives the scope-picker (mock) and the
/// live mission-control / fleet (Contract A/B) from one observable.
@MainActor
@Observable
final class AppState {
    enum Step { case fleet, discovery, scope, review, monitor }

    var step: Step = .discovery
    var role: String = "customer"

    // Agency / fleet
    var accounts: [Account] = []
    var migrations: [Migration] = []
    var selectedMigrationID: String?
    var loadError: String?

    // Scope picker (unchanged)
    var inventory = MockData.inventory
    var selectedCategoryID: String?
    var inspectedModelID: String?
    var runMode: RunMode = .migrate
    var searchText: String = ""

    // Monitor (event-driven)
    var progress: [ModelProgress] = []
    var log: [MigrationEventItem] = []
    var monitorComplete = false
    var expectedTotal = 0
    var turnCount = 0
    var driftCount = 0
    var costUsd: Double = 0
    var outcome: String?
    var monitorReturnStep: Step = .review
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    init() {
        selectedCategoryID = inventory.categories.first { $0.name == "Sales" }?.id ?? inventory.categories.first?.id
        inspectedModelID = currentCategory?.models.first?.id
    }

    // MARK: Bootstrap (role + roster)

    func bootstrap(client: APIClient) async {
        do {
            async let a = client.listAccounts()
            async let m = client.listMigrations(accountId: nil)
            accounts = try await a
            migrations = try await m
            role = accounts.count > 1 ? "superdev" : "customer"
            step = role == "superdev" ? .fleet : .discovery
        } catch {
            loadError = error.localizedDescription
            role = "customer"; step = .discovery
        }
    }

    func refreshFleet(client: APIClient) async {
        if let m = try? await client.listMigrations(accountId: nil) { migrations = m }
    }

    func accountName(_ id: String) -> String {
        accounts.first { $0.id == id }?.displayName ?? id
    }

    // MARK: Scope picker (derived + mutations)

    var currentCategory: ModuleCategory? { inventory.categories.first { $0.id == selectedCategoryID } }
    var inspectedModel: ModelInfo? { inventory.categories.flatMap(\.models).first { $0.id == inspectedModelID } }
    var resolved: ResolvedScope { ScopeResolver.resolve(inventory) }
    var visibleModels: [ModelInfo] {
        let models = currentCategory?.models ?? []
        guard !searchText.isEmpty else { return models }
        return models.filter { $0.name.localizedCaseInsensitiveContains(searchText) || $0.label.localizedCaseInsensitiveContains(searchText) }
    }
    func state(for category: ModuleCategory) -> CheckState {
        let sel = category.models.filter(\.selected).count
        if sel == 0 { return .off }
        return sel == category.models.count ? .on : .mixed
    }
    var allState: CheckState {
        let all = inventory.categories.flatMap(\.models)
        let sel = all.filter(\.selected).count
        if sel == 0 { return .off }
        return sel == all.count ? .on : .mixed
    }
    func toggleCategory(_ id: String) {
        guard let c = inventory.categories.firstIndex(where: { $0.id == id }) else { return }
        let turnOn = state(for: inventory.categories[c]) != .on
        for m in inventory.categories[c].models.indices { inventory.categories[c].models[m].selected = turnOn }
    }
    func toggleModel(categoryID: String, modelID: String) {
        guard let c = inventory.categories.firstIndex(where: { $0.id == categoryID }),
              let m = inventory.categories[c].models.firstIndex(where: { $0.id == modelID }) else { return }
        inventory.categories[c].models[m].selected.toggle()
    }
    func toggleAll() { setAll(allState != .on) }
    func resetToAll() { setAll(true) }
    private func setAll(_ value: Bool) {
        for c in inventory.categories.indices {
            for m in inventory.categories[c].models.indices { inventory.categories[c].models[m].selected = value }
        }
    }
    func toggleCustomField(modelID: String, fieldID: UUID) {
        for c in inventory.categories.indices {
            guard let m = inventory.categories[c].models.firstIndex(where: { $0.id == modelID }) else { continue }
            if let f = inventory.categories[c].models[m].customFields.firstIndex(where: { $0.id == fieldID }) {
                inventory.categories[c].models[m].customFields[f].selected.toggle()
            }
        }
    }

    // MARK: Live monitor (Contract B stream)

    /// Open the monitor for a fleet migration.
    func openMonitor(client: APIClient, migration: Migration) {
        selectedMigrationID = migration.id
        monitorReturnStep = role == "superdev" ? .fleet : .review
        startMonitor(client: client, migrationID: migration.ludoSessionId ?? migration.id)
        step = .monitor
    }

    func startMonitor(client: APIClient, migrationID: String) {
        progress = []; log = []; monitorComplete = false
        expectedTotal = 0; turnCount = 0; driftCount = 0; costUsd = 0; outcome = nil
        monitorTask?.cancel()
        monitorTask = Task { [weak self] in
            for await ev in client.streamEvents(migrationId: migrationID) {
                self?.apply(ev)
            }
            self?.monitorComplete = true
        }
    }

    func stopMonitor() { monitorTask?.cancel(); monitorTask = nil }

    private func apply(_ ev: SessionEvent) {
        if let t = ev.payload.totalModels { expectedTotal = t }
        let time = Self.hhmmss(ev.at)
        switch ev.type {
        case "session_started":
            log.append(.init(time: time, kind: .event, text: "session_started \(ev.sessionId)"))
        case "model_started":
            if let m = ev.payload.model, !progress.contains(where: { $0.name == m }) {
                progress.append(ModelProgress(name: m, status: .running, done: 0, total: 1))
            }
            log.append(.init(time: time, kind: .event, text: "model_started \(ev.payload.model ?? "")"))
        case "model_completed":
            if let m = ev.payload.model, let i = progress.firstIndex(where: { $0.name == m }) {
                progress[i].status = .done; progress[i].done = 1
            }
            log.append(.init(time: time, kind: .ok, text: "model_completed \(ev.payload.model ?? "") ✓"))
        case "turn_completed":
            turnCount += 1
            if let c = ev.payload.costUsd { costUsd += c }
            log.append(.init(time: time, kind: .ok, text: "turn_completed \(ev.payload.message ?? "")"))
        case "turn_started", "job_started", "job_completed":
            log.append(.init(time: time, kind: .event, text: "\(ev.type) \(ev.payload.model ?? "")"))
        case "job_failed", "safety_event":
            driftCount += 1
            log.append(.init(time: time, kind: .warn, text: "\(ev.type) \(ev.payload.message ?? "")"))
        case "session_end":
            outcome = ev.payload.outcome
            if let c = ev.payload.costUsd, costUsd == 0 { costUsd = c }
            monitorComplete = true
            log.append(.init(time: time, kind: .ok, text: "session_end outcome=\(ev.payload.outcome ?? "")"))
        default:
            break
        }
    }

    var completedModelCount: Int { progress.filter { $0.status == .done }.count }
    var overallFraction: Double {
        let total = expectedTotal > 0 ? expectedTotal : progress.count
        guard total > 0 else { return 0 }
        return Double(completedModelCount) / Double(total)
    }

    private static func hhmmss(_ at: String) -> String {
        if at.isEmpty { return "" }
        if let tRange = at.range(of: "T") {           // ISO-8601 → time part
            return String(at[tRange.upperBound...].prefix(8))
        }
        return at
    }
}
