import SwiftUI

/// Agency console — one operator (a `superdev`) tracking migrations across all
/// managed client accounts. Roster comes pre-scoped from `GET /migrations`.
struct FleetView: View {
    @Environment(AppState.self) private var app
    @Environment(\.apiClient) private var api

    private var orphans: [Migration] {
        app.migrations.filter { m in !app.accounts.contains { $0.id == m.accountId } }
    }

    var body: some View {
        List {
            if let err = app.loadError {
                Text(err).foregroundStyle(Theme.badPillText)
            }
            ForEach(app.accounts) { acct in
                let migs = app.migrations.filter { $0.accountId == acct.id }
                if !migs.isEmpty {
                    Section(acct.displayName) { ForEach(migs) { row($0) } }
                }
            }
            if !orphans.isEmpty { Section("Unassigned") { ForEach(orphans) { row($0) } } }
        }
        .listStyle(.inset)
        .navigationTitle("Fleet — \(app.migrations.count) migrations across \(app.accounts.count) clients")
        .toolbar {
            Button { Task { await app.refreshFleet(client: api) } } label: {
                Image(systemName: "arrow.clockwise")
            }
        }
    }

    private func row(_ mig: Migration) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mig.combo).font(.mono)
                Text(mig.id).font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            statusPill(mig)
            if mig.stateIndex == 0 {
                Button("Approve & run") {
                    Task {
                        let m = (try? await api.approve(id: mig.id)) ?? mig
                        app.openMonitor(client: api, migration: m)
                    }
                }
            } else {
                Button("Open monitor") { app.openMonitor(client: api, migration: mig) }
            }
        }
        .padding(.vertical, 4)
    }

    private func statusPill(_ mig: Migration) -> some View {
        let (bg, fg): (Color, Color)
        switch mig.agentOutcome {
        case "migrated": (bg, fg) = (Theme.okPillBg, Theme.okPillText)
        case "aborted", "partial_migrated": (bg, fg) = (Theme.badPillBg, Theme.badPillText)
        default: (bg, fg) = (Color(hex: 0xEEF3FF), Theme.depText)
        }
        return Pill(text: mig.statusText, bg: bg, fg: fg)
    }
}
