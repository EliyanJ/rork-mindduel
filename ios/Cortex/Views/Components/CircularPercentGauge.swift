import SwiftUI

/// Circular progress ring showing an accuracy percentage, styled after a
/// results screen: big centered number, thin muted track, animated fill.
struct CircularPercentGauge: View {
    let percent: Double // 0...1
    var color: Color = Theme.success
    var size: CGFloat = 190
    var lineWidth: CGFloat = 20
    var caption: String = "Taux de réussite"

    @State private var animatedPercent: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedPercent)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int((animatedPercent * 100).rounded())) %")
                    .font(.system(size: size * 0.23, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(caption)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.15)) {
                animatedPercent = percent
            }
        }
    }
}

#Preview {
    CircularPercentGauge(percent: 0.85)
        .padding(40)
        .background(Theme.background)
}
