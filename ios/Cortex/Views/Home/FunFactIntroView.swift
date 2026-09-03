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

/// Pre-quiz revision sheet: a themed illustration plus a handful of
/// swipeable cards distilled from the ring's real questions, shown before
/// the mini quiz starts. Matches the app's airy, light aesthetic — the
/// accent color is the only thing that shifts per discipline.
struct FunFactIntroView: View {
    let discipline: Discipline
    let cards: [StudyCard]
    let onStart: () -> Void
    let onClose: () -> Void

    @State private var hasAppeared = false
    @State private var pageIndex = 0

    private var accent: Color { discipline.color }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.16))

                illustration
                    .padding(.top, 20)
                    .padding(.horizontal, 20)

                Text("À retenir avant de jouer")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)

                TabView(selection: $pageIndex) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        StudyCardView(card: card, accent: accent)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 10)

                if cards.count > 1 {
                    pageDots
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                }

                actions
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Haptics.tap()
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.05)) {
                hasAppeared = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Fiche de révision")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(accent))
            .padding(.trailing, 40)

            Text(discipline.name)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
        }
    }

    private var illustration: some View {
        Theme.canvas
            .frame(height: 150)
            .overlay {
                if let assetName = ThemeIllustration.assetName(for: discipline.id),
                   let uiImage = UIImage(named: assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(accent)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.96)
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(cards.indices, id: \.self) { index in
                Circle()
                    .fill(index == pageIndex ? accent : Theme.line)
                    .frame(width: index == pageIndex ? 8 : 6, height: index == pageIndex ? 8 : 6)
                    .animation(.easeOut(duration: 0.2), value: pageIndex)
            }
        }
    }

    private var actions: some View {
        Button {
            Haptics.medium()
            onStart()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                Text("Mini quiz")
            }
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 18).fill(Theme.gold))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.ink.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// One page of the revision carousel: a short bullet list of hints drawn
/// from the ring's actual question explanations.
private struct StudyCardView: View {
    let card: StudyCard
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(card.points) { point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(accent)
                        .padding(.top, 1)
                    Text(point.text)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.line, lineWidth: 1.5))
    }
}
