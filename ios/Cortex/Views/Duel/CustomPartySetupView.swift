import SwiftUI

/// One flexible mode instead of a pile of fixed formats: pick how many
/// teammates and opponents you want, then either open a fresh room (sharing
/// a code with friends) or hop into a friend's room using their code.
struct CustomPartySetupView: View {
    let onStart: (PartySession.Origin) -> Void

    @State private var mode: SetupMode = .create
    @State private var allies: Int = 1
    @State private var opponents: Int = 3
    @State private var joinCode: String = ""
    @Environment(\.dismiss) private var dismiss

    private enum SetupMode: String, CaseIterable, Identifiable {
        case create = "Créer"
        case join = "Rejoindre"
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Picker("Mode", selection: $mode) {
                    ForEach(SetupMode.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                switch mode {
                case .create:
                    createBody
                case .join:
                    joinBody
                }

                Spacer()

                Button(mode == .create ? "Créer la partie" : "Rejoindre") {
                    Haptics.medium()
                    switch mode {
                    case .create:
                        onStart(.customHost(allies: allies, opponents: opponents))
                    case .join:
                        let code = joinCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard !code.isEmpty else { return }
                        onStart(.customJoin(roomCode: code))
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
                .disabled(mode == .join && joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(mode == .join && joinCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .padding(.top, 4)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Partie personnalisée")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
    }

    private var createBody: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("\(allies + 1) vs \(opponents)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.duelAccent)
                    .contentTransition(.numericText())
                Text("Toi + tes alliés contre l'équipe adverse")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.inkMuted)
            }
            .padding(.top, 8)

            counterRow(title: "Alliés (en plus de toi)", value: $allies, range: 0...9)
            counterRow(title: "Adversaires", value: $opponents, range: 1...19)

            Text("Une fois créée, partage le code avec tes amis pour qu'ils te rejoignent. Les places encore vides sont comblées par des bots quand tu démarres.")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.horizontal, 16)
    }

    private var joinBody: some View {
        VStack(spacing: 16) {
            Text("Entre le code que ton ami t'a partagé")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .padding(.top, 24)
            TextField("Ex. K7QX2", text: $joinCode)
                .font(.system(size: 28, weight: .heavy, design: .monospaced))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.card))
                .padding(.horizontal, 32)
        }
    }

    private func counterRow(title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            HStack(spacing: 16) {
                stepperButton(icon: "minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - 1)
                }
                Text("\(value.wrappedValue)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 28)
                    .contentTransition(.numericText())
                stepperButton(icon: "plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + 1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
    }

    private func stepperButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.spring(duration: 0.2)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.duelAccent)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Theme.duelAccent.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}
