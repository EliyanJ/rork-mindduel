import SwiftUI

/// Dedicated failure screen shown when a chapter level is completed but scored
/// under the 80% passing threshold. Offers a rewarded-ad retry (or free for
/// Premium) or the option to come back later after the cooldown.
struct LessonFailureView: View {
    let score: Int
    let maxScore: Int
    let requiredAccuracy: Double
    let wrongAnswers: [LessonSession.WrongAnswer]
    let isPremium: Bool
    let onRetry: () -> Void
    let onLater: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var expandedWrongAnswer: UUID?

    private var accuracy: Double {
        guard maxScore > 0 else { return 0 }
        return Double(score) / Double(maxScore)
    }

    private var isPassing: Bool { accuracy >= requiredAccuracy }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    heroSection

                    missedQuestionsSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }

            bottomSheet
        }
        .background(Theme.background)
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.danger.opacity(0.14))
                    .frame(width: 150, height: 150)
                Image("MascotRead")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .accessibilityHidden(true)
            }
            .scaleEffect(hasAppeared ? 1 : 0.3)

            VStack(spacing: 6) {
                Text("Pas encore réussi")
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)

                Text("Tu as obtenu \(score)/\(maxScore) — il faut au moins \(Int(requiredAccuracy * 100))% pour valider.")
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(hasAppeared ? 1 : 0)

            HStack(spacing: 12) {
                statCard(
                    title: "Score",
                    value: "\(Int(accuracy * 100))%",
                    icon: "target",
                    color: Theme.danger
                )
                statCard(
                    title: "Objectif",
                    value: "\(Int(requiredAccuracy * 100))%",
                    icon: "flag.checkered",
                    color: Theme.success
                )
                statCard(
                    title: "Ratées",
                    value: "\(wrongAnswers.count)",
                    icon: "xmark.circle",
                    color: Theme.danger
                )
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 24)
        }
        .frame(maxWidth: .infinity)
    }

    private var missedQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Questions à revoir")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)

            if wrongAnswers.isEmpty {
                Text("Aucune question ratée cette fois — la barre des \(Int(requiredAccuracy * 100))% est juste très haute.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(wrongAnswers) { wrong in
                        wrongAnswerRow(wrong)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func wrongAnswerRow(_ wrong: LessonSession.WrongAnswer) -> some View {
        let isExpanded = expandedWrongAnswer == wrong.id
        let question = wrong.question
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(.spring(duration: 0.25)) {
                    expandedWrongAnswer = isExpanded ? nil : wrong.id
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.danger)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.prompt)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(isExpanded ? nil : 2)

                        Text("Bonne réponse : \(question.answer)")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.success)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Explication", systemImage: "lightbulb.fill")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                    Text(question.explanation)
                        .font(.system(.footnote, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
    }

    private var bottomSheet: some View {
        VStack(spacing: 12) {
            VStack(spacing: 4) {
                Text(isPremium ? "Rejouer maintenant" : "Rejouer maintenant")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)

                Text(isPremium
                    ? "Premium : tu peux réessayer immédiatement."
                    : "Regarde une courte pub pour réessayer ce niveau tout de suite.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Haptics.success()
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isPremium ? "arrow.clockwise" : "play.rectangle.fill")
                    Text("Rejouer maintenant")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.danger))

            Button("Plus tard") {
                Haptics.tap()
                onLater()
            }
            .font(.system(.subheadline, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.inkMuted)
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .fill(Theme.card)
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                .stroke(Theme.line, lineWidth: 1.5)
                .ignoresSafeArea(edges: .bottom)
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
    LessonFailureView(
        score: 14,
        maxScore: 20,
        requiredAccuracy: 0.8,
        wrongAnswers: [
            LessonSession.WrongAnswer(
                question: Question(
                    id: "q1",
                    type: .multipleChoice,
                    prompt: "Quelle est la capitale de la France ?",
                    options: ["Lyon", "Marseille", "Paris", "Bordeaux"],
                    answer: "Paris",
                    explanation: "Paris est la capitale de la France depuis le Ve siècle.",
                    familiarity: .commun
                ),
                selectedAnswer: "Lyon",
                disciplineId: "geo"
            )
        ],
        isPremium: false,
        onRetry: {},
        onLater: {}
    )
}
