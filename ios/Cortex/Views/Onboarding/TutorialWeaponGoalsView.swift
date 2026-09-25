import SwiftUI

/// An objective offered by the game. Pass real weapon identifiers and display names from the caller.
struct TutorialWeaponGoal: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
}

/// Lets the player choose exactly two goals; persistence and unlock rules belong to the caller.
struct TutorialWeaponGoalsView: View {
    let weapons: [TutorialWeaponGoal]
    let onConfirm: ([String]) -> Void
    @State private var selectedIDs: [String] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                TutorialScreenStyle.eyebrow("Tes prochains objectifs")
                TutorialScreenStyle.heading("Choisis tes deux armes.")
                Text("Celles que tu aimerais débloquer au fil de ton aventure.")
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                Text("\(selectedIDs.count) / 2 sélectionnées")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.primary)
                    .contentTransition(.numericText())
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(weapons) { weapon in
                        let chosen = selectedIDs.contains(weapon.id)
                        Button {
                            withAnimation(.spring(duration: 0.25)) {
                                if chosen {
                                    selectedIDs.removeAll { $0 == weapon.id }
                                } else if selectedIDs.count < 2 {
                                    selectedIDs.append(weapon.id)
                                }
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: weapon.symbol)
                                    .font(.system(size: 35, weight: .medium))
                                    .frame(height: 48)
                                Text(weapon.name)
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .multilineTextAlignment(.center)
                                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                            }
                            .foregroundStyle(chosen ? Theme.primary : Theme.ink)
                            .frame(maxWidth: .infinity)
                            .frame(height: 132)
                            .background(chosen ? TutorialScreenStyle.peach : .white, in: .rect(cornerRadius: 22))
                            .overlay { RoundedRectangle(cornerRadius: 22).stroke(chosen ? Theme.primary : Theme.line, lineWidth: chosen ? 2 : 1) }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(weapon.name), \(chosen ? "sélectionnée" : "non sélectionnée")")
                    }
                }
                Button("Découvrir mon profil") { onConfirm(selectedIDs) }
                    .buttonStyle(ChunkyButtonStyle())
                    .disabled(selectedIDs.count != 2)
                    .opacity(selectedIDs.count == 2 ? 1 : 0.5)
                    .padding(.top, 8)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background { TutorialScreenStyle.backdrop() }
    }
}

#Preview {
    TutorialWeaponGoalsView(weapons: [
        .init(id: "standard", name: "Standard", symbol: "scope"),
        .init(id: "sniper", name: "Sniper", symbol: "viewfinder"),
        .init(id: "machine", name: "Mitrailleuse", symbol: "bolt.fill"),
        .init(id: "bucket", name: "Lance-Seau", symbol: "drop.fill"),
        .init(id: "vacuum", name: "Aspirateur à eau", symbol: "wind"),
        .init(id: "spray", name: "Spray", symbol: "humidity.fill")
    ], onConfirm: { _ in })
}
