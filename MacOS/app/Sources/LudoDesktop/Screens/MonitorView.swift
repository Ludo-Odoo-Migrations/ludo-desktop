import SwiftUI

struct MonitorView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        HSplitView {
            leftPane.frame(minWidth: 540)
            rightPane.frame(minWidth: 320)
        }
        .navigationTitle("\(MockData.customerName) — \(app.monitorComplete ? "Migration complete" : "Migration in progress")")
        .toolbar {
            ToolbarItemGroup {
                Button("Pause") {}.disabled(app.monitorComplete)
                Button("Cancel") { app.stopMonitor(); app.step = .review }
                    .tint(Theme.badPillText)
            }
        }
        .onDisappear { app.stopMonitor() }
    }

    // MARK: Left — progress + per-model list

    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 22) {
                ProgressRing(fraction: app.overallFraction)
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.monitorComplete
                         ? "Done · \(app.completedModelCount) of \(app.progress.count) models"
                         : "Migrating · \(app.completedModelCount) of \(app.progress.count) models")
                        .font(.system(size: 18, weight: .bold))
                    Text("Session s_9f3a21 · started 11:42")
                        .font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    if let running = app.progress.first(where: { $0.status == .running }) {
                        (Text("Now: ").foregroundStyle(Theme.textSecondary)
                         + Text(running.name).font(.monoSmall).foregroundStyle(Theme.depText))
                            .font(.system(size: 13)).padding(.top, 5)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 26).padding(.vertical, 22)
            Divider()

            HStack(spacing: 26) {
                kpi("1.54M", "records loaded")
                kpi("0", "drift / rollbacks")
                kpi("3", "Cortex wake-ups")
                kpi("€1,180", "cost so far")
            }
            .padding(.horizontal, 26).padding(.vertical, 14)
            Divider()

            Text("MODELS").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary).padding(.horizontal, 26).padding(.top, 10)

            List(app.progress) { row in
                HStack(spacing: 12) {
                    statusIcon(row.status)
                    Text(row.name).font(.monoSmall).frame(width: 180, alignment: .leading)
                        .foregroundStyle(row.status == .queued ? Theme.textTertiary : Theme.textPrimary)
                    ProgressView(value: Double(row.done), total: Double(max(row.total, 1)))
                        .tint(row.status == .running ? Theme.running : Theme.success)
                    Text(label(for: row)).font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary).frame(width: 110, alignment: .trailing)
                }
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
        }
    }

    private func kpi(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func statusIcon(_ s: JobStatus) -> some View {
        switch s {
        case .done:    return Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
        case .running: return Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.running)
        case .queued:  return Image(systemName: "circle").foregroundStyle(Theme.checkOff)
        case .failed:  return Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.badPillText)
        }
    }

    private func label(for row: ModelProgress) -> String {
        switch row.status {
        case .done:    return "\(row.total.grouped) done"
        case .running: return "\(row.done.compact) / \(row.total.compact)"
        case .queued:  return "queued"
        case .failed:  return "failed"
        }
    }

    // MARK: Right — live log

    private var rightPane: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Live activity").font(.system(size: 12.5, weight: .bold))
                .padding(.horizontal, 18).padding(.vertical, 14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(app.log) { e in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(e.time).foregroundStyle(Theme.textTertiary)
                            Text(e.text).foregroundStyle(color(for: e.kind))
                        }
                        .font(.monoSmall)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
        }
    }

    private func color(for kind: MigrationEventItem.Kind) -> Color {
        switch kind {
        case .info:  return Theme.textPrimary
        case .ok:    return Theme.okPillText
        case .event: return Theme.depText
        case .warn:  return Theme.badPillText
        }
    }
}

/// Conic progress ring.
private struct ProgressRing: View {
    var fraction: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color(hex: 0xE9E9EE), lineWidth: 11)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(Theme.success, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(fraction * 100))%").font(.system(size: 21, weight: .heavy))
                Text("complete").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 96, height: 96)
        .animation(.easeOut, value: fraction)
    }
}
