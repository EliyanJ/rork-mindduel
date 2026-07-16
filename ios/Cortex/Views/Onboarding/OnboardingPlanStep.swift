import SwiftUI

/// Final recap screen before entering the app: summarizes the answers into
/// a concrete "plan" card, then a last high-energy CTA.
struct OnboardingPlanStep: View {
    let goal: LearningGoal?
    let topics: [Discipline]
    let dailyGoal: Int
    let onFinish: () -> Void

    private let helpBubbles: [(icon: String, text: String)] = [
        ("bubble.left.fill", "Avoir des conversations plus riches"),
        ("brain.head.profile", "Muscler ta mémoire, un fait à la fois"),
        ("bolt.fill", "Défier tes amis dans des duels de culture G")
    ]

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let titleSize: CGFloat = compact ? 26 : 32
            let bubbleFont: CGFloat = compact ? 15 : 17

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 16 : 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Prêt(e) à booster")
                                .font(.system(size: titleSize, weight: .black, design: .rounded))
                            Text("ta culture sans effort ?")
                                .font(.system(size: titleSize, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Ton plan :")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)

                            HStack(spacing: 10) {
                                Image(systemName: "square.grid.2x2.fill")
                                    .foregroundStyle(Theme.inkMuted)
                                Text("\(topics.count) thématique\(topics.count > 1 ? "s" : "")")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                            }

                            HStack(spacing: 8) {
                                ForEach(topics.prefix(3)) { topic in
                                    Text(topic.name)
                                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(topic.color))
                                }
                            }

                            HStack(spacing: 10) {
                                Image(systemName: "target")
                                    .foregroundStyle(Theme.inkMuted)
                                Text("\(dailyGoal) nouvelle\(dailyGoal > 1 ? "s" : "") connaissance\(dailyGoal > 1 ? "s" : "") par jour")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Minduel t'aide à")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)

                            ForEach(helpBubbles, id: \.text) { bubble in
                                HStack(spacing: 14) {
                                    Image(systemName: bubble.icon)
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundStyle(Theme.primary)
                                        .frame(width: 36, height: 36)
                                        .background(Circle().fill(Theme.primary.opacity(0.12)))
                                    Text(bubble.text)
                                        .font(.system(size: bubbleFont, weight: .bold, design: .rounded))
                                        .foregroundStyle(Theme.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }

                Button("C'est parti") {
                    Haptics.success()
                    onFinish()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.ink, textColor: Theme.gold))
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 0)
                }
            )
        }
    }
}

#Preview {
    OnboardingPlanStep(goal: .learn, topics: [], dailyGoal: 3, onFinish: {})
}
