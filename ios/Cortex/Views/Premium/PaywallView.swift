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
    @State private var selectedPackageId: String?
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

    private var selectedPackage: Package? {
        packages.first { $0.identifier == selectedPackageId } ?? store.annualPackage ?? packages.first
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            background
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    benefits
                    plans
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { footer }

            if !isEmbedded { closeButton }
        }
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

    private var background: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.primary.opacity(0.22), Theme.primary.opacity(0)],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            RadialGradient(
                colors: [Theme.gold.opacity(0.18), Theme.gold.opacity(0)],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 260
            )
        }
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        Button {
            Haptics.tap()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.card.opacity(0.9)))
        }
        .accessibilityLabel("Fermer")
        .padding(.trailing, 14)
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image("MascotTrophy")
                .resizable()
                .scaledToFit()
                .frame(height: 128)
                .offset(y: isMascotUp ? -6 : 4)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isMascotUp)
                .onAppear { isMascotUp = true }
                .accessibilityHidden(true)
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundStyle(Theme.gold)
                Text("MINDUEL PREMIUM")
                    .tracking(1.2)
                    .foregroundStyle(Theme.primary)
            }
            .font(.system(.caption, design: .rounded, weight: .heavy))
            Text("Joue sans aucune limite")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
        }
    }

    private var benefits: some View {
        VStack(spacing: 10) {
            benefitRow(icon: "infinity", color: Theme.primary, title: "Leçons illimitées", detail: "Fini la limite de 2 leçons par jour")
            benefitRow(icon: "square.grid.2x2.fill", color: Color(hex: "1CB0F6"), title: "Choix libre des thèmes", detail: "Choisis tes thèmes en leçon et en duel")
            benefitRow(icon: "globe", color: Color(hex: "9B4DFF"), title: "Mode classé", detail: "Matchs 1V1 classés et classement mondial")
            benefitRow(icon: "bolt.fill", color: Theme.duelAccent, title: "Duels illimités", detail: "Fini les points de duel à recharger")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Theme.card)
                .shadow(color: Theme.ink.opacity(0.06), radius: 14, y: 6)
        )
    }

    private func benefitRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 13).fill(color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Text(detail)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.success)
        }
    }

    @ViewBuilder
    private var plans: some View {
        if packages.isEmpty {
            VStack(spacing: 12) {
                if store.isLoading {
                    ProgressView().tint(Theme.primary)
                    Text("Chargement des offres…")
                } else {
                    Text("Les offres ne sont pas disponibles pour le moment.")
                    Button("Réessayer") {
                        Task { await store.loadOfferings() }
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                }
            }
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(Theme.inkMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(packages, id: \.identifier) { package in
                    planCard(package)
                }
            }
        }
    }

    private func planCard(_ package: Package) -> some View {
        let isSelected = package.identifier == selectedPackage?.identifier
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let trial = store.freeTrial(for: package)
        return Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.3)) { selectedPackageId = package.identifier }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.inkMuted.opacity(0.35))
                VStack(alignment: .leading, spacing: 3) {
                    Text(isAnnual ? "Annuel" : "Mensuel")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    if let trial {
                        Text("\(Self.durationText(trial.subscriptionPeriod)) gratuits, puis \(priceLine(package))")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.success)
                    } else if isAnnual, let perMonth = package.storeProduct.localizedPricePerMonth {
                        Text("Soit \(perMonth) par mois")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer(minLength: 6)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(isAnnual ? "par an" : "par mois")
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.primary.opacity(0.07) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2.5 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if isAnnual { annualBadge(trial: trial) }
            }
        }
        .buttonStyle(.plain)
        .padding(.top, isAnnual ? 10 : 0)
    }

    private func annualBadge(trial: StoreProductDiscount?) -> some View {
        HStack(spacing: 6) {
            if let trial {
                Text("\(Self.durationText(trial.subscriptionPeriod).uppercased()) GRATUITS")
            } else {
                Text("LE PLUS AVANTAGEUX")
            }
            if let savings = savingsPercent {
                Text("−\(savings) %")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white.opacity(0.25)))
            }
        }
        .font(.system(size: 11, weight: .heavy, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.primary))
        .offset(x: -14, y: -11)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.medium()
                guard let package = selectedPackage else { return }
                Task { await store.purchase(package) }
            } label: {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle)
                }
            }
            .buttonStyle(ChunkyButtonStyle())
            .disabled(selectedPackage == nil || store.isPurchasing || store.isRestoring)
            .opacity(selectedPackage == nil ? 0.5 : 1)

            Text(disclosure)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Button {
                    Haptics.tap()
                    Task { await store.restore() }
                } label: {
                    if store.isRestoring {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("Restaurer les achats")
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
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .background(Theme.background.opacity(0.96).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Copy

    private var ctaTitle: String {
        guard let package = selectedPackage else { return "Continuer" }
        if let trial = store.freeTrial(for: package) {
            return "Essayer \(Self.durationText(trial.subscriptionPeriod)) gratuits"
        }
        return "S'abonner"
    }

    private func priceLine(_ package: Package) -> String {
        let isAnnual = package.identifier == store.annualPackage?.identifier
        return "\(package.storeProduct.localizedPriceString)/\(isAnnual ? "an" : "mois")"
    }

    private var disclosure: String {
        guard let package = selectedPackage else { return "" }
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let period = isAnnual ? "par an" : "par mois"
        let price = package.storeProduct.localizedPriceString
        let renewal = "Renouvellement automatique, résiliable à tout moment dans les réglages de ton compte Apple au moins 24 h avant la fin de la période en cours."
        if let trial = store.freeTrial(for: package) {
            return "\(Self.durationText(trial.subscriptionPeriod)) gratuits, puis \(price) \(period). \(renewal)"
        }
        return "\(price) \(period). \(renewal)"
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
