import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @State private var lessonLaunch: LessonLaunch?
    @State private var lockedRingPending: PathRing?
    @State private var cooldownRing: PathRing?
    @State private var isEnergyOutPresented = false
    @State private var isMenuPresented = false
    /// A lesson the player picked from the menu to replay; nil tracks the
    /// current lesson of the journey.
    @State private var focusedLessonId: String?

    /// Lesson currently on display: the menu pick when it still exists,
    /// otherwise the journey's next lesson.
    private var visibleLesson: PathLesson? {
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
        .sheet(isPresented: $isEnergyOutPresented) {
            EnergyRefillView(progressStore: model.store, quitTitle: "Fermer") {
                isEnergyOutPresented = false
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isMenuPresented) {
            if let lesson = visibleLesson,
               let discipline = model.discipline(withId: lesson.disciplineId) {
                LessonsMenuView(
                    discipline: discipline,
                    lessons: model.lessons(inDiscipline: discipline.id),
                    currentLessonId: model.currentLesson?.id,
                    focusedLessonId: focusedLessonId
                ) { picked in
                    focusedLessonId = picked.id
                    isMenuPresented = false
                }
                .presentationDetents([.medium])
            }
        }
        .onChange(of: model.currentLesson?.id ?? "") { _, _ in
            // The journey moved on — stop showing an older, menu-picked lesson.
            focusedLessonId = nil
        }
    }

    // MARK: - Headers

    private var statsHeader: some View {
        HStack(spacing: 8) {
            MinduelWordmark()
            Spacer()
            HStack(spacing: 6) {
                StatPill(icon: "diamond.fill", color: Theme.livres, value: "\(model.store.livresBalance)")
                StatPill(icon: "heart.fill", color: Theme.danger, value: "\(model.store.energy)")
                StatPill(icon: "flame.fill", color: Theme.primary, value: "\(model.store.currentStreak)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    /// The sticky band that stays on top of the scroll: current theme and
    /// chapter, its completion percentage, and the hamburger that lists every
    /// sub-theme of this theme.
    private func lessonBanner(_ lesson: PathLesson) -> some View {
        let discipline = model.discipline(withId: lesson.disciplineId)
        let color = discipline?.color ?? Theme.primary
        let counts = model.lessonRingCounts(lesson)
        let progress = counts.total > 0 ? Double(counts.done) / Double(counts.total) : 0
        let isReplaying = focusedLessonId != nil && visibleLesson?.id == focusedLessonId
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(discipline?.name.uppercased() ?? "") · CHAPITRE \(model.lessonIndex(lesson))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(color)
                HStack(spacing: 6) {
                    Text(lesson.title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    if isReplaying {
                        Text("RELECTURE")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(Theme.inkMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Theme.lockedFill.opacity(0.6)))
                    }
                }
            }
            Spacer(minLength: 6)
            CircularProgressGauge(progress: progress, color: color)
            Button {
                Haptics.tap()
                isMenuPresented = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 46, height: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1)
        }
    }

    // MARK: - Path body

    private func lessonPath(_ lesson: PathLesson) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 8) {
                    Text("\(lesson.title) · \(lesson.rings.count) épreuves")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 6)

                    RingPathView(
                        rings: lesson.rings,
                        accent: model.discipline(withId: lesson.disciplineId)?.color ?? Theme.primary,
                        stateOf: { model.state(of: $0) },
                        lockOf: { model.lock(for: $0) },
                        recordOf: { model.store.ringRecord($0.id) }
                    ) { ring in
                        startRing(ring)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("pathBottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 110)
                .background(alignment: .top) {
                    GeometryReader { geometry in
                        AlternatingBackgroundPattern(
                            width: geometry.size.width,
                            tileCount: backgroundTileCount(width: geometry.size.width, ringCount: lesson.rings.count)
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .overlay(alignment: .bottomTrailing) {
                if lesson.rings.count > 4 {
                    Button {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.35)) {
                            proxy.scrollTo("pathBottom", anchor: .bottom)
                        }
                    } label: {
                        Image(systemName: "arrow.down")
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

    /// Estimates how many stacked background tiles are needed for one lesson's
    /// path, from its ring count rather than from a live-measured height — the
    /// lazy stack would otherwise grow the background as it mounts.
    private func backgroundTileCount(width: CGFloat, ringCount: Int) -> Int {
        let tileAspectRatio: CGFloat = 887.0 / 1774.0
        let tileHeight = width / tileAspectRatio
        guard tileHeight > 0 else { return 1 }
        let perRingPitch: CGFloat = 170
        let headerAllowance: CGFloat = 220
        let estimatedContentHeight = CGFloat(ringCount) * perRingPitch + headerAllowance
        let minHeight = max(estimatedContentHeight, UIScreen.main.bounds.height * 1.2)
        return max(1, Int((minHeight / tileHeight).rounded(.up)))
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
        if model.store.energy <= 0 {
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

/// Everything bundled inside one theme that unlocks from the hamburger: the
/// sub-themes of this discipline, with progress and lock state on each row.
private struct LessonsMenuView: View {
    @Environment(AppModel.self) private var model
    let discipline: Discipline
    let lessons: [PathLesson]
    let currentLessonId: String?
    let focusedLessonId: String?
    let onPick: (PathLesson) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(discipline.name)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text("Toutes les leçons de ce thème")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 14)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(lessons) { lesson in
                        row(for: lesson)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(Theme.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func row(for lesson: PathLesson) -> some View {
        let color = discipline.color
        let counts = model.lessonRingCounts(lesson)
        let done = model.isLessonDone(lesson)
        let unlocked = model.isLessonUnlocked(lesson)
        let isCurrent = lesson.id == currentLessonId
        let isFocused = lesson.id == focusedLessonId

        Button {
            guard unlocked else {
                Haptics.error()
                return
            }
            Haptics.tap()
            onPick(lesson)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(done ? color : (unlocked ? color.opacity(0.14) : Theme.lockedFill.opacity(0.7)))
                        .frame(width: 40, height: 40)
                    Image(systemName: done ? "checkmark" : (unlocked ? "play.fill" : "lock.fill"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(done ? .white : (unlocked ? color : Theme.inkMuted))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(unlocked ? Theme.ink : Theme.inkMuted)
                        .lineLimit(2)
                    Text("\(counts.done)/\(counts.total) épreuves")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 6)
                if isCurrent {
                    Text("EN COURS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color))
                } else {
                    Image(systemName: isFocused ? "eye.fill" : "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isFocused ? color : Theme.line, lineWidth: isFocused ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
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

/// Small progress donut used in the sticky lesson banner.
private struct CircularProgressGauge: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((progress * 100).rounded()))%")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: 46, height: 46)
    }
}

/// Stacks the two decorative background illustrations one after another,
/// alternating down the whole scrollable path so it never abruptly stops
/// even on long lessons.
private struct AlternatingBackgroundPattern: View {
    let width: CGFloat
    let tileCount: Int

    private static let tileNames = ["BackgroundPatternIcons", "BackgroundPatternMascots"]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<tileCount, id: \.self) { index in
                Image(Self.tileNames[index % Self.tileNames.count])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width)
            }
        }
        .opacity(0.32)
        .allowsHitTesting(false)
        .fixedSize(horizontal: false, vertical: true)
    }
}
