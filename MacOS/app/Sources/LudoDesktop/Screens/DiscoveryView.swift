import SwiftUI

struct DiscoveryView: View {
    @Environment(AppState.self) private var app

    private var totalModels: Int { app.inventory.categories.reduce(0) { $0 + $1.models.count } }
    private var totalRecords: Int { app.inventory.categories.flatMap(\.models).reduce(0) { $0 + ($1.records ?? 0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Discovery complete")
                    .font(.system(size: 22, weight: .bold))
                Text("We scanned your source system read-only. Nothing was changed.")
                    .font(.system(size: 13.5)).foregroundStyle(Theme.textSecondary)
                    .padding(.top, 3)

                Pill(text: MockData.versionPair, bg: Color(hex: 0xEEF3FF), fg: Theme.depText)
                    .padding(.top, 14)

                HStack(spacing: 14) {
                    statCard("\(app.inventory.totalModules)", "Installed modules", warn: false)
                    statCard("\(totalModels)", "Data models", warn: false)
                    statCard(totalRecords.compact, "Records", warn: false)
                    statCard("6", "Port-blocker modules", warn: true)
                }
                .padding(.top, 22)

                ReadinessPanels().padding(.top, 22)

                Button { app.step = .scope } label: {
                    Text("Configure migration scope →").fontWeight(.semibold)
                        .padding(.horizontal, 6)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .padding(.top, 24)
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .navigationTitle("\(MockData.customerName) — Discovery")
    }

    private func statCard(_ value: String, _ label: String, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 27, weight: .bold))
                .foregroundStyle(warn ? Theme.warn : Theme.textPrimary)
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warn ? Theme.warnBg : Theme.cardBg)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(warn ? Theme.warnBorder : Theme.cardBorder))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}

/// Two readiness panels under the stat cards.
private struct ReadinessPanels: View {
    @Environment(AppState.self) private var app
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Card(title: "Largest modules by data") {
                VStack(spacing: 0) {
                    panelRow("Accounting", "account.*", "≈ 1.2M records")
                    Divider()
                    panelRow("Sales", "sale.*", "480K records")
                    Divider()
                    panelRow("Inventory", "stock.*", "410K records")
                    Divider()
                    panelRow("CRM", "crm.*", "38K records")
                }
            }
            Card(title: "Migration readiness") {
                VStack(spacing: 0) {
                    KVRow(label: "Standard modules") { Pill(text: "152 ready", bg: Theme.okPillBg, fg: Theme.okPillText) }
                    Divider()
                    KVRow(label: "Custom / Studio modules") { Pill(text: "6 need port", bg: Theme.badPillBg, fg: Theme.badPillText) }
                    Divider()
                    KVRow(label: "Custom fields detected") { Text("214").foregroundStyle(Theme.textSecondary) }
                    Divider()
                    KVRow(label: "Estimated effort") { Text("€1,650 – €2,100").foregroundStyle(Theme.textSecondary) }
                }
            }
        }
    }

    private func panelRow(_ name: String, _ tech: String, _ trailing: String) -> some View {
        HStack {
            Text(name) + Text("  \(tech)").foregroundStyle(Theme.textSecondary).font(.system(size: 12))
            Spacer()
            Text(trailing).foregroundStyle(Theme.textSecondary).font(.system(size: 12))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 14).padding(.vertical, 9)
    }
}
