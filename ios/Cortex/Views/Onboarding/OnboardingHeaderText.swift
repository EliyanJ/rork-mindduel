import SwiftUI

/// Shared title block used by the middle onboarding steps: big rounded
/// title on the left, a floating emoji accent on the right.
struct OnboardingHeaderText: View {
    let title: String
    let emoji: String
    var subtitle: String?

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let titleSize: CGFloat = compact ? 28 : 34
            let emojiSize: CGFloat = compact ? 40 : 52
            let subtitlePadding: CGFloat = compact ? 8 : 10

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Text(title)
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                    Spacer(minLength: 4)
                    Text(emoji)
                        .font(.system(size: emojiSize))
                        .rotationEffect(.degrees(appeared ? -8 : -18))
                        .scaleEffect(appeared ? 1 : 0.6)
                }
                .padding(.top, 8)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.top, subtitlePadding)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 10)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                    appeared = true
                }
            }
        }
    }
}
