import Foundation

enum RunMode: String, CaseIterable, Identifiable {
    case estimate = "Estimate", migrate = "Migrate", dryRun = "Dry-run"
    var id: String { rawValue }
}

enum JobStatus { case done, running, queued, failed }

/// One custom / Studio field on a model. Default = migrate (opt-out).
struct CustomField: Identifiable, Hashable {
    let id = UUID()
    let name: String
    var selected: Bool = true
}

/// An Odoo data model in the inventory.
struct ModelInfo: Identifiable, Hashable {
    var id: String { name }
    let name: String          // e.g. "sale.order"
    let label: String         // e.g. "Sales Order"
    let records: Int?         // nil => unknown / view ("—")
    let fieldCount: Int
    var selected: Bool = true
    var customFields: [CustomField] = []
}

/// A module category grouping models (the left column).
struct ModuleCategory: Identifiable, Hashable {
    var id: String { name }
    let name: String          // "Sales"
    let symbol: String        // SF Symbol
    let moduleCount: Int       // installed modules in this category
    var models: [ModelInfo]
}

struct Inventory {
    var categories: [ModuleCategory]
    let totalModules: Int
}

/// A model auto-pulled into scope because selected data depends on it.
struct Dependency: Identifiable, Hashable {
    var id: String { model }
    let model: String
    let reason: String
}

/// A custom module owning selected data that must be ported first.
struct PortBlocker: Identifiable, Hashable {
    let id = UUID()
    let module: String
    let owns: String          // "sale.order.x_delivery_route"
    let note: String
}

/// Result of resolving a tentative selection (mirrors the BFF /resolve-scope).
struct ResolvedScope {
    var selectedModelCount: Int   // includes auto-included deps
    var totalModelCount: Int
    var autoIncludedDeps: [Dependency]
    var portBlockersHit: [PortBlocker]
    var recordsEstimate: Int
    var costEUR: Int
}

/// One line in the live activity log.
struct MigrationEventItem: Identifiable {
    let id = UUID()
    let time: String
    let kind: Kind
    let text: String
    enum Kind { case info, ok, event, warn }
}

/// Per-model progress in the monitor.
struct ModelProgress: Identifiable {
    var id: String { name }
    let name: String
    var status: JobStatus
    var done: Int
    var total: Int
}

/// Deterministic scope resolver — the mock equivalent of the BFF closure.
/// Shared by `MockAPIClient` and the live summary footer.
enum ScopeResolver {
    static func resolve(_ inv: Inventory) -> ResolvedScope {
        let allModels = inv.categories.flatMap { $0.models }
        let selected = allModels.filter { $0.selected }
        // Dependencies are auto-included whenever any business data is selected.
        let deps = selected.isEmpty ? [] : MockData.dependencies
        // Port-blocker fires when sale.order (with its custom field) is in scope.
        let blockers = selected.contains { $0.name == "sale.order" } ? MockData.portBlockers : []
        let records = selected.reduce(0) { $0 + ($1.records ?? 0) }
        let cost = Int((Double(records) * 0.00075).rounded())
        return ResolvedScope(
            selectedModelCount: selected.count + deps.count,
            totalModelCount: allModels.count,
            autoIncludedDeps: deps,
            portBlockersHit: blockers,
            recordsEstimate: records,
            costEUR: cost
        )
    }
}
