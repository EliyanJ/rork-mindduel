import SwiftUI
import RevenueCat

/// Sheet listing the four one-time rubis packs (S/M/L/XL). Purchases are
/// credited straight to the local wallet through `ProgressStore`.
struct LivresShopView: View {
    @Environment(StoreViewModel.self) private var store
    @Environment(\.dismiss) private var dismiss
    let progressStore: ProgressStore

    @State private var purchasingIdentifier: String?

    private var packages: [Package] {
        (store.livresOffering?.availablePackages ?? [])
            .sorted { lhs, rhs in
                (StoreViewModel.livresPackAmounts[lhs.storeProduct.productIdentifier] ?? 0)
                    < (StoreViewModel.livresPackAmounts[rhs.storeProduct.productIdentifier] ?? 0)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    if packages.isEmpty {
                        ProgressView().tint(Theme.livres).padding(.top, 40)
                    } else {
                        ForEach(packages, id: \.identifier) { package in
                            packRow(package)
                        }
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Packs de rubis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
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

    private var header: some View {
        VStack(spacing: 6) {
            Text("♦️")
                .font(.system(size: 44))
            Text("Solde actuel : \(progressStore.livresBalance) ♦️")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text("Les rubis servent à débloquer des leçons et des révisions en plus de ton quota gratuit du jour.")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 8)
    }

    private func packRow(_ package: Package) -> some View {
        let amount = StoreViewModel.livresPackAmounts[package.storeProduct.productIdentifier] ?? 0
        let isBest = amount == (StoreViewModel.livresPackAmounts.values.max() ?? 0)
        return Button {
            Haptics.medium()
            purchasingIdentifier = package.identifier
            Task {
                let granted = await store.purchaseLivresPack(package: package)
                if granted > 0 {
                    progressStore.addLivres(granted)
                    Haptics.success()
                }
                purchasingIdentifier = nil
            }
        } label: {
            HStack(spacing: 14) {
                Text("♦️")
                    .font(.system(size: 30))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Theme.livres.opacity(0.14)))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("\(amount) rubis")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        if isBest {
                            Text("MEILLEURE OFFRE")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Theme.success))
                        }
                    }
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                if purchasingIdentifier == package.identifier {
                    ProgressView().tint(Theme.livres)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .disabled(purchasingIdentifier != nil)
    }
}
