import SwiftUI

/// Shop sections the header counters can jump straight to.
enum ShopSection: String, Hashable {
    case hearts
    case lessonBolts
}

/// "Boutique": everything diamonds can buy, opened from the diamond counter
/// (or from the bolts / hearts counters, scrolled to their section).
struct ShopView: View {
    let progressStore: ProgressStore
    /// Section to scroll to when the shop opens; nil shows the top.
    var initialSection: ShopSection? = nil
    /// Called after the shop closes itself to go to the Missions tab.
    let onOpenMissions: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreViewModel.self) private var store
    @State private var missingCost: MissingCost?
    @State private var isWatchingAd: Bool = false
    @State private var toast: String?
    @State private var toastTask: Task<Void, Never>?
    @State private var highlighted: ShopSection?

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        balanceHeader
                        section("SÉRIE") { streakRows }
                        section("CŒURS", id: .hearts) {
                            heartsExplainer
                        } content: { heartRows }
                        section("ÉCLAIRS DE LEÇON", id: .lessonBolts) {
                            boltsExplainer
                        } content: { lessonRow }
                        section("GAGNER DES DIAMANTS") { earnRows }
                        Label("Les éclairs de duel se rechargent uniquement avec une vidéo, depuis l'onglet Duel.", systemImage: "info.circle")
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .task {
                    guard let initialSection else { return }
                    try? await Task.sleep(for: .milliseconds(250))
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        proxy.scrollTo(initialSection, anchor: .top)
                    }
                    highlighted = initialSection
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.easeOut(duration: 0.4)) { highlighted = nil }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Boutique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Haptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .accessibilityLabel("Fermer")
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Theme.success))
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .sheet(item: $missingCost) { item in
                InsufficientDiamondsSheet(cost: item.cost, progressStore: progressStore) {
                    dismiss()
                    onOpenMissions()
                }
            }
            .alert("Erreur", isPresented: .init(
                get: { AdsManager.shared.lastError != nil && missingCost == nil },
                set: { if !$0 { AdsManager.shared.lastError = nil } }
            )) {
                Button("OK") { AdsManager.shared.lastError = nil }
            } message: {
                Text(AdsManager.shared.lastError ?? "")
            }
        }
        .onAppear { Analytics.capture("shop_viewed") }
    }

    // MARK: - Header

    private var balanceHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.livres)
                    .frame(width: 64, height: 64)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("TES DIAMANTS")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.8))
                Text("\(progressStore.livresBalance)")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Theme.livres, Theme.livres.mix(with: .black, by: 0.25)], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(alignment: .topTrailing) {
            Image(systemName: "sparkles")
                .font(.system(size: 54, weight: .bold))
                .foregroundStyle(.white.opacity(0.18))
                .padding(14)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tes diamants : \(progressStore.livresBalance)")
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        section(title, id: nil, header: { EmptyView() }, content: content)
    }

    /// A titled group of rows, optionally preceded by an explainer and
    /// tagged with an id so the shop can open scrolled to it.
    private func section<Header: View, Content: View>(
        _ title: String,
        id: ShopSection?,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isHighlighted = id != nil && highlighted == id
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Theme.inkMuted)
            header()
            VStack(spacing: 0) {
                content()
            }
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isHighlighted ? Theme.primary : Theme.line, lineWidth: isHighlighted ? 3 : 2)
            )
            .scaleEffect(isHighlighted ? 1.015 : 1)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHighlighted)
        }
        .id(id.map { AnyHashable($0) } ?? AnyHashable(title))
    }

    // MARK: - Explainers

    private var heartsExplainer: some View {
        ResourceExplainer(
            icon: "heart.fill",
            color: Theme.danger,
            title: store.isPremium ? "Cœurs illimités avec Premium" : "\(ProgressStore.energyMax) cœurs par jour",
            lines: [
                .init(icon: "xmark.circle.fill", text: "Chaque mauvaise réponse en leçon te coûte 1 cœur."),
                .init(icon: "hand.raised.fill", text: "À 0 cœur, tu ne peux plus commencer de leçon jusqu'à la recharge."),
                .init(icon: "moon.stars.fill", text: "Tous tes cœurs reviennent à minuit."),
                .init(icon: "arrow.clockwise.circle.fill", text: "Recharge plus tôt : 1 cœur pour \(ProgressStore.heartCost) 💎, le plein pour \(ProgressStore.energyRefillCost) 💎, +1 cœur par vidéo ou avec la mission « Gagne 1 duel ».")
            ]
        )
    }

    private var boltsExplainer: some View {
        ResourceExplainer(
            icon: "bolt.fill",
            color: Theme.lessonBolt,
            title: store.isPremium ? "Leçons illimitées avec Premium" : "\(ProgressStore.freeLessonDailyLimit) éclairs de leçon par jour",
            lines: [
                .init(icon: "book.fill", text: "Chaque leçon terminée utilise 1 éclair."),
                .init(icon: "hand.raised.fill", text: "Sans éclair, tu ne peux plus lancer de nouvelle leçon aujourd'hui."),
                .init(icon: "moon.stars.fill", text: "Ils se rechargent à minuit."),
                .init(icon: "arrow.clockwise.circle.fill", text: "Recharge plus tôt : +1 éclair pour \(ProgressStore.extraLessonCost) 💎 (\(ProgressStore.extraLessonDailyMax) max par jour) ou avec la mission « Termine 2 épreuves ».")
            ]
        )
    }

    // MARK: - Rows

    @ViewBuilder
    private var streakRows: some View {
        if let broken = progressStore.brokenStreak() {
            let nextRepair = progressStore.nextStreakRepairDate()
            ShopRow(
                icon: "flame.fill",
                color: Theme.primary,
                title: "Réparer ma série",
                subtitle: nextRepair.map { "Déjà réparée cette semaine · possible le \($0.formatted(.dateTime.weekday(.wide).day().month()))" }
                    ?? "Ta série de \(broken.length) jour\(broken.length > 1 ? "s" : "") s'est arrêtée",
                action: nextRepair == nil ? .price(broken.cost) : .status("Indisponible")
            ) {
                buy(cost: broken.cost, done: "Série de \(broken.length) jours réparée 🔥") { progressStore.repairStreak() }
            }
            divider
        }
        let freezes = progressStore.streakFreezes
        ShopRow(
            icon: "snowflake",
            color: Theme.link,
            title: "Protection de série",
            subtitle: "Utilisée automatiquement si tu rates un jour · en réserve : \(freezes)/\(ProgressStore.streakFreezeMax)",
            action: freezes >= ProgressStore.streakFreezeMax ? .status("Réserve pleine") : .price(ProgressStore.streakFreezeCost)
        ) {
            buy(cost: ProgressStore.streakFreezeCost, done: "Protection ajoutée 🧊") { progressStore.buyStreakFreeze() }
        }
    }

    @ViewBuilder
    private var heartRows: some View {
        let isFull = progressStore.energy >= ProgressStore.energyMax
        let premiumStatus: ShopRow.Action? = store.isPremium ? .status("Illimités") : (isFull ? .status("Déjà plein") : nil)
        ShopRow(
            icon: "heart.fill",
            color: Theme.danger,
            title: "1 cœur",
            subtitle: "Pour continuer ta leçon · \(progressStore.energy)/\(ProgressStore.energyMax) aujourd'hui",
            action: premiumStatus ?? .price(ProgressStore.heartCost)
        ) {
            buy(cost: ProgressStore.heartCost, done: "+1 cœur ❤️") { progressStore.buyHeart() }
        }
        divider
        ShopRow(
            icon: "heart.circle.fill",
            color: Theme.danger,
            title: "Recharge complète",
            subtitle: "Remet tes \(ProgressStore.energyMax) cœurs d'un coup",
            action: premiumStatus ?? .price(ProgressStore.energyRefillCost)
        ) {
            buy(cost: ProgressStore.energyRefillCost, done: "Cœurs rechargés ❤️") { progressStore.refillEnergyWithRubis() }
        }
        if !store.isPremium {
            divider
            let canWatch = progressStore.canWatchRewardedAd()
            ShopRow(
                icon: "play.rectangle.fill",
                color: Theme.danger,
                title: "Regarder une vidéo",
                subtitle: "+1 cœur, gratuit",
                action: isFull ? .status("Déjà plein") : (isWatchingAd ? .loading : (canWatch ? .label("Regarder") : .status("Demain")))
            ) {
                watchHeartAd()
            }
        }
    }

    @ViewBuilder
    private var lessonRow: some View {
        let left = progressStore.extraLessonsBuyableToday
        ShopRow(
            icon: "bolt.fill",
            color: Theme.lessonBolt,
            title: "Leçon supplémentaire",
            subtitle: "+1 éclair de leçon · encore \(left)/\(ProgressStore.extraLessonDailyMax) aujourd'hui",
            action: store.isPremium ? .status("Illimitées") : (left == 0 ? .status("Demain") : .price(ProgressStore.extraLessonCost))
        ) {
            buy(cost: ProgressStore.extraLessonCost, done: "+1 éclair de leçon ⚡️") { progressStore.unlockExtraLesson() }
        }
    }

    @ViewBuilder
    private var earnRows: some View {
        let videosLeft = progressStore.diamondAdsRemainingToday
        ShopRow(
            icon: "play.rectangle.fill",
            color: Theme.duelAccent,
            title: "Regarder une vidéo",
            subtitle: "+\(ProgressStore.rewardedAdLivres) 💎 · encore \(videosLeft)/\(ProgressStore.diamondAdDailyCap) aujourd'hui",
            action: isWatchingAd ? .loading : (videosLeft == 0 ? .status("Demain") : .label("Regarder"))
        ) {
            watchAd()
        }
        divider
        ShopRow(
            icon: "target",
            color: Theme.success,
            title: "Missions du jour",
            subtitle: "Des diamants à gagner chaque jour",
            action: .label("Voir")
        ) {
            dismiss()
            onOpenMissions()
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 1.5).padding(.leading, 74)
    }

    // MARK: - Actions

    private func buy(cost: Int, done: String, perform: () -> Bool) {
        guard progressStore.livresBalance >= cost else {
            Haptics.error()
            missingCost = MissingCost(cost: cost)
            return
        }
        let ok = withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { perform() }
        if ok {
            Haptics.success()
            showToast(done)
        } else {
            Haptics.error()
        }
    }

    private func showToast(_ text: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { toast = text }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
    }

    private func watchHeartAd() {
        guard !isWatchingAd else { return }
        Haptics.medium()
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            guard rewarded else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                progressStore.grantEnergyFromAd()
            }
            Haptics.success()
            showToast("+1 cœur ❤️")
        }
    }

    private func watchAd() {
        guard !isWatchingAd else { return }
        Haptics.medium()
        isWatchingAd = true
        AdsManager.shared.showRewarded(from: TopViewControllerFinder.topViewController()) { rewarded in
            isWatchingAd = false
            guard rewarded else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                progressStore.creditRewardedAd()
            }
            Haptics.success()
            showToast("+\(ProgressStore.rewardedAdLivres) 💎")
        }
    }
}

/// Short "how it works" card above a resource's rows.
private struct ResourceExplainer: View {
    struct Line: Hashable {
        let icon: String
        let text: String
    }

    let icon: String
    let color: Color
    let title: String
    let lines: [Line]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(color))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            ForEach(lines, id: \.self) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: line.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(color)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    Text(line.text)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }
}

private struct MissingCost: Identifiable {
    let cost: Int
    var id: Int { cost }
}

/// One shop line: tinted icon tile, title and detail, and a price pill or status.
private struct ShopRow: View {
    enum Action: Equatable {
        case price(Int)
        case label(String)
        case status(String)
        case loading
    }

    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let action: Action
    let onTap: () -> Void

    private var isEnabled: Bool {
        switch action {
        case .price, .label: return true
        case .status, .loading: return false
        }
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressDownStyle())
        .disabled(!isEnabled)
    }

    @ViewBuilder
    private var trailing: some View {
        switch action {
        case .price(let cost):
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("\(cost)")
                    .monospacedDigit()
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(minHeight: 36)
            .background(Capsule().fill(Theme.livres))
            .background(Capsule().fill(Theme.livres.mix(with: .black, by: 0.28)).offset(y: 3))
            .accessibilityLabel("\(cost) diamants")
        case .label(let text):
            Text(text.uppercased())
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.link)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 2))
        case .status(let text):
            Text(text)
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 12)
                .frame(minHeight: 32)
                .background(Capsule().fill(Theme.lockedFill))
        case .loading:
            ProgressView()
                .tint(Theme.duelAccent)
                .frame(width: 44, height: 36)
        }
    }
}
