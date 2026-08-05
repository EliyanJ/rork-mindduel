import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @State private var lessonLaunch: LessonLaunch?
    @State private var lockedRingPending: PathRing?
    @State private var cooldownRing: PathRing?

    var body: some View {
        VStack(spacing: 0) {
            statsHeader
            ScrollView {
                VStack(spacing: 28) {
                    dailyLessonCard
                    RingPathView { ring in
                        startRing(ring)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 48)
            }
        }
        .background(Theme.background)
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
    }

    private var statsHeader: some View {
        HStack(spacing: 8) {
            if let discipline = model.selectedDiscipline {
                Button {
                    Haptics.tap()
                    model.selectedDisciplineId = nil
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: discipline.icon)
                            .font(.system(size: 14, weight: .bold))
                        Text(discipline.name)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(discipline.color))
                    .overlay(Capsule().stroke(Theme.ink, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Revenir au parcours mélangé")
            } else {
                Text("Minduel")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.primary)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                StatPill(icon: "bolt.fill", color: Theme.gold, value: "\(model.store.progress.xp)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dailyLessonCard: some View {
        let ring = model.nextRing
        let ringDiscipline = ring.flatMap { model.discipline(withId: $0.disciplineId) }
        let color = ring?.kind == .recap ? Theme.gold : (ringDiscipline?.color ?? Theme.primary)
        VStack(alignment: .leading, spacing: 12) {
            Label(ring?.kind == .recap ? "RÉCAP À DÉBLOQUER" : "LEÇON DU JOUR", systemImage: ring?.kind == .recap ? "crown.fill" : "sun.max.fill")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .opacity(0.9)
            Text(ring?.chapterTitle ?? "Bientôt disponible")
                .font(.system(.title2, design: .rounded, weight: .heavy))
            Text(dailyCardSubtitle(for: ring))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .opacity(0.85)
            if model.isMixedPath {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 12, weight: .bold))
                    Text("Parcours mélangé")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.22)))
            }
            Button("Commencer") {
                if let ring {
                    startRing(ring)
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, textColor: color))
            .padding(.top, 4)
            .disabled(ring == nil)
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

    private func dailyCardSubtitle(for ring: PathRing?) -> String {
        guard let ring else { return "Reviens bientôt pour de nouvelles questions" }
        let count = model.playableItems(for: ring).count
        let theme = model.discipline(withId: ring.disciplineId)?.name ?? ""
        if ring.kind == .recap {
            return "\(count) questions · tes erreurs + les plus dures"
        }
        return "\(ring.shortTitle) · \(count) questions · \(theme)"
    }

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

/// Explains why a failed recap is locked and points the player at revision.
private struct RecapCooldownSheet: View {
    let ring: PathRing
    let unlockDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.danger.opacity(0.12))
                    .frame(width: 92, height: 92)
                Image(systemName: "hourglass")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(Theme.danger)
            }
            .padding(.top, 12)

            VStack(spacing: 8) {
                Text("Récap verrouillé")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text("Le récap de « \(ring.chapterTitle) » se débloque \(unlockDate, style: .relative). Profites-en pour revoir tes erreurs dans l'onglet Révisions.")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("J'ai compris") {
                Haptics.tap()
                dismiss()
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }
}
