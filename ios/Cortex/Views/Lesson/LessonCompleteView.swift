import SwiftUI

struct LessonCompleteView: View {
    let xp: Int
    let accuracy: Double
    let streak: Int
    let masteredCount: Int
    let toReinforceCount: Int
    let onDone: () -> Void
    /// Optional multi-session indicator, e.g. "Manche 1/2" or "Niveau validé".
    var sessionLabel: String? = nil
    /// True when this was session 1/2 and the level isn't evaluated yet.
    var needsAnotherSession: Bool = false
    /// True when this manche just validated the chapter level (>=80%).
    var levelJustValidated: Bool = false

    @State private var hasAppeared: Bool = false

    private var gaugeColor: Color {
        if accuracy >= 0.8 { return Theme.success }
        if accuracy >= 0.5 { return Theme.gold }
        return Theme.danger
    }

    private var headline: String {
        if accuracy == 1 { return "Bravo ! Connaissances maîtrisées" }
        if accuracy >= 0.8 { return "Bravo ! Très bon travail" }
        if accuracy >= 0.5 { return "Continue comme ça, ça rentre !" }
        return "Courage, tu progresses"
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Label("+\(xp) XP", systemImage: "bolt.fill")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.gold.mix(with: .black, by: 0.1))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.gold.opacity(0.14)))
                if streak > 0 {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.primary.opacity(0.12)))
                }
            }
            .opacity(hasAppeared ? 1 : 0)

            CircularPercentGauge(percent: accuracy, color: gaugeColor)
                .scaleEffect(hasAppeared ? 1 : 0.5)
                .opacity(hasAppeared ? 1 : 0)

            VStack(spacing: 6) {
                Text(headline)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Ta culture générale vient de progresser.")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .opacity(hasAppeared ? 1 : 0)

            if let sessionLabel {
                sessionBadge(label: sessionLabel, highlighted: levelJustValidated)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 16)
            }

            HStack(spacing: 12) {
                statCard(title: "Maîtrisés", value: "\(masteredCount)", icon: "checkmark.seal.fill", color: Theme.success)
                statCard(title: "À renforcer", value: "\(toReinforceCount)", icon: "arrow.triangle.2.circlepath", color: Theme.gold)
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 24)

            Spacer()
            VStack(spacing: 10) {
                if needsAnotherSession {
                    Text("Reviens demain pour la manche 2 et valider ce niveau.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                Button("Continuer", action: onDone)
                    .buttonStyle(ChunkyButtonStyle())
            }
        }
        .padding(20)
        .background(Theme.background)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    private func sessionBadge(label: String, highlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: highlighted ? "checkmark.seal.fill" : "flag.checkered.2.crossed")
                .font(.system(size: 13, weight: .bold))
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(highlighted ? Theme.success : Theme.primary)
        )
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
    }
}

#Preview {
    LessonCompleteView(
        xp: 30,
        accuracy: 1,
        streak: 4,
        masteredCount: 10,
        toReinforceCount: 0,
        onDone: {}
    )
}
