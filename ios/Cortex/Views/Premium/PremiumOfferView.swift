import SwiftUI
import RevenueCat

/// Full offer screen, Genka-style long scroll:
/// personalised plan → plans → trial timeline → "Minduel t'aide à" stickers →
/// Free vs Premium table → what's inside → FAQ, with a sticky glass bar holding
/// the call-to-action. The amount billed after the trial is always stated next
/// to the button (App Store rule 3.1.2).
struct PremiumOfferView: View {
    let source: String
    /// Plan selected when the screen opens; annual when nil.
    var initialPackageId: String?
    /// Label of the dismiss control ("Plus tard" in onboarding, a cross elsewhere).
    var closeTitle: String?
    /// Themes picked during onboarding, shown in the "Ton plan" card.
    var planTopics: [Discipline] = []
    /// Daily goal picked during onboarding.
    var dailyGoal: Int?
    let onClose: () -> Void

    @Environment(StoreViewModel.self) private var store
    @Environment(AppModel.self) private var model
    @State private var selectedId: String?
    @State private var legalLink: LegalLink?
    @State private var isFloating: Bool = false
    @State private var hasAppeared: Bool = false
    @State private var openFaq: Int?

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

    private func isAnnual(_ package: Package) -> Bool {
        package.identifier == store.annualPackage?.identifier
    }

    var body: some View {
        ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    heroSection
                    plansSection
                    if let selected, let trial = store.freeTrial(for: selected) {
                        timeline(selected, trial: trial)
                    }
                    helpsSection
                    compareSection
                    insideSection
                    faqSection
                    legalFooter
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 20)
                .padding(.top, 64)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        // The sticky bar is a safe-area inset, so it never covers the plan rows.
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .overlay(alignment: .topLeading) { closeButton }
        .background(background.ignoresSafeArea())
        .task {
            Analytics.capture("premium_offer_viewed", ["source": source])
            if selectedId == nil { selectedId = initialPackageId ?? store.annualPackage?.identifier }
            if store.offering == nil { await store.loadOfferings() }
            if selectedId == nil { selectedId = store.annualPackage?.identifier }
            hasAppeared = true
            isFloating = true
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
                colors: [Theme.primary.opacity(0.18), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
            .frame(height: 520)
        }
    }

    // MARK: - Close

    private var closeButton: some View {
        Button {
            Haptics.tap()
            Analytics.capture("premium_offer_closed", ["source": source])
            onClose()
        } label: {
            Group {
                if let closeTitle {
                    Text(closeTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 16)
                        .frame(height: 40)
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .frame(width: 40, height: 40)
                }
            }
            .foregroundStyle(Theme.ink)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
            .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .padding(.leading, 14)
        .padding(.top, 6)
        .accessibilityLabel(closeTitle ?? "Fermer")
    }

    // MARK: - Hero + plan card

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(heroTitle)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 40)

            planCard
                .padding(.top, 18)
        }
    }

    private var heroTitle: String {
        planTopics.isEmpty ? "Débloque tout Minduel, sans limite" : "Prêt(e) à booster ta culture ?"
    }

    private var planCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(planTopics.isEmpty ? "Avec Premium :" : "Ton plan :")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)

            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2.fill")
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 22)
                Text(planTopics.isEmpty ? "Tous les thèmes débloqués" : "\(planTopics.count) thématique\(planTopics.count > 1 ? "s" : "")")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }

            if !planTopics.isEmpty {
                FlowChips(topics: Array(planTopics.prefix(4)))
            }

            HStack(spacing: 10) {
                Image(systemName: "scope")
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 22)
                Text(goalLine)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 22)
                Text("Duels illimités contre tes amis")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(22)
        .padding(.trailing, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 26).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Theme.ink.opacity(0.85), lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 26).fill(Theme.ink.opacity(0.85)).offset(x: 4, y: 5))
        .rotationEffect(.degrees(-1.5))
        .overlay(alignment: .topTrailing) {
            Image("book_quill_pen")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(isFloating ? 10 : 4))
                .offset(x: 10, y: -64)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: isFloating)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .bottomTrailing) {
            Image("MascotTrophy")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .offset(x: 6, y: isFloating ? 30 : 36)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: isFloating)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.gold)
                .offset(x: -6, y: -34)
                .scaleEffect(isFloating ? 1.1 : 0.9)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isFloating)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 18)
    }

    private var goalLine: String {
        guard let dailyGoal else { return "Leçons et cœurs illimités" }
        return "\(dailyGoal) nouvelle\(dailyGoal > 1 ? "s" : "") connaissance\(dailyGoal > 1 ? "s" : "") par jour, sans limite"
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        if packages.isEmpty {
            loadingCard
        } else {
            VStack(spacing: 12) {
                ForEach(packages, id: \.identifier) { package in
                    planRow(package)
                }
            }
        }
    }

    private func planRow(_ package: Package) -> some View {
        let annual = isAnnual(package)
        let isSelected = package.identifier == selected?.identifier
        let product = package.storeProduct
        let trial = store.freeTrial(for: package)
        let subtitle: String? = {
            var parts: [String] = []
            if annual, let perMonth = product.localizedPricePerMonth { parts.append("\(perMonth)/mois") }
            if !annual { parts.append("Sans engagement") }
            if let trial { parts.append("\(PaywallView.durationText(trial.subscriptionPeriod)) gratuits") }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }()
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selectedId = package.identifier
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.primary : Theme.inkMuted.opacity(0.6), lineWidth: 2.5)
                        .frame(width: 28, height: 28)
                    if isSelected {
                        Circle().fill(Theme.primary).frame(width: 28, height: 28)
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(annual ? "Annuel" : "Mensuel")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(.footnote, design: .rounded, weight: .semibold))
                            .foregroundStyle(Theme.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 8)
                Text("\(product.localizedPriceString)\(annual ? "/an" : "/mois")")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 78)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? Theme.primary.opacity(0.16) : Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 3 : 2)
            )
            .scaleEffect(isSelected ? 1 : 0.985)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Trial timeline

    private func timeline(_ package: Package, trial: StoreProductDiscount) -> some View {
        let end = trialEndDate(trial.subscriptionPeriod)
        let reminderDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        let endText = end.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR")))
        let reminderText = reminderDay.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "fr_FR")))
        let steps: [(icon: String, color: Color, title: String, text: String)] = [
            ("lock.open.fill", Theme.primary, "Aujourd'hui", "Tout Minduel est débloqué."),
            ("bell.fill", Theme.gold, "Jusqu'au \(reminderText)", "Annule en 2 touchers dans les réglages Apple, sans frais."),
            ("crown.fill", Theme.success, "Le \(endText)", "Début de l'abonnement : \(package.storeProduct.localizedPriceString) \(periodWord(package)).")
        ]
        return VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Comment marche l'essai", highlight: "gratuit")
            VStack(alignment: .leading, spacing: 0) {
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
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    // MARK: - Stickers

    private struct HelpSticker {
        let emoji: String
        let text: String
        let fill: Color
        let ink: Color
        let rotation: Double
        let indent: CGFloat
    }

    private static let helpStickers: [HelpSticker] = [
        HelpSticker(emoji: "💬", text: "Briller dans les conversations", fill: Theme.gold, ink: Color(hex: "3B2E28"), rotation: -3, indent: 0),
        HelpSticker(emoji: "🧠", text: "Muscler ta mémoire", fill: Theme.danger, ink: .white, rotation: 2.5, indent: 60),
        HelpSticker(emoji: "⚔️", text: "Battre tes amis en duel", fill: Color(hex: "2B3A42"), ink: .white, rotation: -2, indent: 22),
        HelpSticker(emoji: "📱", text: "Rendre ton temps d'écran utile", fill: Theme.livres, ink: .white, rotation: 1.5, indent: 48)
    ]

    private var helpsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Minduel t'aide à", highlight: nil)
            VStack(alignment: .leading, spacing: -6) {
                ForEach(Array(Self.helpStickers.enumerated()), id: \.offset) { index, sticker in
                    HStack(spacing: 10) {
                        Text(sticker.emoji).font(.system(size: 24))
                        Text(sticker.text)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(sticker.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 20).fill(sticker.fill))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black.opacity(0.85), lineWidth: 2.5))
                    .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.85)).offset(x: 3, y: 5))
                    .rotationEffect(.degrees(sticker.rotation))
                    .padding(.leading, sticker.indent)
                    .zIndex(Double(Self.helpStickers.count - index))
                    .opacity(hasAppeared ? 1 : 0)
                    .scaleEffect(hasAppeared ? 1 : 0.85)
                    .animation(.spring(response: 0.45, dampingFraction: 0.65).delay(0.08 * Double(index)), value: hasAppeared)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Free vs Premium

    private struct CompareRow {
        let emoji: String
        let label: String
        let free: String?
    }

    private static let compareRows: [CompareRow] = [
        CompareRow(emoji: "📚", label: "Leçons illimitées", free: "2/j"),
        CompareRow(emoji: "❤️", label: "Cœurs illimités", free: "3"),
        CompareRow(emoji: "🗺️", label: "Tous les thèmes", free: nil),
        CompareRow(emoji: "⚔️", label: "Duels illimités", free: "3"),
        CompareRow(emoji: "🏆", label: "Parties classées illimitées", free: "1/j"),
        CompareRow(emoji: "🚀", label: "Tests de passage sans vidéo", free: nil),
        CompareRow(emoji: "🎯", label: "Choix du chapitre", free: nil)
    ]

    private var compareSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle("Va", highlight: "plus loin", suffix: "avec Premium")
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 50)
                    ForEach(Array(Self.compareRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 10) {
                            Text(row.emoji).font(.system(size: 20))
                            Text(row.label)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)

                VStack(spacing: 0) {
                    Text("Gratuit")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(height: 50)
                    ForEach(Array(Self.compareRows.enumerated()), id: \.offset) { _, row in
                        Group {
                            if let free = row.free {
                                Text(free)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.inkMuted)
                            } else {
                                Capsule().fill(Theme.inkMuted.opacity(0.6)).frame(width: 12, height: 3)
                            }
                        }
                        .frame(height: 52)
                    }
                }
                .frame(width: 64)

                VStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Premium")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(height: 50)
                    ForEach(Array(Self.compareRows.enumerated()), id: \.offset) { index, _ in
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(.white))
                            .frame(height: 52)
                            .scaleEffect(hasAppeared ? 1 : 0.3)
                            .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.05 * Double(index)), value: hasAppeared)
                    }
                }
                .padding(.bottom, 8)
                .frame(width: 92)
                .background(RoundedRectangle(cornerRadius: 22).fill(Theme.primary))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color(hex: "FFB070"), lineWidth: 2))
                .padding(.vertical, -6)
                .padding(.trailing, 8)
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    // MARK: - What's inside (real catalog numbers only)

    private var insideSection: some View {
        let disciplines = model.catalog.disciplines
        let chapters = disciplines.reduce(0) { $0 + $1.chapters.count }
        let stats: [(value: String, label: String)] = [
            ("\(disciplines.count)", "thèmes"),
            ("\(chapters)", "chapitres"),
            ("1 vs 9", "en classé")
        ]
        return VStack(spacing: 18) {
            HStack(spacing: 10) {
                Image("MascotCheer")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                Text("Tout ce que tu débloques dès aujourd'hui")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: "3B2E28"))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                    VStack(spacing: 2) {
                        Text(stat.value)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(stat.label)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: "1A1A1A")))
                    .rotationEffect(.degrees(-1))
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                Text("Annule à tout moment depuis les réglages Apple")
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: "3B2E28"))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 26).fill(Theme.gold))
    }

    // MARK: - FAQ

    private var faqItems: [(question: String, answer: String)] {
        [
            ("Comment fonctionne l'essai gratuit ?", "Tu as accès à tout Minduel Premium pendant la période d'essai, sans rien payer. Si tu n'annules pas au moins 24 h avant la fin, l'abonnement choisi démarre automatiquement."),
            ("Comment annuler ?", "Ouvre Réglages › ton nom › Abonnements › Minduel, puis touche « Annuler l'abonnement ». Aucune pénalité, aucun frais."),
            ("Et si je reste en gratuit ?", "Tu gardes 2 leçons par jour, 3 cœurs, le parcours général et des duels. Les vidéos récompensées te permettent de recharger."),
            ("Mon abonnement marche sur un autre iPhone ?", "Oui, avec le même identifiant Apple : touche « Restaurer » en bas de cette page."),
            ("Quelle différence entre annuel et mensuel ?", "Exactement les mêmes avantages. L'annuel revient moins cher par mois, le mensuel est sans engagement.")
        ]
    }

    private var faqSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("FAQ", highlight: nil)
            VStack(spacing: 0) {
                ForEach(Array(faqItems.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            Haptics.tap()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                openFaq = openFaq == index ? nil : index
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Text(item.question)
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(Theme.inkMuted)
                                    .rotationEffect(.degrees(openFaq == index ? 180 : 0))
                            }
                            .frame(minHeight: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if openFaq == index {
                            Text(item.answer)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.bottom, 16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        if index < faqItems.count - 1 {
                            Rectangle().fill(Theme.line).frame(height: 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        }
    }

    private var legalFooter: some View {
        HStack(spacing: 8) {
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
            Text("•")
            Button("Conditions") { legalLink = .terms }
            Text("•")
            Button("Confidentialité") { legalLink = .privacy }
        }
        .font(.system(.subheadline, design: .rounded, weight: .bold))
        .foregroundStyle(Theme.inkMuted)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    // MARK: - Sticky bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let selected {
                Text(billedAmount(selected))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: selectedId)
            }
            Button {
                guard let selected else { return }
                Haptics.medium()
                Analytics.capture("paywall_plan_tapped", ["plan": isAnnual(selected) ? "annual" : "monthly", "source": source])
                Task { await store.purchase(selected) }
            } label: {
                ZStack {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("CONTINUER")
                    }
                }
            }
            .buttonStyle(ChunkyOfferButtonStyle())
            .disabled(selected == nil || store.isPurchasing || store.isRestoring)
            if let selected {
                Text(disclosure(selected))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                .fill(.regularMaterial)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30)
                        .stroke(Theme.line, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ text: String, highlight: String?, suffix: String? = nil) -> some View {
        var title = AttributedString(text)
        if let highlight {
            var part = AttributedString(" \(highlight)")
            part.foregroundColor = Theme.primary
            title += part
        }
        if let suffix {
            title += AttributedString(" \(suffix)")
        }
        return Text(title)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(Theme.ink)
            .fixedSize(horizontal: false, vertical: true)
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

    // MARK: - Copy

    private func periodWord(_ package: Package) -> String {
        isAnnual(package) ? "par an" : "par mois"
    }

    /// The amount actually billed, e.g. "29,99 € par an": always the most
    /// prominent price on screen (App Store rule 3.1.2(c)).
    private func billedAmount(_ package: Package) -> String {
        "\(package.storeProduct.localizedPriceString) \(periodWord(package))"
    }

    private func disclosure(_ package: Package) -> String {
        let renewal = "Renouvellement automatique, résiliable à tout moment dans les réglages Apple."
        if let trial = store.freeTrial(for: package) {
            return "\(PaywallView.durationText(trial.subscriptionPeriod)) gratuits, puis \(billedAmount(package)). \(renewal)"
        }
        return "\(billedAmount(package)). \(renewal)"
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

/// Coloured theme chips of the "Ton plan" card, wrapping onto several lines.
private struct FlowChips: View {
    let topics: [Discipline]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { chips }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) { ForEach(topics.prefix(2)) { chip($0) } }
                HStack(spacing: 8) { ForEach(topics.dropFirst(2)) { chip($0) } }
            }
        }
    }

    @ViewBuilder
    private var chips: some View {
        ForEach(topics) { chip($0) }
    }

    private func chip(_ topic: Discipline) -> some View {
        Text(topic.name)
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(topic.color))
            .overlay(Capsule().stroke(Color.black.opacity(0.8), lineWidth: 2))
    }
}

/// Big orange 3D call-to-action of the offer screen.
private struct ChunkyOfferButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .black))
            .tracking(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Capsule().fill(Theme.primary))
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(Capsule().fill(Color(hex: "C75400")).offset(y: 4))
            .padding(.bottom, 4)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
