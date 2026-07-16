import SwiftUI

/// A single finger-drawn stroke, stored as a sequence of points.
private struct SignatureStroke {
    var points: [CGPoint]
}

/// Commitment step: the user reviews a short pledge checklist, then signs
/// with their finger on a small canvas — a tactile commitment device.
struct OnboardingCommitmentStep: View {
    let nickname: String
    @Binding var commitmentText: String
    let onNext: () -> Void

    @State private var strokes: [SignatureStroke] = []
    @State private var currentStroke: SignatureStroke?
    @State private var checklistVisible = [false, false, false]
    @State private var canvasVisible = false

    private var displayName: String {
        let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "toi" : trimmed
    }

    private let commitments = [
        ("🧠", "Apprendre un peu chaque jour"),
        ("💪", "Muscler ma culture générale"),
        ("🏆", "Grimper dans les classements")
    ]

    private var hasSignature: Bool {
        !strokes.isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 700
            let canvasHeight: CGFloat = compact ? 110 : 150
            let itemFont: CGFloat = compact ? 16 : 18
            let itemPadding: CGFloat = compact ? 14 : 18

            VStack(alignment: .leading, spacing: 0) {
                OnboardingHeaderText(
                    title: "Ton engagement",
                    emoji: "✍️",
                    subtitle: "À partir d'aujourd'hui, \(displayName), tu choisis de :"
                )
                .frame(height: compact ? 140 : 170)

                Spacer(minLength: compact ? 12 : 20)

                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    ForEach(Array(commitments.enumerated()), id: \.offset) { index, item in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary.opacity(0.15))
                                    .frame(width: 30, height: 30)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(Theme.primary)
                            }
                            Text(item.0)
                                .font(.system(size: 24))
                            Text(item.1)
                                .font(.system(size: itemFont, weight: .heavy, design: .rounded))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, itemPadding)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.line, lineWidth: 1.5))
                        .opacity(checklistVisible[index] ? 1 : 0)
                        .offset(x: checklistVisible[index] ? 0 : -18)
                    }
                }

                Spacer(minLength: compact ? 12 : 20)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ta signature")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.inkMuted)
                        Spacer()
                        Button("Effacer") {
                            Haptics.tap()
                            withAnimation(.easeOut(duration: 0.2)) {
                                strokes = []
                                currentStroke = nil
                            }
                        }
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.primary)
                        .opacity(hasSignature ? 1 : 0)
                        .disabled(!hasSignature)
                    }

                    signatureCanvas(height: canvasHeight)
                }
                .opacity(canvasVisible ? 1 : 0)
                .offset(y: canvasVisible ? 0 : 14)

                Button("Je signe et je m'engage") {
                    Haptics.success()
                    commitmentText = displayName
                    onNext()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.ink, textColor: Theme.gold))
                .disabled(!hasSignature)
                .opacity(hasSignature ? 1 : 0.4)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasSignature)
                .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, compact ? 4 : 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                ZStack {
                    Theme.background
                    OnboardingDecor(variant: 1)
                }
            )
            .onAppear {
                for index in checklistVisible.indices {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(Double(index) * 0.12)) {
                        checklistVisible[index] = true
                    }
                }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(Double(checklistVisible.count) * 0.12 + 0.1)) {
                    canvasVisible = true
                }
            }
        }
    }

    private func signatureCanvas(height: CGFloat) -> some View {
        Canvas { context, size in
            for stroke in strokes + (currentStroke.map { [$0] } ?? []) {
                guard stroke.points.count > 1 else { continue }
                var path = Path()
                path.move(to: stroke.points[0])
                for point in stroke.points.dropFirst() {
                    path.addLine(to: point)
                }
                context.stroke(path, with: .color(Theme.ink), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(hasSignature ? Theme.primary : Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: hasSignature ? [] : [6, 6]))
        )
        .overlay {
            if !hasSignature {
                VStack(spacing: 6) {
                    Image(systemName: "signature")
                        .font(.system(size: 20))
                    Text("Signe ici avec ton doigt")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Theme.inkMuted.opacity(0.6))
                .allowsHitTesting(false)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if currentStroke == nil {
                        currentStroke = SignatureStroke(points: [value.location])
                    } else {
                        currentStroke?.points.append(value.location)
                    }
                }
                .onEnded { _ in
                    if let stroke = currentStroke, stroke.points.count > 1 {
                        strokes.append(stroke)
                        Haptics.tap()
                    }
                    currentStroke = nil
                }
        )
    }
}

#Preview {
    OnboardingCommitmentStep(nickname: "Alex", commitmentText: .constant(""), onNext: {})
}
