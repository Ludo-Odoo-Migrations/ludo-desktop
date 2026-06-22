import SwiftUI

enum CheckState { case on, off, mixed }

/// Tri-state checkbox matching the prototype (accent fill + check / minus).
struct Checkbox: View {
    var state: CheckState

    var body: some View {
        let filled = state != .off
        RoundedRectangle(cornerRadius: 4)
            .fill(filled ? Theme.accent : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(filled ? Theme.accent : Theme.checkOff, lineWidth: 1.6)
            )
            .frame(width: 16, height: 16)
            .overlay {
                switch state {
                case .on:    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                case .mixed: Image(systemName: "minus").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                case .off:   EmptyView()
                }
            }
            .accessibilityAddTraits(filled ? [.isSelected] : [])
    }
}

/// Small status / count pill.
struct Pill: View {
    var text: String
    var bg: Color
    var fg: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(bg, in: Capsule())
            .foregroundStyle(fg)
    }
}

/// Bordered card container with an optional header.
struct Card<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.cardBg)
                Divider()
            }
            content
        }
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Key/value row used inside cards.
struct KVRow<Trailing: View>: View {
    var label: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack {
            Text(label).font(.system(size: 13.5))
            Spacer()
            trailing
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

extension Int {
    /// 1234567 -> "1,234,567"
    var grouped: String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    /// 2410000 -> "2.41M"
    var compact: String {
        if self >= 1_000_000 { return String(format: "%.2fM", Double(self) / 1_000_000) }
        if self >= 1_000 { return String(format: "%.0fK", Double(self) / 1_000) }
        return "\(self)"
    }
}
