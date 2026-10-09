import SwiftUI

/// Duolingo-style chapter list opened from the Parcours sticky banner:
/// a cross to go back, the theme's chapters as stacked cards (the current
/// one with the mascot and a speech bubble), then the theme switcher.
struct ChaptersMenuView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store

    let discipline: Discipline
    let currentLessonId: String?
    let onPick: (PathLesson) -> Void
    let onAdvance: (PathLesson) -> Void
    let onSelectDiscipline: (Discipline?) -> Void
    let onClose: () -> Void

    @State private var appeared: Bool = false

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var lessons: [PathLesson] { model.lessons(inDiscipline: discipline.id) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                            chapterCard(lesson, number: index + 1)
                                .id(lesson.id)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                                .animation(.spring(response: 0.45, dampingFraction: 0.85).delay(Double(min(index, 6)) * 0.04), value: appeared)
                        }
                        themeSwitcher
                            .padding(.top, 18)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    appeared = true
                    if let currentLessonId, lessons.first?.id != currentLessonId {
                        proxy.scrollTo(currentLessonId, anchor: .center)
                    }
                }
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    // MARK: - Header

    private var header: some View {
        ZStack {
            Text(discipline.name)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .padding(.horizontal, 60)
            HStack {
                Button {
                    Haptics.tap()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 48, height: 48)
                }
                .accessibilityLabel("Fermer")
                Spacer()
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1.5)
        }
    }

    // MARK: - Chapter card

    private func chapterCard(_ lesson: PathLesson, number: Int) -> some View {
        let counts = model.lessonRingCounts(lesson)
        let progress = counts.total > 0 ? Double(counts.done) / Double(counts.total) : 0
        let isUnlocked = model.isLessonUnlocked(lesson)
        let isCurrent = lesson.id == currentLessonId
        return Button {
            guard isUnlocked else {
                Haptics.error()
                return
            }
            Haptics.tap()
            onPick(lesson)
        } label: {
            VStack(spacing: 0) {
                if isCurrent {
                    currentHero(lesson, counts: counts)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chapitre \(number)")
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .tracking(0.4)
                                .foregroundStyle(isUnlocked ? discipline.color : Theme.inkMuted)
                            Text(lesson.title)
                                .font(.system(.title3, design: .rounded, weight: .heavy))
                                .foregroundStyle(isUnlocked ? Theme.ink : Theme.inkMuted)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 6)
                        ringsPill(count: counts.total, isUnlocked: isUnlocked)
                    }
                    if isUnlocked {
                        ProgressBar3D(progress: progress)
                    } else {
                        Button {
                            Haptics.tap()
                            onAdvance(lesson)
                        } label: {
                            Text("AVANCER ICI")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(Theme.link)
                                .frame(minHeight: 32)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(isCurrent ? Theme.background : Color.clear)
            }
            .background(Theme.card)
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 2))
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.line).offset(y: 4))
            .padding(.bottom, 4)
        }
        .buttonStyle(PressDownStyle())
    }

    private func ringsPill(count: Int, isUnlocked: Bool) -> some View {
        HStack(spacing: 5) {
            discipleIcon
            Text("\(count) épreuves")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .foregroundStyle(isUnlocked ? Theme.ink : Theme.inkMuted)
                .monospacedDigit()
            if !isUnlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.raised))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
    }

    private var discipleIcon: some View {
        RemoteThemeImage(urlString: discipline.imageUrl) {
            if let illustrated = discipline.illustratedIconName {
                Image(illustrated).resizable().scaledToFit()
            } else {
                Image(systemName: discipline.icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(discipline.color)
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 18, height: 18)
        .clipShape(Circle())
    }

    /// Speech bubble + peeking mascot, shown only on the chapter in progress.
    private func currentHero(_ lesson: PathLesson, counts: (done: Int, total: Int)) -> some View {
        let remaining = max(0, counts.total - counts.done)
        let line: String
        if counts.done == 0 {
            line = "On attaque « \(lesson.title) » ensemble ?"
        } else if remaining == 0 {
            line = "Chapitre bouclé, bravo !"
        } else {
            line = "Plus que \(remaining) épreuve\(remaining > 1 ? "s" : "") pour finir ce chapitre !"
        }
        return HStack(alignment: .bottom, spacing: 0) {
            SpeechBubble(text: line)
                .padding(.leading, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            Spacer(minLength: 0)
            Image("book_mascot_waving")
                .resizable()
                .scaledToFit()
                .frame(width: 112, height: 112)
                .offset(x: 10, y: 8)
                .accessibilityHidden(true)
        }
        .frame(minHeight: 130)
        .clipped()
    }

    // MARK: - Theme switcher

    private var themeSwitcher: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CHANGER DE THÈME")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.inkMuted)
            if !store.isPremium {
                Text("Avec Premium, choisis librement le thème de ton parcours.")
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            if store.isPremium && model.selectedDisciplineId != nil {
                Button {
                    Haptics.tap()
                    onSelectDiscipline(nil)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15, weight: .heavy))
                        Text("Parcours général (tous les thèmes)")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .heavy))
                    }
                    .foregroundStyle(Theme.link)
                    .padding(.horizontal, 16)
                    .frame(height: 54)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 2))
                }
                .buttonStyle(PressDownStyle())
            }
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(model.orderedDisciplines) { item in
                    let isActive = item.id == discipline.id
                    Button {
                        Haptics.tap()
                        onSelectDiscipline(item)
                    } label: {
                        ThemePillCard(discipline: item, isLocked: !store.isPremium && !isActive)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(isActive ? item.color : .clear, lineWidth: 2.5)
                            )
                    }
                    .buttonStyle(PressDownStyle())
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
        }
    }
}

/// Speech bubble with a small tail pointing toward the mascot.
private struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.body, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
            .overlay(alignment: .bottomTrailing) {
                Triangle()
                    .fill(Theme.background)
                    .frame(width: 18, height: 14)
                    .offset(x: -22, y: 13)
            }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Chunky green progress bar with a soft highlight stripe.
private struct ProgressBar3D: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.lockedFill)
                if progress > 0 {
                    Capsule()
                        .fill(Theme.success)
                        .frame(width: max(18, geo.size.width * progress))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 5)
                                .padding(.horizontal, 10)
                                .padding(.top, 4)
                        }
                }
            }
        }
        .frame(height: 18)
        .accessibilityLabel("Progression \(Int((progress * 100).rounded())) %")
    }
}

/// Sinks slightly while pressed, like the chunky cards of the reference.
struct PressDownStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// One pastel pill per theme: soft tinted background, name in the theme's own
/// deeper colour, illustrated badge on the right.
struct ThemePillCard: View {
    let discipline: Discipline
    var isLocked: Bool = false

    private var pastel: Color { Theme.pastel(discipline.color) }
    private var textColor: Color { Theme.pastelInk(discipline.color) }

    var body: some View {
        HStack(spacing: 8) {
            Text(discipline.name)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(textColor.opacity(0.7))
            }
            icon
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18).fill(pastel))
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }

    private var icon: some View {
        RemoteThemeImage(urlString: discipline.imageUrl) {
            if let illustratedIconName = discipline.illustratedIconName {
                Image(illustratedIconName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: discipline.icon)
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(textColor)
            }
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: 30, height: 30)
        .clipShape(Circle())
    }
}

extension String {
    /// Lowercase, accent-folded form used for simple case/accent-insensitive search.
    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
