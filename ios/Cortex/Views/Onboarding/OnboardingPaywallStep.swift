import SwiftUI
import RevenueCat

/// End-of-funnel paywall. Non-regression rules from the App Store review
/// guidelines: the close button always sits top-left on a contrasted
/// circle, price/duration/renewal terms are visible without scrolling, and
/// the restore + legal links are always present.
struct OnboardingPaywallStep: View {
    let store: StoreViewModel
    let onFinished: () -> Void

    @State private var selectedPackage: Package?
    @State private var legalSheet: LegalLink?

    private enum LegalLink: Identifiable {
        case privacy, terms
        var id: Int { hashValue }
    }

    private var packages: [Package] {
        store.offerings?.current?.availablePackages ?? []
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700

            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    header(compact: compact)

                    Spacer(minLength: 12)

                    if store.isLoading {
                        ProgressView().tint(Theme.primary)
                        Spacer()
                    } else if packages.isEmpty {
                        emptyState
                        Spacer()
                    } else {
                        VStack(spacing: 14) {
                            ForEach(packages, id: \.identifier) { package in
                                packageRow(package)
                            }
                        }

                        Spacer(minLength: 16)

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

                        footer
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    ZStack {
                        Theme.background
                        OnboardingDecor(variant: 0)
                    }
                )

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

    private func header(compact: Bool) -> some View {
        VStack(spacing: 10) {
            Text("🚀")
                .font(.system(size: compact ? 36 : 44))
                .padding(.top, compact ? 20 : 40)
            Text("Passe en Premium")
                .font(.system(size: compact ? 26 : 30, weight: .black, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text("Duels illimités, tous les thèmes débloqués, sans publicité.")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

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
