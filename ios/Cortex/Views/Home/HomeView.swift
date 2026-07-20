import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @State private var lessonLaunch: LessonLaunch?
    @State private var isMenuOpen: Bool = false
    @State private var lockedLessonPending: PathStage?
    @State private var isShopPresented: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                statsHeader
                ScrollView {
                    VStack(spacing: 28) {
                        dailyLessonCard
                        if model.selectedDiscipline?.chapters.contains(where: { $0.hasLevels }) == true {
                            ChapterBrowserView { items, disciplineId, chapterId, level in
                                startLevelLesson(items: items, disciplineId: disciplineId, chapterId: chapterId, level: level)
                            }
                        } else {
                            StagePathView { stage in
                                startLesson(stage)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 48)
                }
            }
            .background(Theme.background)

            if isMenuOpen {
                Button {
                    closeMenu()
                } label: {
                    Color.black.opacity(0.35)
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
                .transition(.opacity)
                .accessibilityLabel("Fermer le menu")

                ThemeMenuView {
                    closeMenu()
                }
                .transition(.move(edge: .leading))
            }
        }
        .fullScreenCover(item: $lessonLaunch) { launch in
            LessonView(launch: launch, store: model.store) { retryLaunch in
                handleLessonRetry(retryLaunch)
            }
        }
        .sheet(item: $lockedLessonPending) { stage in
            UnlockWithLivresView(kind: .lesson, progressStore: model.store) {
                startLesson(stage, bypassCheck: true)
            }
        }
        .sheet(isPresented: $isShopPresented) {
            LivresShopView(progressStore: model.store)
        }
    }

    private var statsHeader: some View {
        HStack(spacing: 8) {
            Button {
                Haptics.tap()
                withAnimation(.spring(duration: 0.32)) {
                    isMenuOpen = true
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choisir un parcours")

            if let discipline = model.selectedDiscipline {
                HStack(spacing: 6) {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(discipline.color)
                    Text(discipline.name)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
                .foregroundStyle(discipline.color)
            } else {
                Text("Minduel")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                StatPill(icon: "flame.fill", color: Theme.primary, value: "\(model.store.currentStreak)")
                StatPill(icon: "text.book.closed.fill", color: Theme.gold, value: "\(model.store.progress.xp)")
                Button {
                    Haptics.tap()
                    isShopPresented = true
                } label: {
                    StatPill(icon: "books.vertical.fill", color: Theme.livres, value: "\(model.store.livresBalance)")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dailyLessonCard: some View {
        let stage = model.nextStage
        let color = model.selectedDiscipline?.color ?? Theme.stageColor(stage?.index ?? 0)
        VStack(alignment: .leading, spacing: 12) {
            Label("LEÇON DU JOUR", systemImage: "sun.max.fill")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .opacity(0.9)
            Text(stage?.title ?? "Bientôt disponible")
                .font(.system(.title2, design: .rounded, weight: .heavy))
            Text("\(stage?.items.count ?? 0) questions · \(model.selectedDiscipline?.name ?? "thèmes variés") · environ 5 min")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .opacity(0.85)
            if let stage {
                themeRow(for: stage)
            }
            Button("Commencer") {
                if let stage {
                    startLesson(stage)
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, textColor: color))
            .padding(.top, 4)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [color, color.mix(with: .black, by: 0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func themeRow(for stage: PathStage) -> some View {
        HStack(spacing: 6) {
            ForEach(stage.disciplineIds.prefix(5), id: \.self) { id in
                if let discipline = model.discipline(withId: id) {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(0.22)))
                }
            }
            if stage.disciplineIds.count > 5 {
                Text("+\(stage.disciplineIds.count - 5)")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .opacity(0.85)
            }
        }
    }

    private func closeMenu() {
        withAnimation(.spring(duration: 0.32)) {
            isMenuOpen = false
        }
    }

    private func startLesson(_ stage: PathStage, bypassCheck: Bool = false) {
        if !bypassCheck, !model.store.canStartLesson(isPremium: store.isPremium) {
            Haptics.tap()
            lockedLessonPending = stage
            return
        }
        Haptics.medium()
        lessonLaunch = LessonLaunch(
            title: stage.title,
            chapterId: stage.id,
            items: stage.items
        )
    }

    private func startLevelLesson(items: [LessonItem], disciplineId: String, chapterId: String, level: DifficultyLevel) {
        if !model.store.canStartLesson(isPremium: store.isPremium) {
            Haptics.tap()
            lockedLessonPending = PathStage(
                id: "\(disciplineId)_\(chapterId)_\(level.rawValue)",
                index: 0,
                title: level.displayName,
                items: items,
                disciplineIds: [disciplineId]
            )
            return
        }
        Haptics.medium()
        let chapter = model.catalog.disciplines.first { $0.id == disciplineId }?
            .chapters.first { $0.id == chapterId }
        let title = "\(chapter?.title ?? "Chapitre") · \(level.displayName)"
        let freshItems = makeFreshLevelItems(
            disciplineId: disciplineId,
            chapterId: chapterId,
            level: level,
            proposedItems: items
        )
        lessonLaunch = LessonLaunch(
            title: title,
            chapterId: "\(disciplineId)_\(chapterId)_\(level.rawValue)",
            items: freshItems,
            disciplineId: disciplineId,
            level: level,
            chapterIdRaw: chapterId
        )
    }

    private func handleLessonRetry(_ retryLaunch: LessonLaunch) {
        guard let disciplineId = retryLaunch.disciplineId,
              let level = retryLaunch.level,
              let chapterIdRaw = retryLaunch.chapterIdRaw else { return }
        model.store.resetChapterLevelProgress(disciplineId: disciplineId, chapterId: chapterIdRaw, level: level)
        let freshItems = makeFreshLevelItems(
            disciplineId: disciplineId,
            chapterId: chapterIdRaw,
            level: level,
            proposedItems: retryLaunch.items
        )
        Haptics.success()
        lessonLaunch = LessonLaunch(
            title: retryLaunch.title,
            chapterId: retryLaunch.chapterId,
            items: freshItems,
            disciplineId: disciplineId,
            level: level,
            chapterIdRaw: chapterIdRaw
        )
    }

    private func makeFreshLevelItems(disciplineId: String, chapterId: String, level: DifficultyLevel, proposedItems: [LessonItem]) -> [LessonItem] {
        let allIds = proposedItems.map { $0.question.id }
        let poolIds = model.store.questionPoolForChapterLevel(
            disciplineId: disciplineId,
            chapterId: chapterId,
            level: level,
            allQuestionIds: allIds
        )
        let idSet = Set(poolIds)
        let fresh = proposedItems.filter { idSet.contains($0.question.id) }
        return fresh.isEmpty ? proposedItems : fresh
    }
}
