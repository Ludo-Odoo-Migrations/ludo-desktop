import SwiftUI

/// Hero screen — 3-column module → model → inspector, with a live summary footer.
struct ScopePickerView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        @Bindable var app = app
        NavigationSplitView {
            categorySidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 220, max: 260)
        } content: {
            modelList
                .navigationSplitViewColumnWidth(min: 320, ideal: 420)
        } detail: {
            inspector
                .navigationSplitViewColumnWidth(min: 300, ideal: 320, max: 360)
        }
        .safeAreaInset(edge: .bottom) { summaryBar }
        .navigationTitle("\(MockData.customerName) — Choose what to migrate")
        .toolbar {
            ToolbarItemGroup {
                TextField("Filter models…", text: $app.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                Button("Reset to all") { app.resetToAll() }
                Button("Review →") { app.step = .review }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: Column 1 — categories

    private var categorySidebar: some View {
        @Bindable var app = app
        return List(selection: $app.selectedCategoryID) {
            Section("Modules by category") {
                Button { app.toggleAll() } label: {
                    categoryRow(check: app.allState, symbol: "square.grid.2x2",
                                name: "All", count: app.inventory.totalModules)
                }
                .buttonStyle(.plain)

                ForEach(app.inventory.categories) { cat in
                    HStack(spacing: 9) {
                        Button { app.toggleCategory(cat.id) } label: { Checkbox(state: app.state(for: cat)) }
                            .buttonStyle(.plain)
                        Image(systemName: cat.symbol).frame(width: 16).foregroundStyle(Theme.textSecondary)
                        Text(cat.name).font(.system(size: 13.5))
                        Spacer()
                        Text("\(cat.moduleCount)").font(.system(size: 11.5)).foregroundStyle(Theme.textTertiary)
                    }
                    .tag(cat.id)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func categoryRow(check: CheckState, symbol: String, name: String, count: Int) -> some View {
        HStack(spacing: 9) {
            Checkbox(state: check)
            Image(systemName: symbol).frame(width: 16).foregroundStyle(Theme.textSecondary)
            Text(name).font(.system(size: 13.5))
            Spacer()
            Text("\(count)").font(.system(size: 11.5)).foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: Column 2 — models

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cat = app.currentCategory {
                HStack(spacing: 11) {
                    Button { app.toggleCategory(cat.id) } label: { Checkbox(state: app.state(for: cat)) }
                        .buttonStyle(.plain)
                    Text(cat.name).font(.system(size: 15, weight: .bold))
                    Text("· \(cat.models.count) models").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 18).padding(.vertical, 13)
                Divider()
            }
            List {
                HStack {
                    Text("MODEL").frame(maxWidth: .infinity, alignment: .leading)
                    Text("RECORDS").frame(width: 96, alignment: .trailing)
                    Text("FIELDS").frame(width: 70, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                .listRowSeparator(.hidden)

                ForEach(app.visibleModels) { model in
                    modelRow(model)
                        .listRowInsets(EdgeInsets(top: 6, leading: 18, bottom: 6, trailing: 18))
                        .listRowBackground(model.id == app.inspectedModelID ? Theme.rowSelected : Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { app.inspectedModelID = model.id }
                }
            }
            .listStyle(.plain)
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        HStack(spacing: 11) {
            Button {
                if let cid = app.selectedCategoryID { app.toggleModel(categoryID: cid, modelID: model.id) }
            } label: { Checkbox(state: model.selected ? .on : .off) }
                .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(model.name).font(.mono)
                    Text(model.label).font(.system(size: 11.5)).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Text(model.records?.grouped ?? "—").font(.system(size: 13)).frame(width: 96, alignment: .trailing)
            Text("\(model.fieldCount)").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
                .frame(width: 70, alignment: .trailing)
        }
    }

    // MARK: Column 3 — inspector

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let model = app.inspectedModel {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INSPECTING MODEL").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                        Text(model.name).font(.system(size: 15, weight: .bold, design: .monospaced))
                    }
                    .padding(16)
                    Divider()

                    if !model.customFields.isEmpty {
                        section("Custom / Studio fields · \(model.customFields.count) found") {
                            ForEach(model.customFields) { field in
                                HStack(spacing: 10) {
                                    Button { app.toggleCustomField(modelID: model.id, fieldID: field.id) } label: {
                                        Checkbox(state: field.selected ? .on : .off)
                                    }.buttonStyle(.plain)
                                    Text(field.name).font(.monoSmall)
                                        .foregroundStyle(field.selected ? Theme.textPrimary : Theme.textTertiary)
                                    Spacer()
                                    Pill(text: "custom", bg: Theme.customTag, fg: .white)
                                }
                                .padding(.vertical, 3)
                            }
                            Text("Standard fields always migrate. Untick only custom fields you want to drop.")
                                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary).padding(.top, 6)
                        }
                        Divider()
                    }
                }

                // Auto-included dependencies (from the resolver).
                let scope = app.resolved
                section("Also required (auto-included)") {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(scope.autoIncludedDeps) { dep in
                            HStack(spacing: 6) {
                                Text("+ \(dep.model)").font(.monoSmall).foregroundStyle(Theme.depText)
                                Text("— \(dep.reason)").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                            }
                        }
                        Text("\(scope.autoIncludedDeps.count) dependencies pulled in across your selection.")
                            .font(.system(size: 11)).foregroundStyle(Theme.textTertiary).padding(.top, 4)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.depBg)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.depBorder))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }

                if let blocker = scope.portBlockersHit.first {
                    Divider()
                    section("Port-blocker in scope") {
                        (Text(blocker.module).bold() + Text(" owns ") + Text(blocker.owns).font(.monoSmall)
                         + Text(". \(blocker.note)"))
                            .font(.system(size: 12)).foregroundStyle(Theme.warnText)
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.warnBg)
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.warnBorder))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Footer

    private var summaryBar: some View {
        let s = app.resolved
        return HStack(spacing: 16) {
            stat("\(s.selectedModelCount)", " of \(s.totalModelCount) models")
            dot
            stat("+\(s.autoIncludedDeps.count)", " dependencies")
            dot
            stat("~\(s.recordsEstimate.compact)", " records")
            dot
            stat("€\(s.costEUR.grouped)", " est.")
            Spacer()
            Text("Default is everything — your changes refine by exclusion")
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 18).padding(.vertical, 12)
        .background(.regularMaterial)
        .overlay(Divider(), alignment: .top)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        (Text(value).fontWeight(.bold) + Text(label).foregroundStyle(Theme.textSecondary))
            .font(.system(size: 12.5))
    }
    private var dot: some View { Text("·").foregroundStyle(Theme.checkOff) }
}
