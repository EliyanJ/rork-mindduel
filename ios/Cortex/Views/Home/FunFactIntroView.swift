import SwiftUI

/// Illustration asset name per discipline, generated once and reused for
/// every fact belonging to that discipline.
private enum FunFactIllustration {
    static func assetName(for disciplineId: String) -> String {
        "theme_illustration_\(disciplineId)"
    }
}

/// Pre-quiz teaser screen: a themed "did you know" fact with its
/// illustration, shown before a ring's mini quiz starts. Matches the app's
/// airy, light aesthetic — the accent color is the only thing that shifts
/// per discipline.
struct FunFactIntroView: View {
    let discipline: Discipline
    let fact: FunFact
    let onStart: () -> Void
    let onClose: () -> Void

    @State private var hasAppeared = false

    private var accent: Color { discipline.color }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accent.opacity(0.16))

                ScrollView {
                    VStack(spacing: 20) {
                        illustration
                            .padding(.top, 22)

                        Text(fact.body)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                    }
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                }
                .scrollIndicators(.hidden)

                actions
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
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
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .bold))
                Text("Le saviez-vous ?")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(0.4)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(accent))
            .padding(.trailing, 40)

            Text(fact.hook)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
        }
    }

    private var illustration: some View {
        Theme.canvas
            .frame(height: 200)
            .overlay {
                if let uiImage = UIImage(named: FunFactIllustration.assetName(for: discipline.id)) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .allowsHitTesting(false)
                } else {
                    Image(systemName: discipline.icon)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(accent)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(.rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
            .padding(.horizontal, 20)
            .opacity(hasAppeared ? 1 : 0)
            .scaleEffect(hasAppeared ? 1 : 0.96)
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
