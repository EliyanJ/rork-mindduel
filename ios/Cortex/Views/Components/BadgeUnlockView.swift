import SwiftUI

/// Full-screen "new badge" moment after a lesson: the medal drops in on a
/// slowly turning sunburst tinted by its rarity, with a burst of sparkles.
struct BadgeUnlockView: View {
    let badge: Badge
    let condition: String
    let onContinue: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var isBurst: Bool = false

    private var tint: Color { badge.rarity.color }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 14) {
                Spacer(minLength: 20)
                Text("NOUVEAU BADGE")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .tracking(2)
                    .foregroundStyle(tint)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : -10)

                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        sparkle(index: index)
                    }
                    Image(badge.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .shadow(color: tint.opacity(0.45), radius: 24, y: 10)
                        .scaleEffect(hasAppeared ? 1 : 0.2)
                        .rotationEffect(.degrees(hasAppeared ? 0 : -25))
                }
                .frame(height: 300)

                Text(badge.rarity.label.uppercased())
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(tint))
                    .opacity(hasAppeared ? 1 : 0)
                Text(badge.name)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 24)
                    .opacity(hasAppeared ? 1 : 0)
                Text(condition)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .opacity(hasAppeared ? 1 : 0)
                Spacer()
                Button {
                    Haptics.tap()
                    onContinue()
                } label: {
                    Text("CONTINUER")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
            }
            .padding(20)
        }
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { hasAppeared = true }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.15)) { isBurst = true }
        }
    }

    private var background: some View {
        ZStack {
            Theme.background
            TimelineView(.animation) { context in
                let angle = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 40) / 40 * 360
                SunburstShape(rays: 16)
                    .fill(
                        RadialGradient(colors: [tint.opacity(0.28), tint.opacity(0)], center: .center, startRadius: 20, endRadius: 360)
                    )
                    .frame(width: 760, height: 760)
                    .rotationEffect(.degrees(angle))
            }
            .offset(y: -80)
            .opacity(hasAppeared ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func sparkle(index: Int) -> some View {
        let angle = Double(index) / 12 * 360 + 15
        let radius: CGFloat = index.isMultiple(of: 2) ? 150 : 128
        return Image(systemName: index.isMultiple(of: 3) ? "star.fill" : "sparkle")
            .font(.system(size: index.isMultiple(of: 2) ? 16 : 11, weight: .bold))
            .foregroundStyle(index.isMultiple(of: 2) ? Theme.gold : tint)
            .offset(
                x: isBurst ? cos(angle * .pi / 180) * radius : 0,
                y: isBurst ? sin(angle * .pi / 180) * radius : 0
            )
            .opacity(isBurst ? 0.9 : 0)
            .scaleEffect(isBurst ? 1 : 0.2)
    }
}

/// Alternating wedge rays radiating from the centre.
private struct SunburstShape: Shape {
    let rays: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(rays * 2)
        for index in 0..<rays {
            let start = Double(index * 2) * step
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: .radians(start), endAngle: .radians(start + step), clockwise: false)
            path.closeSubpath()
        }
        return path
    }
}
