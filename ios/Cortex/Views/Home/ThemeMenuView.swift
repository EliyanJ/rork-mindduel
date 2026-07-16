import SwiftUI

/// Left-side drawer to pick the active path: the default mixed journey,
/// or a dedicated path gathering every question of one theme.
struct ThemeMenuView: View {
    @Environment(AppModel.self) private var model
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Parcours")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            Text("Choisis un thème dédié\nou mélange tout")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Theme.inkMuted)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 6) {
                    menuRow(
                        id: nil,
                        name: "Parcours mixte",
                        icon: "sparkles",
                        color: Theme.primary,
                        subtitle: "Tous les thèmes mélangés"
                    )

                    HStack(spacing: 10) {
                        Rectangle().fill(Theme.line).frame(height: 1.5)
                        Text("THÈMES")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.inkMuted)
                        Rectangle().fill(Theme.line).frame(height: 1.5)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)

                    ForEach(model.catalog.disciplines) { discipline in
                        menuRow(
                            id: discipline.id,
                            name: discipline.name,
                            icon: discipline.icon,
                            color: discipline.color,
                            subtitle: "\(questionCount(of: discipline)) questions"
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 300, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(
            UnevenRoundedRectangle(bottomTrailingRadius: 28, topTrailingRadius: 28)
                .fill(Theme.background)
                .shadow(color: .black.opacity(0.2), radius: 18, x: 6, y: 0)
                .ignoresSafeArea()
        )
    }

    private func questionCount(of discipline: Discipline) -> Int {
        discipline.chapters.reduce(0) { $0 + $1.questionCount }
    }

    private func menuRow(id: String?, name: String, icon: String, color: Color, subtitle: String) -> some View {
        let isSelected = model.selectedDisciplineId == id
        return Button {
            Haptics.tap()
            model.selectedDisciplineId = id
            onClose()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(color)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? color.opacity(0.14) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? color.opacity(0.45) : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
