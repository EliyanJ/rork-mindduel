import SwiftUI

/// "Solde" line used by the refill sheets: diamond icon + current balance.
struct DiamondBalance: View {
    let amount: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("Solde :")
                .foregroundStyle(Theme.inkMuted)
            Image(systemName: "diamond.fill")
                .foregroundStyle(Theme.livres)
            Text("\(amount)")
                .foregroundStyle(Theme.livres)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.system(.headline, design: .rounded, weight: .heavy))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Solde : \(amount) diamants")
    }
}
