import SwiftUI

/// Lets the player pick a new nickname from the profile screen. The first
/// `ProgressStore.freeNicknameChanges` renames are free; every one after
/// that costs rubis, with a clear "not enough" state instead of a silent
/// failure.
struct RenameNicknameSheet: View {
    let currentName: String
    let changesUsed: Int
    let store: ProgressStore
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var draft: String = ""
    @Environment(\.dismiss) private var dismiss

    private var remainingFree: Int { max(0, ProgressStore.freeNicknameChanges - changesUsed) }
    private var cost: Int { remainingFree > 0 ? 0 : ProgressStore.nicknameChangeCost }
    private var canAfford: Bool { cost == 0 || store.livresBalance >= cost }
    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isValid: Bool { (2...16).contains(trimmed.count) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                VStack(spacing: 6) {
                    Text("Nouveau pseudo")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(costLabel)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(cost > 0 ? Theme.livres : Theme.inkMuted)
                }
                .padding(.top, 12)

                TextField("Ton pseudo", text: $draft)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.canvas))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1.5))
                    .padding(.horizontal, 24)

                if cost > 0 && !canAfford {
                    Text("Solde insuffisant — gagne des rubis en jouant ou en maintenant ta série.")
                        .font(.system(.footnote, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()

                Button {
                    guard isValid else { return }
                    if cost > 0 {
                        guard store.spendLivres(cost) else { return }
                    }
                    Haptics.success()
                    onSave(trimmed)
                } label: {
                    Text(cost > 0 ? "Valider (\(cost) rubis)" : "Valider")
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary, textColor: .white))
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .disabled(!isValid || (cost > 0 && !canAfford))
                .opacity((!isValid || (cost > 0 && !canAfford)) ? 0.5 : 1)
            }
            .background(Theme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
            }
            .onAppear { draft = currentName }
        }
    }

    private var costLabel: String {
        if cost == 0 {
            return "\(remainingFree) changement\(remainingFree > 1 ? "s" : "") gratuit\(remainingFree > 1 ? "s" : "") restant\(remainingFree > 1 ? "s" : "")"
        }
        return "Coûte \(cost) rubis (tu as \(store.livresBalance) rubis)"
    }
}
