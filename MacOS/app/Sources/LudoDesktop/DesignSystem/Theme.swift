import SwiftUI

extension Color {
    /// 0xRRGGBB convenience.
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}

/// Visual tokens ported from the agreed HTML prototypes (`../prototypes`).
/// Light-first; system controls adapt to dark mode automatically.
enum Theme {
    static let accent       = Color(hex: 0x007AFF)
    static let success      = Color(hex: 0x34C759)
    static let running      = Color(hex: 0x007AFF)
    static let warn         = Color(hex: 0xD1620A)
    static let warnText     = Color(hex: 0x9A5511)
    static let warnBg       = Color(hex: 0xFFF7EF)
    static let warnBorder   = Color(hex: 0xFBE2C7)

    static let textPrimary  = Color(hex: 0x1D1D1F)
    static let textSecondary = Color(hex: 0x86868B)
    static let textTertiary = Color(hex: 0x9A9AA0)

    static let separator    = Color(hex: 0xE6E6EA)
    static let hairline     = Color(hex: 0xF2F2F4)
    static let sidebarBg    = Color(hex: 0xF5F5F7)
    static let rowSelected  = Color(hex: 0xEEF4FF)

    static let cardBg       = Color(hex: 0xFAFAFC)
    static let cardBorder   = Color(hex: 0xECECEF)

    static let depBg        = Color(hex: 0xEEF4FF)
    static let depBorder    = Color(hex: 0xD4E2FF)
    static let depText      = Color(hex: 0x0050D0)

    static let customTag    = Color(hex: 0x34A853)
    static let checkOff     = Color(hex: 0xC4C4C8)

    static let okPillBg     = Color(hex: 0xEAF6EC)
    static let okPillText   = Color(hex: 0x1C8A3A)
    static let badPillBg    = Color(hex: 0xFDECEC)
    static let badPillText  = Color(hex: 0xC0392B)
}

extension Font {
    static let mono = Font.system(.callout, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)
}
