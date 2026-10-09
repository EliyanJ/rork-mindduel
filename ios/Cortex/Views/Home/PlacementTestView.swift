import SwiftUI

/// "Avancer ici ?" placement test: ~15 hard questions from the next chapter.
/// At least 80 % right unlocks that chapter straight away.
struct PlacementTestView: View {
    let lesson: PathLesson
    let items: [LessonItem]
    let accent: Color
    let onPassed: () -> Void
    let onClose: () -> Void

    private enum Phase { case intro, playing, result }

    @State private var phase: Phase = .intro
    @State private var index: Int = 0
    @State private var options: [String] = []
    @State private var selection: String?
    @State private var isChecked: Bool = false
    @State private var correctCount: Int = 0

    private var current: LessonItem? { items.indices.contains(index) ? items[index] : nil }
    private var score: Double { items.isEmpty ? 0 : Double(correctCount) / Double(items.count) }
    private var hasPassed: Bool { score >= ProgressStore.placementPassScore }
    private var requiredCount: Int { Int((Double(items.count) * ProgressStore.placementPassScore).rounded(.up)) }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch phase {
            case .intro: intro
            case .playing: playing
            case .result: result
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: phase)
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(spacing: 18) {
            closeBar
            Spacer()
            Image("book_mascot_reading")
                .resizable()
                .scaledToFit()
                .frame(height: 180)
                .accessibilityHidden(true)
            Text("Test de passage")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("\(items.count) questions difficiles sur « \(lesson.title) ». Il te faut au moins \(requiredCount) bonnes réponses (80 %) pour débloquer ce chapitre.")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            HStack(spacing: 10) {
                infoChip(icon: "bolt.fill", text: "Très dur", color: Theme.danger)
                infoChip(icon: "heart.fill", text: "Sans cœurs", color: Theme.primary)
            }
            Spacer()
            Button("COMMENCER") {
                Haptics.medium()
                startPlaying()
            }
            .buttonStyle(ChunkyButtonStyle(color: accent))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func infoChip(icon: String, text: String, color: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Playing

    private var playing: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    Haptics.tap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Quitter le test")
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.lockedFill)
                        Capsule()
                            .fill(accent)
                            .frame(width: max(14, geo.size.width * Double(index) / Double(max(1, items.count))))
                    }
                }
                .frame(height: 16)
                Text("\(index + 1)/\(items.count)")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                if let current {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(current.question.prompt)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                ChoiceRowView(text: option, style: style(for: option, item: current)) {
                                    guard !isChecked else { return }
                                    Haptics.tap()
                                    selection = option
                                }
                            }
                        }
                    }
                    .padding(20)
                    .id(current.id)
                }
            }

            Button(isChecked ? "CONTINUER" : "VÉRIFIER") {
                isChecked ? next() : check()
            }
            .buttonStyle(ChunkyButtonStyle(color: selection == nil ? Theme.lockedFill : accent, textColor: selection == nil ? Theme.inkMuted : .white))
            .disabled(selection == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func style(for option: String, item: LessonItem) -> ChoiceRowView.Style {
        guard isChecked else { return option == selection ? .selected : .normal }
        if isAnswer(option, for: item) { return .correct }
        if option == selection { return .wrong }
        return .dimmed
    }

    private func isAnswer(_ option: String, for item: LessonItem) -> Bool {
        option.normalizedForSearch.trimmingCharacters(in: .whitespaces)
            == item.question.answer.normalizedForSearch.trimmingCharacters(in: .whitespaces)
    }

    private func loadOptions() {
        guard let current else { return }
        switch current.question.type {
        case .trueFalse: options = ["Vrai", "Faux"]
        default: options = (current.question.options ?? []).shuffled()
        }
        selection = nil
        isChecked = false
    }

    private func startPlaying() {
        index = 0
        correctCount = 0
        loadOptions()
        phase = .playing
    }

    private func check() {
        guard let current, let selection else { return }
        isChecked = true
        if isAnswer(selection, for: current) {
            correctCount += 1
            Haptics.success()
        } else {
            Haptics.error()
        }
    }

    private func next() {
        Haptics.tap()
        if index + 1 >= items.count {
            Analytics.capture("placement_test_finished", ["passed": hasPassed, "score": Int(score * 100)])
            if hasPassed { onPassed() }
            phase = .result
        } else {
            index += 1
            loadOptions()
        }
    }

    // MARK: - Result

    private var result: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(hasPassed ? "MascotCelebrate" : "book_mascot_sitting")
                .resizable()
                .scaledToFit()
                .frame(height: 190)
                .accessibilityHidden(true)
            Text(hasPassed ? "Chapitre débloqué !" : "Pas encore…")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("\(correctCount)/\(items.count) bonnes réponses")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(hasPassed ? Theme.success : Theme.danger)
            Text(hasPassed
                 ? "Bravo, tu peux attaquer « \(lesson.title) » directement."
                 : "Il fallait \(requiredCount) bonnes réponses. Continue ton parcours actuel : tu seras vite prêt !")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            Button(hasPassed ? "C'EST PARTI" : "RETOUR AU PARCOURS") {
                Haptics.tap()
                onClose()
            }
            .buttonStyle(ChunkyButtonStyle(color: hasPassed ? Theme.success : accent))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private var closeBar: some View {
        HStack {
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer")
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
}

/// Sheet shown to free players tapping "AVANCER ICI ?": finish the current
/// path first, or watch a video to try the test anyway.
struct AdvanceChoiceSheet: View {
    let chapterTitle: String
    let onGoPremium: () -> Void
    let onWatchVideo: () -> Void
    let onClose: () -> Void

    @State private var isLoadingAd: Bool = false
    @State private var adError: String?

    var body: some View {
        VStack(spacing: 14) {
            Image("book_mascot_peeking_cloud")
                .resizable()
                .scaledToFit()
                .frame(height: 110)
                .padding(.top, 22)
                .accessibilityHidden(true)
            Text("Envie d'avancer ?")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Termine d'abord ton parcours actuel pour débloquer « \(chapterTitle) ». Tu peux aussi tenter le test de passage maintenant : il faut 80 % de bonnes réponses.")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            if let adError {
                Text(adError)
                    .font(.system(.footnote, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.danger)
            }
            VStack(spacing: 12) {
                Button("CONTINUER MON PARCOURS") {
                    Haptics.tap()
                    onClose()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                Button {
                    watchVideo()
                } label: {
                    HStack(spacing: 8) {
                        if isLoadingAd {
                            ProgressView().tint(Theme.link)
                        } else {
                            Image(systemName: "play.rectangle.fill")
                        }
                        Text("PASSER LE TEST QUAND MÊME")
                    }
                }
                .buttonStyle(OutlineChunkyButtonStyle())
                .disabled(isLoadingAd)
                Button("Tester sans pub avec Premium") {
                    Haptics.tap()
                    onGoPremium()
                }
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .background(Theme.background)
    }

    private func watchVideo() {
        Haptics.tap()
        adError = nil
        isLoadingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isLoadingAd = false
            if rewarded {
                Analytics.capture("placement_test_ad_watched")
                onWatchVideo()
            } else {
                adError = AdsManager.shared.lastError ?? "Vidéo indisponible, réessaie dans un instant."
            }
        }
    }
}

/// Outline variant of the chunky button: card face, grey edge, blue label.
struct OutlineChunkyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(Theme.link)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 2))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.line)
                    .offset(y: 4)
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
