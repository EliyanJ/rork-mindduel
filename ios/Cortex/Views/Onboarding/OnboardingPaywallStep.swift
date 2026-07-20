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
    @State private var compact: Bool = false

    private enum LegalLink: Identifiable {
        case privacy, terms
        var id: Int { hashValue }
    }

    private struct BenefitItem: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let color: Color
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

    private var benefits: [BenefitItem] {
        [
            BenefitItem(icon: "brain.head.profile", text: "Développer ta culture générale", color: Theme.primary),
            BenefitItem(icon: "bubble.left.and.bubble.right", text: "Avoir des conversations plus riches", color: Color(hex: "#F59E0B")),
            BenefitItem(icon: "sparkles", text: "Booster ta confiance en soirée", color: Color(hex: "#EC4899")),
            BenefitItem(icon: "flame.fill", text: "Rendre ton temps d'écran utile", color: Color(hex: "#8B5CF6")),
        ]
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
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        heroSection

                        benefitsSection

                        comparisonCard

                        packagesSection

                        faqSection
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, compact ? 52 : 68)
                    .padding(.bottom, 24)
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
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { size in
                compact = size.height < 700
            }

            closeButton
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

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            Image("MascotWave")
                .resizable()
                .scaledToFit()
                .frame(height: compact ? 90 : 110)

            VStack(spacing: 8) {
                Text("Passe en Premium")
                    .font(.system(size: compact ? 28 : 32, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)

                Text("Apprends 4 fois plus avec les leçons, révise sans limites et sans publicité.")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Benefits

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Minduel t'aide à")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)

            VStack(spacing: 10) {
                ForEach(benefits) { item in
                    HStack(spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(item.color)
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(item.color.opacity(0.12)))

                        Text(item.text)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
                }
            }
        }
    }

    // MARK: - Comparison table

    private var comparisonCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Spacer().frame(maxWidth: .infinity)
                Text("Gratuit")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 64, alignment: .center)
                Text("Premium")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.primary))
                    .frame(width: 86, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().background(Theme.line)

            ForEach(features) { feature in
                HStack(spacing: 0) {
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
                        .frame(width: 64, alignment: .center)

                    HStack(spacing: 4) {
                        Image(systemName: feature.premiumIsUnlimited ? "infinity.circle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.success)
                        Text(feature.premiumValue)
                            .font(.system(.footnote, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                    }
                    .frame(width: 86, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if feature.id != features.last?.id {
                    Divider().background(Theme.line.opacity(0.6))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    // MARK: - Packages

    private var packagesSection: some View {
        VStack(spacing: 14) {
            ForEach(packages, id: \.identifier) { package in
                packageCard(package)
            }
        }
    }

    private func packageCard(_ package: Package) -> some View {
        let isSelected = selectedPackage?.identifier == package.identifier
        let product = package.storeProduct
        let isAnnual = package.packageType == .annual

        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.2)) { selectedPackage = package }
        } label: {
            VStack(spacing: 0) {
                if isAnnual {
                    Text("3 jours d'essai gratuit")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.gold))
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isAnnual ? "Annuel" : "Mensuel")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)

                        if isAnnual, let monthlyPrice = monthlyEquivalent(for: product) {
                            Text("\(monthlyPrice) / mois")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.inkMuted)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 6) {
                            if isAnnual, let discount = annualDiscountString {
                                Text(discount)
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Theme.ink))
                            }

                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(isSelected ? Theme.primary : Theme.line)
                        }

                        Text(product.localizedPriceString + (isAnnual ? "/an" : "/mois"))
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, isAnnual ? 12 : 16)
            }
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2.5 : 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var annualDiscountString: String? {
        guard let monthly = packages.first(where: { $0.packageType == .monthly })?.storeProduct,
              let annual = packages.first(where: { $0.packageType == .annual })?.storeProduct else {
            return nil
        }
        let monthlyNumber = NSDecimalNumber(decimal: monthly.price)
        let annualNumber = NSDecimalNumber(decimal: annual.price)
        let monthlyTotal = monthlyNumber.multiplying(by: 12)
        if monthlyTotal.compare(annualNumber) == .orderedDescending {
            let ratio = 1.0 - (annualNumber.doubleValue / monthlyTotal.doubleValue)
            let percent = Int((ratio * 100).rounded())
            return "-\(percent)%"
        }
        return nil
    }

    private func monthlyEquivalent(for product: StoreProduct) -> String? {
        let monthly = NSDecimalNumber(decimal: product.price).dividing(by: 12)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        return formatter.string(from: monthly)
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
                HStack(spacing: 12) {
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
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.2))
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
                    Text("Commencer l'essai gratuit")
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
            Text("Annule à tout moment, 0 pénalité, 0 frais")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)

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

    private var closeButton: some View {
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
        .padding(.top, 8)
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
