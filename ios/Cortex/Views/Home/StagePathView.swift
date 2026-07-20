import SwiftUI

/// Duolingo-like zigzag path for the unified journey:
/// one single track whose stages each mix questions from several themes.
struct StagePathView: View {
    @Environment(AppModel.self) private var model
    let onSelect: (PathStage) -> Void

    @State private var pathWidth: CGFloat = 360

    var body: some View {
        VStack(spacing: 0) {
            ForEach(model.stages) { stage in
                if stage.index > 0 {
                    connector
                }
                StageNodeView(
                    stage: stage,
                    state: model.state(of: stage),
                    color: model.selectedDiscipline?.color ?? Theme.stageColor(stage.index),
                    record: model.store.progress.chapterRecords[stage.id],
                    disciplines: stage.disciplineIds.compactMap { model.discipline(withId: $0) },
                    isMixedPath: model.selectedDiscipline == nil
                ) {
                    onSelect(stage)
                }
                .offset(x: horizontalOffset(for: stage.index, width: pathWidth))
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            pathWidth = newWidth
        }
    }

    private var connector: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(Theme.line)
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.vertical, 10)
    }

    private func horizontalOffset(for index: Int, width: CGFloat) -> CGFloat {
        let step = min(width * 0.22, 72)
        let pattern: [CGFloat] = [0, -step, 0, step]
        return pattern[index % pattern.count]
    }
}

struct StageNodeView: View {
    let stage: PathStage
    let state: ChapterState
    let color: Color
    let record: ChapterRecord?
    let disciplines: [Discipline]
    /// True when this node belongs to the default mixed path (multiple themes per lesson).
    var isMixedPath: Bool = false
    let action: () -> Void

    @State private var isPulsing: Bool = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    if state == .available {
                        Circle()
                            .stroke(color.opacity(0.35), lineWidth: 4)
                            .frame(width: 96, height: 96)
                            .scaleEffect(isPulsing ? 1.05 : 0.94)
                    }
                    Circle()
                        .fill(fillColor.mix(with: .black, by: 0.25))
                        .frame(width: 78, height: 78)
                        .offset(y: 5)
                    Circle()
                        .fill(fillColor)
                        .frame(width: 78, height: 78)
                    Image(systemName: iconName)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                .frame(height: 96)
                Text(stage.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(state == .locked ? Theme.inkMuted : Theme.ink)
                    .multilineTextAlignment(.center)
                    .frame(width: 160)
                if isMixedPath {
                    HStack(spacing: 4) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 10, weight: .bold))
                        Text("Thèmes mélangés")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                    }
                    .foregroundStyle(state == .locked ? Theme.inkMuted : color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(state == .locked ? Theme.lockedFill : color.opacity(0.12))
                    )
                }
                themeIcons
                if let record {
                    Text("\(Int(record.bestScore * 100)) % maîtrisé")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(record.bestScore >= 0.8 ? Theme.gold.mix(with: .black, by: 0.15) : Theme.inkMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(state == .locked)
        .onAppear {
            guard state == .available else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    /// Small badges showing which themes are mixed into this stage.
    private var themeIcons: some View {
        HStack(spacing: 5) {
            ForEach(disciplines.prefix(5)) { discipline in
                Image(systemName: discipline.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(state == .locked ? Theme.inkMuted : .white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(state == .locked ? Theme.lockedFill : discipline.color))
            }
            if disciplines.count > 5 {
                Text("+\(disciplines.count - 5)")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .opacity(state == .locked ? 0.6 : 1)
    }

    private var fillColor: Color {
        switch state {
        case .locked: return Theme.lockedFill
        case .available, .completed: return color
        case .mastered: return Theme.gold
        }
    }

    private var iconName: String {
        switch state {
        case .locked: return "lock.fill"
        case .available: return "star.fill"
        case .completed: return "book.fill"
        case .mastered: return "crown.fill"
        }
    }

    private var iconColor: Color {
        state == .locked ? Theme.inkMuted : .white
    }
}
