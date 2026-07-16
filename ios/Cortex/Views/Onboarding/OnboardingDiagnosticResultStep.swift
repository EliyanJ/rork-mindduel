import SwiftUI

/// Final screen of the optional diagnostic: shows per-discipline tiers and
/// offers a personalized path or the full default path. Designed to be
/// screenshot-worthy for organic sharing.
struct OnboardingDiagnosticResultStep: View {
    let results: [DisciplineDiagnosticResult]
    let score: Int
    let total: Int
    let onStartWeakest: (DisciplineDiagnosticResult) -> Void
    let onViewFullPath: () -> Void

    @Environment(AppModel.self) private var model

    @State private var isReady = false
    @State private var showContinue = false

    private var sortedResults: [DisciplineDiagnosticResult] {
        results.sorted {
            if $0.correctCount == $1.correctCount {
                return $0.disciplineName < $1.disciplineName
            }
            return $0.correctCount < $1.correctCount
        }
    }

    private var weakest: DisciplineDiagnosticResult? {
        sortedResults.first
    }

    private var scoreSummary: String {
        "\(score)/\(total)"
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let titleSize: CGFloat = compact ? 26 : 32
            let scoreSize: CGFloat = compact ? 48 : 64

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: compact ? 16 : 22) {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Diagnostic")
                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.inkMuted)

                            Text(scoreSummary)
                                .font(.system(size: scoreSize, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .contentTransition(.numericText())

                            Text("Aperçu de ton niveau — 3 questions par discipline")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.inkMuted)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, compact ? 8 : 12)

                        Text("Points forts et lacunes")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.ink)

                        VStack(spacing: 12) {
                            ForEach(sortedResults) { result in
                                resultRow(result)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))

                        Text("Tendance seulement — ça reste un petit échantillon pour guider le parcours.")
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 4 : 8)
                    .padding(.bottom, 8)
                    .opacity(isReady ? 1 : 0)
                    .offset(y: isReady ? 0 : 12)
                }

                VStack(spacing: 10) {
                    if let weakest {
                        Button {
                            Haptics.success()
                            model.selectedDisciplineId = weakest.disciplineId
                            onStartWeakest(weakest)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Commencer par \(weakest.disciplineName)")
                            }
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.ink, textColor: Theme.gold))
                    }

                    Button("Voir mon parcours complet") {
                        Haptics.tap()
                        onViewFullPath()
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.vertical, 8)
                    .opacity(showContinue ? 1 : 0)
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 1)
                }
            )
            .task {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    isReady = true
                }
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showContinue = true
                }
            }
        }
    }

    private func resultRow(_ result: DisciplineDiagnosticResult) -> some View {
        let color = Color(hex: DiagnosticTier.allCases.first { $0 == result.tier }?.color ?? "#868E96")
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                if let discipline = model.discipline(withId: result.disciplineId) {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(discipline.color)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(discipline.color.opacity(0.12)))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.disciplineName)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(result.tier.label)
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(color)
                }
                Spacer()
                Text("\(result.correctCount)/\(result.totalCount)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line.opacity(0.6))
                    Capsule()
                        .fill(color)
                        .frame(width: max(4, geo.size.width * result.ratio))
                }
            }
            .frame(height: 8)
        }
    }
}

#Preview {
    OnboardingDiagnosticResultStep(
        results: [
            DisciplineDiagnosticResult(disciplineId: "hist", disciplineName: "Histoire", correctCount: 1, totalCount: 3, tier: .faible),
            DisciplineDiagnosticResult(disciplineId: "sci", disciplineName: "Sciences", correctCount: 2, totalCount: 3, tier: .moyen),
            DisciplineDiagnosticResult(disciplineId: "geo", disciplineName: "Géographie", correctCount: 3, totalCount: 3, tier: .solide),
        ],
        score: 6,
        total: 9,
        onStartWeakest: { _ in },
        onViewFullPath: {}
    )
}
