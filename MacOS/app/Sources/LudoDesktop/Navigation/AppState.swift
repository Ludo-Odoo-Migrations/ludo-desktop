import SwiftUI

/// Flow + selection state for the whole app. Mutates the inventory selection
/// in place; the summary footer reads `resolved` (the mock /resolve-scope).
@Observable
final class AppState {
    enum Step { case discovery, scope, review, monitor }

    var step: Step = .discovery
    var inventory = MockData.inventory
    var selectedCategoryID: String?
    var inspectedModelID: String?
    var runMode: RunMode = .migrate
    var searchText: String = ""

    // Monitor
    var progress: [ModelProgress] = []
    var log: [MigrationEventItem] = []
    var monitorComplete = false
    @ObservationIgnored private var timer: Timer?

    init() {
        selectedCategoryID = inventory.categories.first { $0.name == "Sales" }?.id
            ?? inventory.categories.first?.id
        inspectedModelID = currentCategory?.models.first?.id
    }

    // MARK: Derived

    var currentCategory: ModuleCategory? {
        inventory.categories.first { $0.id == selectedCategoryID }
    }
    var inspectedModel: ModelInfo? {
        inventory.categories.flatMap(\.models).first { $0.id == inspectedModelID }
    }
    var resolved: ResolvedScope { ScopeResolver.resolve(inventory) }

    /// Models in the current category filtered by the search box.
    var visibleModels: [ModelInfo] {
        let models = currentCategory?.models ?? []
        guard !searchText.isEmpty else { return models }
        return models.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.label.localizedCaseInsensitiveContains(searchText)
        }
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

    // MARK: Mutations

    func toggleCategory(_ id: String) {
        guard let c = inventory.categories.firstIndex(where: { $0.id == id }) else { return }
        let turnOn = state(for: inventory.categories[c]) != .on
        for m in inventory.categories[c].models.indices {
            inventory.categories[c].models[m].selected = turnOn
        }
    }

    func toggleModel(categoryID: String, modelID: String) {
        guard let c = inventory.categories.firstIndex(where: { $0.id == categoryID }),
              let m = inventory.categories[c].models.firstIndex(where: { $0.id == modelID })
        else { return }
        inventory.categories[c].models[m].selected.toggle()
    }

    func toggleAll() {
        let turnOn = allState != .on
        setAll(turnOn)
    }

    func resetToAll() { setAll(true) }

    private func setAll(_ value: Bool) {
        for c in inventory.categories.indices {
            for m in inventory.categories[c].models.indices {
                inventory.categories[c].models[m].selected = value
            }
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

    // MARK: Monitor simulation

    func startMonitor(api: APIClient) {
        progress = api.initialProgress()
        log = []
        monitorComplete = false
        let script = api.eventScript()
        var i = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            guard i < script.count else {
                t.invalidate()
                self.monitorComplete = true
                return
            }
            self.log.append(script[i])
            self.advanceProgress()
            i += 1
        }
    }

    func stopMonitor() { timer?.invalidate(); timer = nil }

    private func advanceProgress() {
        if let r = progress.firstIndex(where: { $0.status == .running }) {
            progress[r].done = progress[r].total
            progress[r].status = .done
            if let next = progress.firstIndex(where: { $0.status == .queued }) {
                progress[next].status = .running
            }
        } else if let next = progress.firstIndex(where: { $0.status == .queued }) {
            progress[next].status = .running
        }
    }

    var completedModelCount: Int { progress.filter { $0.status == .done }.count }
    var overallFraction: Double {
        guard !progress.isEmpty else { return 0 }
        return Double(completedModelCount) / Double(progress.count)
    }
}
