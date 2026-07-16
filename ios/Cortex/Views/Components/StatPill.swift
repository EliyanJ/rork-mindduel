import SwiftUI

struct StatPill: View {
    let icon: String
    let color: Color
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1.5))
    }
}
