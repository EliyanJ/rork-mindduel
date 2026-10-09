import SwiftUI

/// Illustration asset name per discipline, generated once and reused for
/// every ring belonging to that discipline.
private enum ThemeIllustration {
    private static let assetNames: [String: String] = [
        "histoire": "temple_scroll_column",
        "sciences": "lab_flask_atom",
        "geographie": "globe_location_pin",
        "litterature": "book_quill_pen",
        "arts": "palette_brush_note",
        "nature": "tree_bird_sticker",
        "technologie": "rocket_satellite",
        "football": "soccer_ball_trophy_2"
    ]

    static func assetName(for disciplineId: String) -> String? {
        assetNames[disciplineId]
    }
}

/// Pre-quiz reading: one single page that grows paragraph by paragraph.
/// A gauge on top, the theme illustration, then each tap on "Continuer"
/// reveals the next key fact under the previous ones (and scrolls to it),
/// so the player reads at their own pace without facing a wall of text.
/// Once everything is read, the button starts the quiz.
struct FunFactIntroView: View {
    let discipline: Discipline
    let cards: [StudyCard]
    let onStart: () -> Void
    let onClose: () -> Void

    @State private var revealedCount: Int = 1
    @State private var hasAppeared: Bool = false

    private var accent: Color { discipline.color }
    private var points: [StudyPoint] { cards.flatMap(\.points) }
    private var isFullyRead: Bool { revealedCount >= points.count }
    private var progress: Double {
        guard !points.isEmpty else { return 1 }
        return Double(revealedCount) / Double(points.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        illustration
                        Text("À retenir avant le quiz")
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.top, 22)
                            .padding(.bottom, 6)
                        Text(discipline.name)
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                            .foregroundStyle(accent)
                            .padding(.bottom, 18)
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(Array(points.prefix(revealedCount).enumerated()), id: \.element.id) { index, point in
                                FactParagraph(text: point.text, number: index + 1, accent: accent, isLatest: index == revealedCount - 1)
                                    .id(point.id)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .offset(y: 14)),
                                        removal: .opacity
                                    ))
                            }
                        }
                        Color.clear.frame(height: 24).id("bottom")
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
                .onChange(of: revealedCount) { _, _ in
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            continueButton
        }
        .background(Theme.background.ignoresSafeArea())
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { hasAppeared = true }
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Fermer")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule()
                        .fill(Theme.success)
                        .frame(width: max(16, geo.size.width * progress))
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.3))
                                .frame(height: 4)
                                .padding(.horizontal, 8)
                                .padding(.top, 3)
                        }
                }
            }
            .frame(height: 16)
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progress)
            .accessibilityLabel("Lecture \(revealedCount) sur \(points.count)")
        }
        .padding(.leading, 8)
        .padding(.trailing, 20)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private var illustration: some View {
        Theme.canvas
            .frame(height: 170)
            .overlay {
                RemoteThemeImage(urlString: discipline.imageUrl) {
                    bundledIllustration
                }
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
    }

    @ViewBuilder
    private var bundledIllustration: some View {
        if let assetName = ThemeIllustration.assetName(for: discipline.id),
           let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image(systemName: discipline.icon)
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private var continueButton: some View {
        Button(isFullyRead ? "C'EST PARTI POUR LE QUIZ" : "CONTINUER") {
            if isFullyRead {
                Haptics.medium()
                onStart()
            } else {
                Haptics.tap()
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    revealedCount += 1
                }
            }
        }
        .buttonStyle(ChunkyButtonStyle(color: isFullyRead ? Theme.success : Theme.link, textColor: .white))
        .animation(.easeOut(duration: 0.2), value: isFullyRead)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.line).frame(height: 1.5)
        }
    }
}

/// One key fact of the reading: a numbered dot and roomy body text. The
/// newest paragraph is fully inked, earlier ones soften slightly so the eye
/// lands on what just appeared.
private struct FactParagraph: View {
    let text: String
    let number: Int
    let accent: Color
    let isLatest: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(accent))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 19, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(isLatest ? 1 : 0.72)
        .animation(.easeOut(duration: 0.3), value: isLatest)
    }
}
