import SwiftUI

/// Bottom sheet that lets the player pick a discipline (or "All") before
/// starting a ranked duel or training match.
struct DuelThemePickerView: View {
    let catalog: ContentCatalog
    @Binding var selectedId: String?
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Choisis ton thème")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                        .padding(.top, 8)

                    Text("Si ton adversaire choisit un autre thème, le duel mélangera les deux")
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.bottom, 8)

                    themeCard(
                        id: nil,
                        name: "Tous les thèmes",
                        icon: "shuffle.fill",
                        colorHex: "#868E96",
                        subtitle: "Questions de toutes les disciplines"
                    )

                    ForEach(catalog.disciplines, id: \.id) { discipline in
                        let count = discipline.chapters.reduce(0) { $0 + $1.questionCount }
                        themeCard(
                            id: discipline.id,
                            name: discipline.name,
                            icon: discipline.icon,
                            colorHex: discipline.colorHex,
                            subtitle: "\(count) questions"
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Confirmer") {
                        Haptics.medium()
                        onConfirm()
                    }
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primary)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") {
                        selectedId = nil
                        onConfirm()
                    }
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                }
            }
        }
    }

    private func themeCard(id: String?, name: String, icon: String, colorHex: String, subtitle: String) -> some View {
        let isSelected = selectedId == id
        let color = Color(hex: colorHex)
        return Button {
            Haptics.tap()
            selectedId = id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14).fill(color))

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.inkMuted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isSelected ? Theme.primary : Theme.inkMuted.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2.5 : 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
