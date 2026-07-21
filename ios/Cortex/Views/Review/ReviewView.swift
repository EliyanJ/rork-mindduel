import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreViewModel.self) private var store
    @State private var lessonLaunch: LessonLaunch?
    @State private var isLockedPresented: Bool = false
    @State private var isShopPresented: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    dueCard
                    memorySection
                }
                .padding(16)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background)
        .fullScreenCover(item: $lessonLaunch) { launch in
            LessonView(launch: launch, store: model.store) { _ in }
        }
        .sheet(isPresented: $isLockedPresented) {
            UnlockWithLivresView(kind: .review, progressStore: model.store) {
                launchReview(bypassCheck: true)
            }
        }
        .sheet(isPresented: $isShopPresented) {
            LivresShopView(progressStore: model.store)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Révisions")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("La répétition espacée ancre ce que tu apprends")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Button {
                Haptics.tap()
                isShopPresented = true
            } label: {
                StatPill(icon: "diamond.fill", color: Theme.livres, value: "\(model.store.livresBalance)")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var dueCard: some View {
        let dueItems = model.dueLessonItems()
        VStack(alignment: .leading, spacing: 12) {
            if dueItems.isEmpty {
                HStack(spacing: 12) {
                    Text("🎉")
                        .font(.system(size: 40))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rien à réviser pour l'instant")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("Les notions apprises reviendront ici au bon moment. Continue tes leçons !")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Theme.gold)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(dueItems.count) notion\(dueItems.count > 1 ? "s" : "") risque\(dueItems.count > 1 ? "nt" : "") de s'estomper")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text("Révise maintenant pour les ancrer durablement.")
                            .font(.system(.subheadline, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                if !store.isPremium {
                    Text("\(min(dueItems.count, model.store.remainingFreeReviewCards(isPremium: false))) / \(dueItems.count) cartes disponibles aujourd'hui")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Button("Lancer la révision") {
                    launchReview()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    private func launchReview(bypassCheck: Bool = false) {
        let dueItems = model.dueLessonItems()
        guard !dueItems.isEmpty else { return }
        let remaining = model.store.remainingFreeReviewCards(isPremium: store.isPremium)
        if !bypassCheck, remaining <= 0 {
            Haptics.tap()
            isLockedPresented = true
            return
        }
        Haptics.medium()
        let capped = store.isPremium ? dueItems : Array(dueItems.prefix(remaining))
        let items = capped.shuffled()
        model.store.registerReviewCardsUsed(items.count)
        lessonLaunch = LessonLaunch(
            title: "Révision",
            chapterId: nil,
            items: items
        )
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mémorisation par thème")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            ForEach(model.catalog.disciplines) { discipline in
                memoryRow(discipline)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    private func memoryRow(_ discipline: Discipline) -> some View {
        let score = model.store.memorizationScore(disciplineId: discipline.id)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(discipline.name, systemImage: discipline.icon)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(discipline.color)
                Spacer()
                Text(score.map { "\(Int($0 * 100)) %" } ?? "—")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line.opacity(0.6))
                    if let score, score > 0 {
                        Capsule()
                            .fill(discipline.color)
                            .frame(width: max(10, geo.size.width * score))
                    }
                }
            }
            .frame(height: 10)
            if score == nil {
                Text("Commence une leçon pour construire ta mémoire")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }
}
