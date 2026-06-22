import Foundation

/// The "Acme GmbH · Odoo 15 → 18" fixture from the prototypes.
enum MockData {
    static let customerName = "Acme GmbH"
    static let versionPair  = "Odoo 15.0 Enterprise → 18.0 Enterprise"

    static let dependencies: [Dependency] = [
        .init(model: "res.partner",  reason: "referenced by partner_id"),
        .init(model: "res.currency", reason: "pricing"),
        .init(model: "res.company",  reason: "ownership"),
    ]

    static let portBlockers: [PortBlocker] = [
        .init(module: "x_acme_logistics",
              owns: "sale.order.x_delivery_route",
              note: "Custom module — must be ported to v18 before this field migrates. Flagged for the engineer."),
    ]

    static let inventory: Inventory = {
        let sales = ModuleCategory(name: "Sales", symbol: "dollarsign.circle", moduleCount: 14, models: [
            ModelInfo(name: "sale.order", label: "Sales Order", records: 38_402, fieldCount: 96, customFields: [
                CustomField(name: "x_delivery_route"),
                CustomField(name: "x_priority_flag"),
                CustomField(name: "x_legacy_ref", selected: false),
                CustomField(name: "x_studio_margin"),
            ]),
            ModelInfo(name: "sale.order.line", label: "Order Line", records: 412_118, fieldCount: 71),
            ModelInfo(name: "sale.order.template", label: "Quotation Template", records: 142, fieldCount: 22),
            ModelInfo(name: "sale.report", label: "Sales Analysis", records: nil, fieldCount: 34),
            ModelInfo(name: "product.product", label: "Product Variant", records: 8_940, fieldCount: 88),
            ModelInfo(name: "product.template", label: "Product", records: 6_120, fieldCount: 102),
            ModelInfo(name: "product.pricelist", label: "Pricelist", records: 38, fieldCount: 19),
        ])

        let accounting = ModuleCategory(name: "Accounting", symbol: "eurosign.circle", moduleCount: 31, models: [
            ModelInfo(name: "account.move", label: "Journal Entry", records: 220_000, fieldCount: 140),
            ModelInfo(name: "account.move.line", label: "Journal Item", records: 1_200_000, fieldCount: 90),
            ModelInfo(name: "account.payment", label: "Payment", records: 45_000, fieldCount: 60),
            ModelInfo(name: "account.journal", label: "Journal", records: 40, fieldCount: 55),
        ])

        let inventoryCat = ModuleCategory(name: "Inventory", symbol: "shippingbox", moduleCount: 22, models: [
            ModelInfo(name: "stock.move", label: "Stock Move", records: 310_000, fieldCount: 80),
            ModelInfo(name: "stock.quant", label: "Quant", records: 95_000, fieldCount: 45),
            ModelInfo(name: "stock.picking", label: "Transfer", records: 60_000, fieldCount: 120),
        ])

        let crm = ModuleCategory(name: "CRM", symbol: "phone", moduleCount: 9, models: [
            ModelInfo(name: "crm.lead", label: "Lead/Opportunity", records: 38_000, fieldCount: 110),
            ModelInfo(name: "crm.stage", label: "Stage", records: 8, fieldCount: 20),
        ])

        // HR is intentionally MIXED (one model deselected) to show tri-state.
        let hr = ModuleCategory(name: "HR", symbol: "person.2", moduleCount: 18, models: [
            ModelInfo(name: "hr.employee", label: "Employee", records: 420, fieldCount: 150),
            ModelInfo(name: "hr.department", label: "Department", records: 24, fieldCount: 18, selected: false),
        ])

        let l10n = ModuleCategory(name: "Localization (DE)", symbol: "flag", moduleCount: 7, models: [
            ModelInfo(name: "account.fiscal.position", label: "Fiscal Position", records: 30, fieldCount: 25),
        ])

        // Website is intentionally OFF (default-excluded in the prototype).
        let website = ModuleCategory(name: "Website / CMS", symbol: "globe", moduleCount: 12, models: [
            ModelInfo(name: "website.page", label: "Page", records: 120, fieldCount: 40, selected: false),
        ])

        // Custom/Studio is MIXED.
        let custom = ModuleCategory(name: "Custom / Studio", symbol: "star", moduleCount: 6, models: [
            ModelInfo(name: "x_acme.delivery.route", label: "Delivery Route", records: 1_200, fieldCount: 15),
            ModelInfo(name: "x_acme.config", label: "Acme Config", records: 5, fieldCount: 8, selected: false),
        ])

        // System is OFF by default (never data-migratable).
        let system = ModuleCategory(name: "System", symbol: "gearshape", moduleCount: 39, models: [
            ModelInfo(name: "ir.ui.view", label: "View", records: 9_400, fieldCount: 30, selected: false),
            ModelInfo(name: "ir.model.data", label: "External ID", records: 120_000, fieldCount: 12, selected: false),
        ])

        return Inventory(
            categories: [sales, accounting, inventoryCat, crm, hr, l10n, website, custom, system],
            totalModules: 158
        )
    }()

    // MARK: Monitor fixtures

    static let progress: [ModelProgress] = [
        .init(name: "res.partner",       status: .done,    done: 62_140,  total: 62_140),
        .init(name: "product.template",  status: .done,    done: 6_120,   total: 6_120),
        .init(name: "sale.order",        status: .done,    done: 38_402,  total: 38_402),
        .init(name: "sale.order.line",   status: .done,    done: 412_118, total: 412_118),
        .init(name: "account.move.line", status: .running, done: 142_000, total: 410_000),
        .init(name: "account.payment",   status: .queued,  done: 0,       total: 45_000),
        .init(name: "stock.move",        status: .queued,  done: 0,       total: 310_000),
        .init(name: "stock.quant",       status: .queued,  done: 0,       total: 95_000),
    ]

    static let eventScript: [MigrationEventItem] = [
        .init(time: "11:42:03", kind: .event, text: "session_started s_9f3a21"),
        .init(time: "11:42:09", kind: .info,  text: "blueprint_generated · 138 models"),
        .init(time: "11:43:50", kind: .ok,    text: "model_completed res.partner ✓"),
        .init(time: "11:51:12", kind: .ok,    text: "model_completed sale.order ✓"),
        .init(time: "12:18:44", kind: .event, text: "job_started load account.move.line"),
        .init(time: "12:31:02", kind: .event, text: "turn_started Cortex — unmapped field"),
        .init(time: "12:31:48", kind: .ok,    text: "turn_completed applied rename → ref"),
        .init(time: "12:33:10", kind: .info,  text: "per-batch verify ✓ (140 / 410)"),
        .init(time: "12:33:30", kind: .warn,  text: "safety_event none · 0 drift"),
        .init(time: "13:40:00", kind: .ok,    text: "session_end outcome=migrated ✓"),
    ]
}
