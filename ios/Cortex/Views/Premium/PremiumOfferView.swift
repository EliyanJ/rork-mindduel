import SwiftUI
import RevenueCat

/// Full offer screen, Duolingo-style: the annual plan first with its monthly
/// equivalent in big, a free-trial timeline and a "try for 0,00 €" button.
/// The amount billed after the trial is always stated next to the button
/// (App Store rule 3.1.2). Used at the end of onboarding and after tapping
/// a plan on the subscription tab.
struct PremiumOfferView: View {
    let source: String
    /// Plan selected when the screen opens; annual when nil.
    var initialPackageId: String?
    /// Label of the dismiss control ("Plus tard" in onboarding, a cross elsewhere).
    var closeTitle: String?
    let onClose: () -> Void

    @Environment(StoreViewModel.self) private var store
    @State private var selectedId: String?
    @State private var legalLink: LegalLink?
    @State private var isMascotUp: Bool = false
    @State private var hasAppeared: Bool = false

    private enum LegalLink: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
        var title: String { self == .terms ? "Conditions d'utilisation" : "Confidentialité" }
        var url: URL { self == .terms ? WebLinks.terms : WebLinks.privacy }
    }

    private var packages: [Package] {
        [store.annualPackage, store.monthlyPackage].compactMap { $0 }
    }

    private var selected: Package? {
        packages.first { $0.identifier == selectedId } ?? store.annualPackage ?? packages.first
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    if packages.isEmpty {
                        loadingCard
                    } else {
                        VStack(spacing: 12) {
                            ForEach(packages, id: \.identifier) { package in
                                planRow(package)
                            }
                        }
                        if let selected, let trial = store.freeTrial(for: selected) {
                            timeline(selected, trial: trial)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            bottomBar
        }
        .background(background.ignoresSafeArea())
        .task {
            Analytics.capture("premium_offer_viewed", ["source": source])
            if selectedId == nil { selectedId = initialPackageId ?? store.annualPackage?.identifier }
            if store.offering == nil { await store.loadOfferings() }
            if selectedId == nil { selectedId = store.annualPackage?.identifier }
            hasAppeared = true
        }
        .onChange(of: store.isPremium) { _, isPremium in
            guard isPremium else { return }
            Haptics.success()
            onClose()
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
        .sensoryFeedback(.selection, trigger: selectedId)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Theme.background
            RadialGradient(
                colors: [Theme.primary.opacity(0.22), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 380
            )
            .frame(height: 420)
        }
    }

    // MARK: - Sections

    private var topBar: some View {
        HStack {
            Spacer()
            Button {
                Haptics.tap()
                Analytics.capture("premium_offer_closed", ["source": source])
                onClose()
            } label: {
                if let closeTitle {
                    Text(closeTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(width: 44, height: 44)
                }
            }
            .accessibilityLabel(closeTitle ?? "Fermer")
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            Image("MascotTrophy")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .offset(y: isMascotUp ? -5 : 3)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: isMascotUp)
                .onAppear { isMascotUp = true }
                .accessibilityHidden(true)
            Text(heroTitle)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("Leçons, cœurs et duels illimités. Tous les thèmes, sans attendre minuit.")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var heroTitle: String {
        if let selected, let trial = store.freeTrial(for: selected) {
            return "Essaie Premium \(PaywallView.durationText(trial.subscriptionPeriod)) gratuitement"
        }
        return "Passe à Minduel Premium"
    }

    private func planRow(_ package: Package) -> some View {
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let isSelected = package.identifier == selected?.identifier
        let product = package.storeProduct
        let bigPrice = isAnnual ? (product.localizedPricePerMonth ?? product.localizedPriceString) : product.localizedPriceString
        let smallPrice = isAnnual ? "\(product.localizedPriceString) par an" : "Sans engagement"
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedId = package.identifier
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: 2.5)
                        .frame(width: 26, height: 26)
                    if isSelected {
                        Circle().fill(Theme.primary).frame(width: 14, height: 14)
                            .transition(.scale)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(isAnnual ? "Annuel" : "Mensuel")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(smallPrice)
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(bigPrice)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.primary : Theme.ink)
                        .monospacedDigit()
                    Text("/mois")
                        .font(.system(.footnote, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(isSelected ? Theme.primary.opacity(0.08) : Theme.card))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2.5 : 2)
            )
            .overlay(alignment: .topTrailing) {
                if isAnnual, let savings = store.annualSavingsPercent {
                    Text("−\(savings) %")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.success))
                        .offset(x: -14, y: -11)
                }
            }
            .scaleEffect(isSelected ? 1 : 0.98)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func timeline(_ package: Package, trial: StoreProductDiscount) -> some View {
        let end = trialEndDate(trial.subscriptionPeriod)
        let reminderDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        let endText = end.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR")))
        let reminderText = reminderDay.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR")))
        let steps: [(icon: String, color: Color, title: String, text: String)] = [
            ("lock.open.fill", Theme.primary, "Aujourd'hui", "Tout Minduel est débloqué, 0,00 € à payer."),
            ("bell.fill", Theme.gold, "Jusqu'au \(reminderText)", "Annule en 2 touchers dans les réglages Apple, sans frais."),
            ("crown.fill", Theme.success, "Le \(endText)", "Début de l'abonnement : \(package.storeProduct.localizedPriceString) \(periodWord(package)).")
        ]
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Image(systemName: step.icon)
                            .font(.system(size: 14, weight: .black))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(step.color))
                        if index < steps.count - 1 {
                            Capsule()
                                .fill(LinearGradient(colors: [step.color, steps[index + 1].color], startPoint: .top, endPoint: .bottom))
                                .frame(width: 5)
                                .frame(minHeight: 26, maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text(step.text)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, index < steps.count - 1 ? 14 : 0)
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.12 * Double(index)), value: hasAppeared)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5))
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
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 2))
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let selected {
                Button {
                    Haptics.medium()
                    let isAnnual = selected.identifier == store.annualPackage?.identifier
                    Analytics.capture("paywall_plan_tapped", ["plan": isAnnual ? "annual" : "monthly", "source": source])
                    Task { await store.purchase(selected) }
                } label: {
                    ZStack {
                        if store.isPurchasing {
                            ProgressView().tint(.white)
                        } else {
                            Text(store.freeTrial(for: selected) != nil ? "ESSAIE POUR 0,00 €" : "S'ABONNER")
                        }
                    }
                }
                .buttonStyle(ChunkyOfferButtonStyle())
                .disabled(store.isPurchasing || store.isRestoring)
                Text(disclosure(selected))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Button {
                    Haptics.tap()
                    Task { await store.restore() }
                } label: {
                    if store.isRestoring {
                        ProgressView().controlSize(.mini)
                    } else {
                        Text("Restaurer")
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
            .frame(minHeight: 32)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(Theme.background.shadow(.drop(color: .black.opacity(0.08), radius: 10, y: -4)))
    }

    // MARK: - Copy

    private func periodWord(_ package: Package) -> String {
        package.identifier == store.annualPackage?.identifier ? "par an" : "par mois"
    }

    private func disclosure(_ package: Package) -> String {
        let price = "\(package.storeProduct.localizedPriceString) \(periodWord(package))"
        if let trial = store.freeTrial(for: package) {
            return "\(PaywallView.durationText(trial.subscriptionPeriod)) gratuits, puis \(price). Renouvellement automatique, résiliable à tout moment."
        }
        return "\(price). Renouvellement automatique, résiliable à tout moment."
    }

    private func trialEndDate(_ period: SubscriptionPeriod) -> Date {
        let component: Calendar.Component
        var value = period.value
        switch period.unit {
        case .day: component = .day
        case .week:
            component = .day
            value *= 7
        case .month: component = .month
        case .year: component = .year
        @unknown default: component = .day
        }
        return Calendar.current.date(byAdding: component, value: value, to: .now) ?? .now
    }
}

/// Big orange 3D call-to-action of the offer screen.
private struct ChunkyOfferButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .black))
            .tracking(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.primary))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "C75400")).offset(y: 4))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
