import SwiftUI

struct ReviewView: View {
    @Environment(AppState.self) private var app
    @Environment(\.apiClient) private var api

    var body: some View {
        @Bindable var app = app
        let s = app.resolved
        let excluded = s.totalModelCount - (s.selectedModelCount - s.autoIncludedDeps.count)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Review your migration").font(.system(size: 22, weight: .bold))
                Text("Confirm the scope and mode. You can re-run an estimate without touching your data.")
                    .font(.system(size: 13.5)).foregroundStyle(Theme.textSecondary).padding(.top, 3)

                HStack(alignment: .top, spacing: 18) {
                    Card(title: "Selected scope") {
                        VStack(spacing: 0) {
                            KVRow(label: "Models") {
                                HStack(spacing: 8) {
                                    Text("\(s.selectedModelCount - s.autoIncludedDeps.count)").bold()
                                    Text("selected").foregroundStyle(Theme.textSecondary)
                                    Pill(text: "+\(s.autoIncludedDeps.count) deps", bg: Theme.okPillBg, fg: Theme.okPillText)
                                }
                            }
                            Divider()
                            KVRow(label: "Excluded models") { Text("\(max(0, excluded))").foregroundStyle(Theme.textSecondary) }
                            Divider()
                            KVRow(label: "Records to migrate") { Text("~\(s.recordsEstimate.compact)").bold() }
                            Divider()
                            KVRow(label: "Port-blockers flagged") {
                                Text("\(s.portBlockersHit.count)").foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }

                    Card(title: "Estimate") {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("€\(s.costEUR.grouped)")
                                .font(.system(size: 34, weight: .heavy))
                                .padding(.horizontal, 16).padding(.top, 18)
                            Text("approx. cost · billed on completion")
                                .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                                .padding(.horizontal, 16).padding(.bottom, 14)
                            Divider()
                            KVRow(label: "Version pair") {
                                Text("15.0 → 18.0 EE").foregroundStyle(Theme.textSecondary)
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Run mode").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                                Picker("Run mode", selection: $app.runMode) {
                                    ForEach(RunMode.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented).labelsHidden()
                            }
                            .padding(14)
                        }
                    }
                }
                .padding(.top, 22)

                HStack(spacing: 14) {
                    Button {
                        app.startMonitor(api: api)
                        app.step = .monitor
                    } label: {
                        Text("Start migration ▸").fontWeight(.bold).padding(.horizontal, 8)
                    }
                    .controlSize(.large).buttonStyle(.borderedProminent)

                    Text("A copy of your selection is saved to this migration. The engine runs server-side; you can close the app and reopen to watch progress.")
                        .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
                }
                .padding(.top, 24)
            }
            .padding(30)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white)
        .navigationTitle("\(MockData.customerName) — Review & launch")
        .toolbar {
            ToolbarItem {
                Button("← Back to scope") { app.step = .scope }
            }
        }
    }
}
