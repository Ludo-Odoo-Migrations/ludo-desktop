import SwiftUI

/// Demo driver: walks the same actions the on-screen CTAs trigger, so the flow
/// can be screen-recorded / screenshotted without UI-scripting permissions.
/// Inert unless launched with `LUDO_AUTOPILOT=1` or `--autopilot`.
@MainActor
final class Autopilot {
    let auth: AuthService
    let app: AppState
    let api: APIClient

    init(auth: AuthService, app: AppState, api: APIClient) {
        self.auth = auth; self.app = app; self.api = api
    }

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["LUDO_AUTOPILOT"] == "1"
            || CommandLine.arguments.contains("--autopilot")
    }

    private func pause(_ seconds: Double = 2.4) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    func run() async {
        await pause(1.2)                       // 1) Sign-in screen visible

        auth.mode = .mock
        auth.signIn()                          // CTA: "Sign in with GitHub" (mock) → Discovery
        await pause()                          // 2) Discovery

        app.step = .scope                      // CTA: "Configure migration scope →"
        app.inspectedModelID = "sale.order"
        await pause()                          // 3) Scope picker (default = everything)

        // CTA interactions: include a module, drop a custom field, deselect a model.
        app.toggleCategory("Website / CMS")
        app.toggleModel(categoryID: "Sales", modelID: "sale.report")
        if let m = app.inventory.categories.flatMap(\.models).first(where: { $0.id == "sale.order" }),
           let f = m.customFields.first(where: { $0.selected }) {
            app.toggleCustomField(modelID: "sale.order", fieldID: f.id)
        }
        await pause()                          // 4) Scope picker after edits

        app.step = .review                     // CTA: "Review →"
        await pause()                          // 5) Review & launch

        app.startMonitor(api: api)             // CTA: "Start migration ▸"
        app.step = .monitor
        await pause(12)                        // 6/7) Monitor animating → complete
    }
}
