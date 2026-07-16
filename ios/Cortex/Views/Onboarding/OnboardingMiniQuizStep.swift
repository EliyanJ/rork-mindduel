import SwiftUI

/// A short, guaranteed-easy playable quiz: the user actually experiences the
/// game (Duolingo-style) instead of just reading a promise. Immediate
/// right/wrong feedback per question plus a rising point counter.
struct OnboardingMiniQuizStep: View {
    let onFinished: (Int) -> Void

    private let questions = MiniQuizContent.questions

    @State private var index = 0
    @State private var score = 0
    @State private var displayedScore = 0
    @State private var selection: String?
    @State private var isRevealed = false

    private var question: Question { questions[index] }
    private var options: [String] { question.options ?? [] }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let promptSize: CGFloat = compact ? 20 : 24
            let rowSpacing: CGFloat = compact ? 8 : 10
            let topSpacing: CGFloat = compact ? 12 : 20

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Question \(index + 1)/\(questions.count)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(Theme.gold)
                        Text("\(displayedScore)")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Theme.gold.opacity(0.18)))
                }
                .padding(.top, 8)

                GeometryReader { progressGeo in
                    Capsule()
                        .fill(Theme.line.opacity(0.6))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Theme.primary)
                                .frame(width: progressGeo.size.width * CGFloat(index) / CGFloat(questions.count))
                                .animation(.easeOut(duration: 0.4), value: index)
                        }
                }
                .frame(height: 8)
                .padding(.top, 10)

                Spacer(minLength: topSpacing)

                Text(question.prompt)
                    .font(.system(size: promptSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .id("prompt-\(index)")
                    .transition(.opacity.combined(with: .move(edge: .trailing)))

                Spacer(minLength: topSpacing)

                VStack(spacing: rowSpacing) {
                    ForEach(options, id: \.self) { option in
                        ChoiceRowView(text: option, style: rowStyle(for: option)) {
                            guard !isRevealed else { return }
                            select(option)
                        }
                    }
                }
                .id("options-\(index)")

                Spacer(minLength: 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 2)
                }
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: index)
        }
    }

    private func rowStyle(for option: String) -> ChoiceRowView.Style {
        guard isRevealed else {
            return option == selection ? .selected : .normal
        }
        if option.comparisonKey == question.answer.comparisonKey { return .correct }
        if option == selection { return .wrong }
        return .dimmed
    }

    private func select(_ option: String) {
        Haptics.tap()
        selection = option
        isRevealed = true

        let isCorrect = option.comparisonKey == question.answer.comparisonKey
        if isCorrect {
            Haptics.success()
            score += 1
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                displayedScore = score
            }
        } else {
            Haptics.error()
        }

        Task {
            try? await Task.sleep(for: .milliseconds(750))
            if index < questions.count - 1 {
                index += 1
                selection = nil
                isRevealed = false
            } else {
                try? await Task.sleep(for: .milliseconds(150))
                onFinished(score)
            }
        }
    }
}

#Preview {
    OnboardingMiniQuizStep(onFinished: { _ in })
}
