import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @State private var lessonLaunch: LessonLaunch?
    @State private var lockedRingPending: PathRing?
    @State private var cooldownRing: PathRing?
    @State private var isEnergyOutPresented = false
    @State private var isBoltsSheetPresented = false
    @State private var isMenuPresented = false
    @State private var isPathScrolledToBottom = false
    @State private var factIntro: FactIntro?
    /// A lesson the player picked from the menu to replay; nil tracks the
    /// current lesson of the journey.
    @State private var focusedLessonId: String?
    @State private var placementLesson: PathLesson?
    @State private var advanceChoiceLesson: PathLesson?
    @State private var isPaywallPresented = false

    /// Lesson currently on display: the menu pick when it still exists,
    /// otherwise the current lesson of whichever path is active — a single
    /// theme's own dedicated path when the player jumped in from the Thèmes
    /// tab, or the mixed general journey otherwise.
    private var visibleLesson: PathLesson? {
        if let themeId = model.selectedDisciplineId {
            if let focusedLessonId,
               let picked = model.lessons(inDiscipline: themeId).first(where: { $0.id == focusedLessonId }) {
                return picked
            }
            return model.currentLesson(inDiscipline: themeId)
        }
        if let focusedLessonId {
            guard let picked = model.lessons.first(where: { $0.id == focusedLessonId }) else {
                return model.currentLesson
            }
            return picked
        }
        return model.currentLesson
    }

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            if let lesson = visibleLesson {
                lessonBanner(lesson)
                lessonPath(lesson)
            } else {
                journeyDonePlaceholder
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .fullScreenCover(item: $lessonLaunch) { launch in
            LessonView(launch: launch, store: model.store) { retryLaunch in
                handleLessonRetry(retryLaunch)
            }
        }
        .fullScreenCover(item: $factIntro) { intro in
            FunFactIntroView(
                discipline: intro.discipline,
                cards: intro.cards,
                onStart: {
                    factIntro = nil
                    launchRing(intro.ring, items: intro.items)
                },
                onClose: { factIntro = nil }
            )
        }
        .sheet(item: $lockedRingPending) { ring in
            UnlockWithLivresView(kind: .lesson, progressStore: model.store) {
                startRing(ring, bypassCheck: true)
            }
        }
        .sheet(item: $cooldownRing) { ring in
            RecapCooldownSheet(
                ring: ring,
                unlockDate: model.store.ringLockedUntil(ring.id) ?? .now
            )
            .presentationDetents([.height(340)])
        }
        .sheet(isPresented: $isBoltsSheetPresented) {
            UnlockWithLivresView(kind: .lesson, progressStore: model.store) {}
        }
        .sheet(isPresented: $isEnergyOutPresented) {
            EnergyRefillView(progressStore: model.store, quitTitle: "Fermer") {
                isEnergyOutPresented = false
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(isPresented: $isMenuPresented) {
            if let lesson = visibleLesson,
               let discipline = model.discipline(withId: lesson.disciplineId) {
                ChaptersMenuView(
                    discipline: discipline,
                    currentLessonId: currentLessonId(inDiscipline: discipline.id),
                    onPick: { picked in
                        focusedLessonId = picked.id
                        isMenuPresented = false
                    },
                    onAdvance: { next in
                        isMenuPresented = false
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            requestAdvance(to: next)
                        }
                    },
                    onSelectDiscipline: { picked in
                        selectDiscipline(picked)
                    },
                    onClose: { isMenuPresented = false }
                )
            }
        }
        .fullScreenCover(item: $placementLesson) { next in
            PlacementTestView(
                lesson: next,
                items: model.placementItems(for: next),
                accent: model.discipline(withId: next.disciplineId)?.color ?? Theme.primary,
                onPassed: {
                    Haptics.success()
                    model.store.unlockChapterByTest(next.chapterId)
                },
                onClose: {
                    let passed = model.isLessonUnlocked(next)
                    placementLesson = nil
                    if passed { focusedLessonId = next.id }
                }
            )
        }
        .sheet(item: $advanceChoiceLesson) { next in
            AdvanceChoiceSheet(
                chapterTitle: next.title,
                onGoPremium: {
                    advanceChoiceLesson = nil
                    isPaywallPresented = true
                },
                onWatchVideo: {
                    advanceChoiceLesson = nil
                    Task {
                        try? await Task.sleep(for: .milliseconds(400))
                        placementLesson = next
                    }
                },
                onClose: { advanceChoiceLesson = nil }
            )
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallView(source: "advance_test")
        }
        .onChange(of: model.currentLesson?.id ?? "") { _, _ in
            // The journey moved on — stop showing an older, menu-picked lesson.
            focusedLessonId = nil
        }
        .onChange(of: model.isChaptersMenuRequested, initial: true) { _, isRequested in
            guard isRequested else { return }
            model.isChaptersMenuRequested = false
            if visibleLesson != nil { isMenuPresented = true }
        }
        .onChange(of: model.selectedDisciplineId) { _, _ in
            // Switched theme (or came back to the general journey) — always
            // start from that path's own current lesson.
            focusedLessonId = nil
        }
    }

    /// The "current lesson" id to highlight in the hamburger menu, scoped to
    /// whichever path is active.
    private func currentLessonId(inDiscipline disciplineId: String) -> String? {
        if let themeId = model.selectedDisciplineId, themeId == disciplineId {
            return model.currentLesson(inDiscipline: themeId)?.id
        }
        return model.currentLesson?.id
    }

    /// Premium players take the placement test straight away; free players
    /// first see the "finish your path or watch a video" choice.
    private func requestAdvance(to next: PathLesson) {
        if store.isPremium {
            placementLesson = next
        } else {
            advanceChoiceLesson = next
        }
    }

    /// Theme switcher of the chapters page: Premium switches the Parcours,
    /// free players (theme imposed) are shown the paywall.
    private func selectDiscipline(_ discipline: Discipline?) {
        let activeId = visibleLesson?.disciplineId
        if let discipline, discipline.id == activeId {
            isMenuPresented = false
            return
        }
        guard store.isPremium else {
            isMenuPresented = false
            Task {
                try? await Task.sleep(for: .milliseconds(450))
                isPaywallPresented = true
            }
            return
        }
        Analytics.capture("theme_switched", ["theme": discipline?.id ?? "journey"])
        model.selectedDisciplineId = discipline?.id
        isMenuPresented = false
    }

    // MARK: - Headers

    /// Duolingo-style top row: diamonds, lesson bolts, hearts and streak,
    /// evenly spread. Bolts and hearts open their refill sheet when tapped;
    /// Premium shows them as unlimited.
    private var statsHeader: some View {
        let isPremium = store.isPremium
        return HStack(spacing: 0) {
            HeaderStat(icon: "diamond.fill", color: Theme.livres, value: "\(model.store.livresBalance)", isEmpty: model.store.livresBalance == 0, label: "Diamants")
            Button {
                Haptics.tap()
                if !isPremium { isBoltsSheetPresented = true }
            } label: {
                let bolts = model.store.remainingFreeLessons()
                HeaderStat(icon: "bolt.fill", color: Theme.lessonBolt, value: isPremium ? "∞" : "\(bolts)", isEmpty: !isPremium && bolts == 0, label: "Éclairs de leçon")
            }
            .buttonStyle(.plain)
            Button {
                Haptics.tap()
                if !isPremium { isEnergyOutPresented = true }
            } label: {
                let hearts = model.store.energy
                HeaderStat(icon: "heart.fill", color: Theme.danger, value: isPremium ? "∞" : "\(hearts)", isEmpty: !isPremium && hearts == 0, label: "Cœurs")
            }
            .buttonStyle(.plain)
            HeaderStat(icon: "flame.fill", color: Theme.primary, value: "\(model.store.currentStreak)", isEmpty: model.store.currentStreak == 0, label: "Série")
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    /// The sticky chapter card: one colored block with the chapter and its
    /// title. Tapping anywhere opens the chapters page.
    private func lessonBanner(_ lesson: PathLesson) -> some View {
        let discipline = model.discipline(withId: lesson.disciplineId)
        let color = discipline?.color ?? Theme.primary
        let isReplaying = focusedLessonId != nil && visibleLesson?.id == focusedLessonId
        return Button {
            Haptics.tap()
            isMenuPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(isReplaying
                     ? "RELECTURE · CHAPITRE \(model.lessonIndex(lesson))"
                     : "\(discipline?.name.uppercased() ?? "") · CHAPITRE \(model.lessonIndex(lesson))")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Text(lesson.title)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(color))
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .overlay(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.22)))
                    .offset(y: 4)
            )
            .padding(.bottom, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle())
        .accessibilityHint("Ouvre la liste des chapitres et des thèmes")
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
        .background(Theme.background)
        .zIndex(1)
    }

    // MARK: - Path body

    private func lessonPath(_ lesson: PathLesson) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    Color.clear
                        .frame(height: 1)
                        .id("pathTop")
                    RingPathView(
                        rings: lesson.rings,
                        accent: model.discipline(withId: lesson.disciplineId)?.color ?? Theme.primary,
                        stateOf: { model.state(of: $0) },
                        lockOf: { model.lock(for: $0) },
                        recordOf: { model.store.ringRecord($0.id) }
                    ) { ring in
                        startRing(ring)
                    }
                    .padding(.horizontal, 16)
                    if let next = model.lesson(after: lesson) {
                        upNextBand(next) {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                proxy.scrollTo("pathTop", anchor: .top)
                            }
                        }
                        .padding(.top, 36)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("pathBottom")
                }
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y >= geometry.contentSize.height - geometry.containerSize.height - 40
            } action: { _, isAtBottom in
                isPathScrolledToBottom = isAtBottom
            }
            .overlay(alignment: .bottomTrailing) {
                if lesson.rings.count > 4 {
                    Button {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            if isPathScrolledToBottom {
                                proxy.scrollTo("pathTop", anchor: .top)
                            } else {
                                proxy.scrollTo("pathBottom", anchor: .bottom)
                            }
                        }
                    } label: {
                        Image(systemName: isPathScrolledToBottom ? "arrow.up" : "arrow.down")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .frame(width: 52, height: 52)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 16)
                    .padding(.bottom, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var journeyDonePlaceholder: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Parcours terminé — reviens bientôt pour de nouveaux chapitres.")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    /// Duolingo-style "À SUIVRE" band closing the path: next chapter, a
    /// short line, and "AVANCER ICI ?" to skip ahead with a placement test.
    private func upNextBand(_ next: PathLesson, onShow: @escaping () -> Void) -> some View {
        let isUnlocked = model.isLessonUnlocked(next)
        return VStack(spacing: 14) {
            Text("À SUIVRE")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Theme.line))
            HStack(spacing: 8) {
                if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .heavy))
                }
                Text(next.title)
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(isUnlocked ? Theme.ink : Theme.inkMuted)
            .padding(.horizontal, 24)
            Text(isUnlocked
                 ? "Ce chapitre est ouvert, lance-toi !"
                 : "Déjà calé sur le sujet ? Passe le test et saute directement à ce chapitre.")
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            Button(isUnlocked ? "Y ALLER" : "AVANCER ICI ?") {
                Haptics.tap()
                if isUnlocked {
                    focusedLessonId = next.id
                    onShow()
                } else {
                    requestAdvance(to: next)
                }
            }
            .buttonStyle(OutlineChunkyButtonStyle())
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .padding(.top, 26)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
        .background(Theme.raised)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1.5)
        }
    }

    // MARK: - Launching

    /// Launches a ring, after checking it isn't gated by the daily quota or by
    /// a failed recap's cool-down.
    private func startRing(_ ring: PathRing, bypassCheck: Bool = false) {
        if case .cooldown = model.lock(for: ring) {
            Haptics.error()
            cooldownRing = ring
            return
        }
        guard model.lock(for: ring) == nil else {
            Haptics.error()
            return
        }
        if !store.isPremium, model.store.energy <= 0 {
            Haptics.error()
            isEnergyOutPresented = true
            return
        }
        if !bypassCheck, !model.store.canStartLesson(isPremium: store.isPremium) {
            Haptics.tap()
            lockedRingPending = ring
            return
        }
        let items = model.playableItems(for: ring)
        guard !items.isEmpty else { return }
        guard let discipline = model.discipline(withId: ring.disciplineId) else {
            launchRing(ring, items: items)
            return
        }
        let lesson = model.chapterLesson(chapterId: ring.chapterId, disciplineId: ring.disciplineId)
        let cards = StudyGuide.cards(for: items.map(\.question), lesson: lesson)
        guard !cards.isEmpty else {
            launchRing(ring, items: items)
            return
        }
        Haptics.tap()
        factIntro = FactIntro(ring: ring, discipline: discipline, cards: cards, items: items)
    }

    /// Actually starts a ring's lesson, once past every gate (and past the
    /// revision sheet, if it was shown).
    private func launchRing(_ ring: PathRing, items: [LessonItem]) {
        Haptics.medium()
        lessonLaunch = LessonLaunch(
            title: ring.lessonTitle,
            chapterId: ring.id,
            items: items,
            disciplineId: ring.disciplineId,
            chapterIdRaw: ring.chapterId,
            ringKind: ring.kind
        )
    }

    /// Replays the same ring immediately. Only reachable for normal rings —
    /// a failed recap goes through the cool-down flow instead.
    private func handleLessonRetry(_ retryLaunch: LessonLaunch) {
        Haptics.success()
        lessonLaunch = LessonLaunch(
            title: retryLaunch.title,
            chapterId: retryLaunch.chapterId,
            items: retryLaunch.items,
            disciplineId: retryLaunch.disciplineId,
            chapterIdRaw: retryLaunch.chapterIdRaw,
            ringKind: retryLaunch.ringKind
        )
    }
}

/// Identifies the pre-quiz revision sheet for a given ring launch.
private struct FactIntro: Identifiable {
    var id: String { ring.id }
    let ring: PathRing
    let discipline: Discipline
    let cards: [StudyCard]
    let items: [LessonItem]
}

/// The app's wordmark: "Min" in ink, "duel" in the brand orange, set tight
/// together as a single logotype rather than a plain title label.
struct MinduelWordmark: View {
    var size: CGFloat = 22

    var body: some View {
        HStack(spacing: 0) {
            Text("Min")
                .foregroundStyle(Theme.ink)
            Text("duel")
                .foregroundStyle(Theme.primary)
        }
        .font(.system(size: size, weight: .heavy, design: .rounded))
        .lineLimit(1)
    }
}

/// One counter of the top row: colored icon and its number, no background.
private struct HeaderStat: View {
    let icon: String
    let color: Color
    let value: String
    let isEmpty: Bool
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(isEmpty ? Theme.inkMuted : color)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) : \(value)")
    }
}
