import SwiftUI
import RevenueCat

/// Minduel Premium paywall. Prices, periods and the free trial all come from
/// the App Store products of the current RevenueCat offering — nothing is
/// hard-coded. The annual plan is highlighted with its free trial.
struct PaywallView: View {
    /// Where the paywall was opened from, for analytics only.
    let source: String
    /// True when shown as the "Premium" tab rather than a sheet: no close button.
    var isEmbedded: Bool = false

    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var purchasingPackageId: String?
    @State private var legalLink: LegalLink?
    @State private var isMascotUp: Bool = false

    private enum LegalLink: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
        var title: String { self == .terms ? "Conditions d'utilisation" : "Confidentialité" }
        var url: URL { self == .terms ? WebLinks.terms : WebLinks.privacy }
    }

    private var packages: [Package] {
        [store.annualPackage, store.monthlyPackage].compactMap { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    plans
                    legalFooter
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            Analytics.capture("paywall_viewed", ["source": source])
            if store.offering == nil { await store.loadOfferings() }
        }
        .onChange(of: store.isPremium) { _, isPremium in
            guard isPremium else { return }
            Haptics.success()
            if !isEmbedded { dismiss() }
        }
        .sheet(item: $legalLink) { link in
            LegalWebView(title: link.title, url: link.url)
        }
        .alert("Oups", isPresented: Binding(
            get: { store.error != nil },
            set: { if !$0 { store.error = nil } }
        )) {
            Button("OK") { store.error = nil }
        } message: {
            Text(store.error ?? "")
        }
        .alert("Minduel Premium", isPresented: Binding(
            get: { store.notice != nil },
            set: { if !$0 { store.notice = nil } }
        )) {
            Button("OK") { store.notice = nil }
        } message: {
            Text(store.notice ?? "")
        }
    }

    // MARK: - Sections

    /// Fixed title bar, like Duolingo's "Abonnement" header.
    private var titleBar: some View {
        HStack {
            Text("Abonnement")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer()
            if !isEmbedded {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Fermer")
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.line).frame(height: 1.5)
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Label("MINDUEL PREMIUM", systemImage: "crown.fill")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.primary)
                Text("Choisis ta formule")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("Joue sans aucune limite, ou reste en gratuit.")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image("MascotTrophy")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .offset(y: isMascotUp ? -4 : 3)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isMascotUp)
                .onAppear { isMascotUp = true }
                .accessibilityHidden(true)
        }
    }

    private static let premiumPerks: [String] = [
        "Leçons et cœurs illimités, chaque jour",
        "Choix libre des thèmes et des chapitres",
        "Classé illimité, 1 contre 9, Flash 2v2",
        "Duels illimités, sans éclairs à recharger",
        "Tests de passage sans vidéo"
    ]

    private static let freePerks: [String] = [
        "2 éclairs de leçon et 3 cœurs par jour",
        "Parcours général (thème imposé)",
        "1v1, Flash, Hors ligne, Personnalisé + 1 classée/jour",
        "3 éclairs de duel, +2 par vidéo",
        "Classement entre amis"
    ]

    @ViewBuilder
    private var plans: some View {
        VStack(spacing: 16) {
            if packages.isEmpty {
                loadingCard
            } else {
                if let annual = store.annualPackage { premiumCard(annual) }
                if let monthly = store.monthlyPackage { premiumCard(monthly) }
            }
            freeCard
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            if store.isLoading {
                ProgressView().tint(Theme.primary)
                Text("Chargement des offres…")
            } else {
                Text("Les offres Premium ne sont pas disponibles pour le moment.")
                    .multilineTextAlignment(.center)
                Button("Réessayer") {
                    Task { await store.loadOfferings() }
                }
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.link)
                .frame(minHeight: 44)
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .semibold))
        .foregroundStyle(Theme.inkMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 2))
    }

    private func premiumCard(_ package: Package) -> some View {
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let trial = store.freeTrial(for: package)
        let isCurrent = store.isPremium && store.activeProductId == package.storeProduct.productIdentifier
        let subtitle: String
        if let trial {
            subtitle = "\(Self.durationText(trial.subscriptionPeriod)) gratuits, puis \(priceLine(package))"
        } else if isAnnual, let perMonth = package.storeProduct.localizedPricePerMonth {
            subtitle = "\(priceLine(package)), soit \(perMonth) par mois"
        } else {
            subtitle = priceLine(package)
        }
        let title: String
        if isCurrent {
            title = "FORMULE ACTUELLE"
        } else if let trial {
            title = "ESSAIE \(Self.durationText(trial.subscriptionPeriod).uppercased()) GRATUITS"
        } else {
            title = "S'ABONNER"
        }
        return PlanCard(
            title: isAnnual ? "Premium annuel" : "Premium mensuel",
            subtitle: subtitle,
            perks: Self.premiumPerks,
            image: isAnnual ? "MascotTrophy" : "MascotGift",
            highlight: isAnnual ? Theme.primary : nil,
            badge: isAnnual ? annualBadgeText : nil,
            disclosure: disclosure(for: package),
            buttonTitle: title,
            isButtonEnabled: !isCurrent && !store.isPurchasing && !store.isRestoring,
            isBusy: store.isPurchasing && purchasingPackageId == package.identifier
        ) {
            Haptics.medium()
            purchasingPackageId = package.identifier
            Analytics.capture("paywall_plan_tapped", ["plan": isAnnual ? "annual" : "monthly", "source": source])
            Task { await store.purchase(package) }
        }
    }

    private var freeCard: some View {
        PlanCard(
            title: "Gratuit",
            subtitle: "Pour découvrir Minduel à ton rythme",
            perks: Self.freePerks,
            image: "book_mascot_sitting",
            highlight: nil,
            badge: nil,
            disclosure: nil,
            buttonTitle: store.isPremium ? "INCLUS DANS PREMIUM" : "FORMULE ACTUELLE",
            isButtonEnabled: false,
            isBusy: false
        ) {}
    }

    private var annualBadgeText: String {
        if let savings = savingsPercent { return "MEILLEURE OFFRE · −\(savings) %" }
        return "MEILLEURE OFFRE"
    }

    private var legalFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Button {
                    Haptics.tap()
                    Task { await store.restore() }
                } label: {
                    if store.isRestoring {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("Restaurer mes achats")
                    }
                }
                .disabled(store.isRestoring || store.isPurchasing)
                Text("·")
                Button("Conditions") { legalLink = .terms }
                Text("·")
                Button("Confidentialité") { legalLink = .privacy }
            }
            .font(.system(.caption, design: .rounded, weight: .bold))
            .foregroundStyle(Theme.inkMuted)
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            Text("Abonnements à renouvellement automatique, résiliables à tout moment dans les réglages de ton compte Apple au moins 24 h avant la fin de la période en cours.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 6)
    }

    // MARK: - Copy

    private func priceLine(_ package: Package) -> String {
        let isAnnual = package.identifier == store.annualPackage?.identifier
        return "\(package.storeProduct.localizedPriceString)/\(isAnnual ? "an" : "mois")"
    }

    private func disclosure(for package: Package) -> String {
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let period = isAnnual ? "par an" : "par mois"
        let price = package.storeProduct.localizedPriceString
        if let trial = store.freeTrial(for: package) {
            return "\(Self.durationText(trial.subscriptionPeriod)) gratuits, puis \(price) \(period), renouvellement automatique."
        }
        return "\(price) \(period), renouvellement automatique."
    }

    /// Annual saving versus twelve monthly payments, from the store prices.
    private var savingsPercent: Int? {
        guard let annual = store.annualPackage?.storeProduct.price,
              let monthly = store.monthlyPackage?.storeProduct.price else { return nil }
        let yearlyFromMonthly = NSDecimalNumber(decimal: monthly * 12).doubleValue
        let annualValue = NSDecimalNumber(decimal: annual).doubleValue
        guard yearlyFromMonthly > 0, annualValue < yearlyFromMonthly else { return nil }
        let percent = Int(((1 - annualValue / yearlyFromMonthly) * 100).rounded())
        return percent >= 5 ? percent : nil
    }

    /// "7 jours", "1 mois"… from the App Store intro offer period.
    static func durationText(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return "\(period.value) jour\(period.value > 1 ? "s" : "")"
        case .week:
            let days = period.value * 7
            return "\(days) jours"
        case .month:
            return "\(period.value) mois"
        case .year:
            return "\(period.value) an\(period.value > 1 ? "s" : "")"
        @unknown default:
            return "\(period.value)"
        }
    }
}

/// One subscription formula, Duolingo-style: title, one line, blue checks,
/// an illustration on the right and its own outlined button.
private struct PlanCard: View {
    let title: String
    let subtitle: String
    let perks: [String]
    let image: String
    let highlight: Color?
    let badge: String?
    let disclosure: String?
    let buttonTitle: String
    let isButtonEnabled: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(perks, id: \.self) { perk in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(Theme.link)
                        Text(perk)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Button(action: action) {
                ZStack {
                    if isBusy {
                        ProgressView().tint(Theme.link)
                    } else {
                        Text(buttonTitle)
                    }
                }
            }
            .buttonStyle(PlanButtonStyle(isActive: isButtonEnabled || isBusy))
            .disabled(!isButtonEnabled)
            .padding(.top, 4)
            if let disclosure {
                Text(disclosure)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.background))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(highlight ?? Theme.line, lineWidth: highlight == nil ? 2 : 2.5)
        )
        .overlay(alignment: .topLeading) {
            if let badge, let highlight {
                Text(badge)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(highlight))
                    .offset(x: 18, y: -11)
            }
        }
        .padding(.top, badge == nil ? 0 : 8)
    }
}

/// Outlined, chunky button of a plan card: blue label when tappable,
/// muted when it marks the current formula.
private struct PlanButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(isActive ? Theme.link : Theme.inkMuted)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.background))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 2))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 16).fill(Theme.line).offset(y: 4))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
