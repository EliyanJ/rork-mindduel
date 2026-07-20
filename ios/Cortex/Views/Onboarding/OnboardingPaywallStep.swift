import SwiftUI
import RevenueCat

/// End-of-funnel paywall. Non-regression rules from the App Store review
/// guidelines: the close button always sits top-left on a contrasted
/// circle, price/duration/renewal terms are visible without scrolling, and
/// the restore + legal links are always present.
///
/// Only real, code-backed premium benefits are advertised here:
/// - Lessons quota: 1/day free → 4/day premium (ProgressStore.freeLessonDailyLimit / premiumLessonDailyLimit)
/// - Reviews quota: 10 cards/day free → unlimited premium (ProgressStore.freeReviewDailyCap / remainingFreeReviewCards)
/// - Ads: interstitials on ranked duels + bot training when !isPremium (DuelHomeView + AdsManager)
/// Themes/disciplines are NOT gated in code, so they are never listed as a
/// premium advantage. Spaced repetition is available to all users.
struct OnboardingPaywallStep: View {
    let store: StoreViewModel
    let onFinished: () -> Void

    @State private var selectedPackage: Package?
    @State private var legalSheet: LegalLink?
    @State private var expandedFaq: FAQItem?

    private enum LegalLink: Identifiable {
        case privacy, terms
        var id: Int { hashValue }
    }

    private struct FeatureRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let freeValue: String
        let premiumValue: String
        let premiumIsUnlimited: Bool
    }

    private struct FAQItem: Identifiable {
        let id = UUID()
        let question: String
        let answer: String
    }

    private var packages: [Package] {
        store.offerings?.current?.availablePackages ?? []
    }

    private let features: [FeatureRow] = [
        FeatureRow(
            icon: "bolt.3.fill",
            label: "Leçons par jour",
            freeValue: "1",
            premiumValue: "4",
            premiumIsUnlimited: false
        ),
        FeatureRow(
            icon: "cards.fill",
            label: "Cartes de révision",
            freeValue: "10 / jour",
            premiumValue: "Illimité",
            premiumIsUnlimited: true
        ),
        FeatureRow(
            icon: "rectangle.fill.badge.checkmark",
            label: "Publicité",
            freeValue: "Présente",
            premiumValue: "Aucune",
            premiumIsUnlimited: false
        )
    ]

    private let faqItems: [FAQItem] = [
        FAQItem(
            question: "Puis-je annuler à tout moment ?",
            answer: "Oui. L'abonnement est auto-renouvelable et se résilie depuis Réglages > Ton nom > Abonnements sur ton iPhone, à tout moment. Tu gardes l'accès Premium jusqu'à la fin de la période déjà payée."
        ),
        FAQItem(
            question: "Que se passe-t-il à la fin de l'essai gratuit ?",
            answer: "Si tu ne résilies pas avant la fin des 3 jours, l'abonnement choisi (mensuel ou annuel) se renouvelle automatiquement au prix affiché. Aucun débit n'a lieu pendant l'essai."
        ),
        FAQItem(
            question: "Mes progrès sont-ils sauvegardés si j'annule ?",
            answer: "Oui. Ton XP, tes séries de jours, ton niveau ELO et tes cartes de révision restent enregistrés sur l'appareil. Seuls les quotas redeviennent ceux de la version gratuite."
        ),
        FAQItem(
            question: "D'où viennent les questions ?",
            answer: "Les questions sont rédigées et vérifiées en interne, puis classées par difficulté (facile à légende) et par fréquence (commun, moyen, pointu). Le catalogue couvre la culture générale et le football."
        )
    ]

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 22) {
                            header(compact: compact)

                            comparisonCard(compact: compact)

                            faqSection

                            if store.isLoading {
                                ProgressView()
                                    .tint(Theme.primary)
                                    .frame(maxWidth: .infinity, minHeight: 120)
                            } else if !packages.isEmpty {
                                VStack(spacing: 14) {
                                    ForEach(packages, id: \.identifier) { package in
                                        packageRow(package)
                                    }
                                }
                            } else {
                                emptyState
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, compact ? 16 : 28)
                        .padding(.bottom, 16)
                    }

                    if !packages.isEmpty {
                        stickyCTA
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Theme.background
                        OnboardingDecor(variant: 0)
                    }
                )

                closeButton(compact: compact)
            }
            .onAppear { selectedPackage = packages.first(where: { $0.packageType == .annual }) ?? packages.first }
            .onChange(of: packages) { _, newValue in
                if selectedPackage == nil { selectedPackage = newValue.first(where: { $0.packageType == .annual }) ?? newValue.first }
            }
            .sheet(item: $legalSheet) { link in
                switch link {
                case .privacy:
                    LegalWebView(title: "Confidentialité", url: WebLinks.privacy)
                case .terms:
                    LegalWebView(title: "Conditions", url: WebLinks.terms)
                }
            }
            .alert("Erreur", isPresented: .init(
                get: { store.error != nil },
                set: { if !$0 { store.error = nil } }
            )) {
                Button("OK") { store.error = nil }
            } message: {
                Text(store.error ?? "")
            }
        }
    }

    // MARK: - Header

    private func header(compact: Bool) -> some View {
        VStack(spacing: 10) {
            Text("🚀")
                .font(.system(size: compact ? 36 : 44))
                .padding(.top, compact ? 20 : 40)
            Text("Passe en Premium")
                .font(.system(size: compact ? 26 : 30, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Plus de leçons, plus de révisions, sans publicité.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Comparison table

    private func comparisonCard(compact: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("Fonctionnalité")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Gratuit")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: compact ? 64 : 76, alignment: .center)
                Text("Premium")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.primary))
                    .frame(width: compact ? 76 : 90, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Theme.line)

            ForEach(features) { feature in
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: feature.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 22)
                        Text(feature.label)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(feature.freeValue)
                        .font(.system(.footnote, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: compact ? 64 : 76, alignment: .center)

                    HStack(spacing: 4) {
                        if feature.premiumIsUnlimited {
                            Image(systemName: "infinity.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.success)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.success)
                        }
                        Text(feature.premiumValue)
                            .font(.system(.footnote, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: compact ? 76 : 90, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, compact ? 11 : 14)

                if feature.id != features.last?.id {
                    Divider().background(Theme.line.opacity(0.6))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
    }

    // MARK: - FAQ

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Questions fréquentes")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 2)

            ForEach(faqItems) { item in
                faqRow(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func faqRow(_ item: FAQItem) -> some View {
        let isExpanded = expandedFaq?.id == item.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                Haptics.tap()
                withAnimation(.spring(duration: 0.25)) {
                    expandedFaq = isExpanded ? nil : item
                }
            } label: {
                HStack {
                    Text(item.question)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(.footnote, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.2))
    }

    // MARK: - Package selection (RevenueCat, unchanged logic)

    private func packageRow(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let product = package.storeProduct
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.2)) { selectedPackage = package }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(package.packageType == .annual ? "Annuel" : product.localizedTitle)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    if let intro = product.introductoryDiscount {
                        Text("Essai gratuit de \(intro.subscriptionPeriod.value) \(intro.subscriptionPeriod.unit.label), puis \(product.localizedPriceString) / \(product.subscriptionPeriod?.unit.label ?? "période")")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    } else {
                        Text("\(product.localizedPriceString) / \(product.subscriptionPeriod?.unit.label ?? "période")")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer()
                if package.packageType == .annual {
                    Text("MEILLEUR PRIX")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.success))
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.line)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2.5 : 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky CTA + footer

    private var stickyCTA: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.medium()
                guard let package = selectedPackage ?? packages.first else { return }
                Task {
                    await store.purchase(package: package)
                    if store.isPremium { onFinished() }
                }
            } label: {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text("Débloquer Minduel Premium")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
            .disabled(store.isPurchasing || (selectedPackage ?? packages.first) == nil)
            .padding(.horizontal, 24)
            .padding(.top, 10)

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .background(
            LinearGradient(
                colors: [Theme.background.opacity(0), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Button("Restaurer les achats") {
                Haptics.tap()
                Task {
                    await store.restore()
                    if store.isPremium { onFinished() }
                }
            }
            .font(.system(.footnote, design: .rounded, weight: .heavy))
            .foregroundStyle(Theme.inkMuted)

            HStack(spacing: 6) {
                Button("Confidentialité") { legalSheet = .privacy }
                Text("·").foregroundStyle(Theme.inkMuted)
                Button("Conditions") { legalSheet = .terms }
            }
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.inkMuted)

            Text("Abonnement auto-renouvelable, résiliable à tout moment dans les réglages de ton compte Apple.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkMuted.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    // MARK: - Close button (top-left, contrasted circle)

    private func closeButton(compact: Bool) -> some View {
        Button {
            Haptics.tap()
            onFinished()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.9)))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .padding(.leading, 20)
        .padding(.top, compact ? 4 : 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundStyle(Theme.inkMuted)
            Text("L'offre Premium arrive bientôt.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            Button("Continuer") { onFinished() }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
                .padding(.top, 8)
        }
        .padding(.top, 40)
    }
}

private extension SubscriptionPeriod.Unit {
    var label: String {
        switch self {
        case .day: return "jour"
        case .week: return "semaine"
        case .month: return "mois"
        case .year: return "an"
        @unknown default: return "période"
        }
    }
}
