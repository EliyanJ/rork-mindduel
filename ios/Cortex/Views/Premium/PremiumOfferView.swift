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
                        comparisonTable
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
                .frame(width: 100, height: 100)
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

    // MARK: - Comparison table

    private enum CompareCell {
        case check, cross, unlimited
        case text(String)
    }

    private struct CompareColumn: Identifiable {
        let id: String
        let title: String
        let package: Package?
        let cells: [CompareCell]
    }

    private static let compareRows: [String] = [
        "Leçons par jour",
        "Cœurs",
        "Choix des thèmes",
        "Duels",
        "Parties classées",
        "Tests de passage",
        "Essai gratuit",
        "Engagement",
        "Prix par mois",
        "Économie"
    ]

    private static let rowHeight: CGFloat = 44

    private var compareColumns: [CompareColumn] {
        var columns: [CompareColumn] = [
            CompareColumn(
                id: "free",
                title: "Gratuit",
                package: nil,
                cells: [.text("2"), .text("3"), .cross, .text("3 éclairs"), .text("1 / jour"), .text("Vidéo"), .cross, .text("—"), .text("0 €"), .text("—")]
            )
        ]
        if let monthly = store.monthlyPackage {
            columns.append(CompareColumn(
                id: monthly.identifier,
                title: "Mensuel",
                package: monthly,
                cells: premiumCells(monthly, commitment: "Aucun", savings: nil)
            ))
        }
        if let annual = store.annualPackage {
            columns.append(CompareColumn(
                id: annual.identifier,
                title: "Annuel",
                package: annual,
                cells: premiumCells(annual, commitment: "1 an", savings: store.annualSavingsPercent)
            ))
        }
        return columns
    }

    private func premiumCells(_ package: Package, commitment: String, savings: Int?) -> [CompareCell] {
        let product = package.storeProduct
        let isAnnual = package.identifier == store.annualPackage?.identifier
        let monthly = isAnnual ? (product.localizedPricePerMonth ?? product.localizedPriceString) : product.localizedPriceString
        let trial: CompareCell = store.freeTrial(for: package).map { .text(PaywallView.durationText($0.subscriptionPeriod)) } ?? .cross
        return [
            .unlimited, .unlimited, .check, .unlimited, .unlimited, .check,
            trial,
            .text(commitment),
            .text(monthly),
            savings.map { .text("−\($0) %") } ?? .text("—")
        ]
    }

    private var comparisonTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPARE LES FORMULES")
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(1)
                .foregroundStyle(Theme.inkMuted)
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 52)
                    ForEach(Array(Self.compareRows.enumerated()), id: \.offset) { index, row in
                        Text(row)
                            .font(.system(.footnote, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight, alignment: .leading)
                            .overlay(alignment: .top) {
                                if index > 0 { Rectangle().fill(Theme.line.opacity(0.6)).frame(height: 1) }
                            }
                    }
                }
                .padding(.leading, 14)
                ForEach(compareColumns) { column in
                    compareColumnView(column)
                }
            }
            .padding(.vertical, 8)
            .padding(.trailing, 6)
            .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    private func compareColumnView(_ column: CompareColumn) -> some View {
        let isSelected = column.package != nil && column.id == selected?.identifier
        let isAnnual = column.package?.identifier == store.annualPackage?.identifier
        return Button {
            guard let package = column.package else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedId = package.identifier
            }
        } label: {
            VStack(spacing: 0) {
                VStack(spacing: 3) {
                    if isAnnual {
                        Text("TOP")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? Theme.primary : .white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(isSelected ? Color.white : Theme.success))
                    }
                    Text(column.title)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(isSelected ? .white : (column.package == nil ? Theme.inkMuted : Theme.ink))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14)
                        .fill(isSelected ? Theme.primary : .clear)
                )
                ForEach(Array(column.cells.enumerated()), id: \.offset) { _, cell in
                    cellView(cell, isPremium: column.package != nil, isSelected: isSelected)
                        .frame(height: Self.rowHeight)
                }
            }
            .frame(width: 70)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Theme.primary.opacity(0.1) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Theme.primary : .clear, lineWidth: 2.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(column.package == nil)
        .accessibilityLabel(column.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func cellView(_ cell: CompareCell, isPremium: Bool, isSelected: Bool) -> some View {
        switch cell {
        case .check:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.success)
        case .cross:
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.inkMuted.opacity(0.6))
        case .unlimited:
            Image(systemName: "infinity")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(isSelected ? Theme.primary : Theme.success)
        case .text(let value):
            Text(value)
                .font(.system(size: 13, weight: isPremium ? .black : .bold, design: .rounded))
                .foregroundStyle(isPremium ? (isSelected ? Theme.primary : Theme.ink) : Theme.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
                .padding(.horizontal, 4)
        }
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
