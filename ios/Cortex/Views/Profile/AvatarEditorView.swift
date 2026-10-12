import SwiftUI

/// Avatar picker: a live preview up top, then either the hand-drawn
/// characters or a big emoji grid (with a background colour).
struct AvatarEditorView: View {
    let store: AvatarStore
    let onDone: () -> Void

    @State private var draft: AvatarConfig

    init(store: AvatarStore, onDone: @escaping () -> Void) {
        self.store = store
        self.onDone = onDone
        _draft = State(initialValue: store.config.normalized)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    AvatarView(config: draft, size: 132)
                        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                        .padding(.top, 12)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: draft)

                    Picker("Mode", selection: $draft.mode) {
                        Text("Persos").tag(AvatarMode.illustration)
                        Text("Emoji").tag(AvatarMode.emoji)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    switch draft.mode {
                    case .illustration:
                        illustrationGrid
                    case .emoji, .face:
                        emojiGrid
                    }

                    if draft.mode == .emoji {
                        backgroundPicker
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("Ton avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Haptics.medium()
                        store.save(draft)
                        onDone()
                    }
                    .fontWeight(.heavy)
                }
            }
        }
    }

    private var illustrationGrid: some View {
        section("Choisis ton perso") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(AvatarIllustration.all) { item in
                    IllustrationTile(
                        imageName: item.imageName,
                        isSelected: draft.mode == .illustration && draft.illustrationId == item.id
                    ) {
                        Haptics.tap()
                        draft.illustrationId = item.id
                        draft.mode = .illustration
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .onAppear {
            if draft.illustrationId == nil {
                draft.illustrationId = AvatarIllustration.all.first?.id
            }
        }
    }

    private var emojiGrid: some View {
        section("Choisis un emoji") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(AvatarConfig.emojiChoices, id: \.self) { emoji in
                    pickerTile(isSelected: draft.emoji == emoji && draft.mode == .emoji) {
                        Text(emoji).font(.system(size: 26))
                    } action: {
                        draft.emoji = emoji
                        draft.mode = .emoji
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var backgroundPicker: some View {
        section("Fond") {
            HStack(spacing: 12) {
                ForEach(AvatarConfig.backgroundChoices, id: \.self) { hex in
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(draft.backgroundColorHex == hex ? Theme.primary : Theme.line, lineWidth: draft.backgroundColorHex == hex ? 3 : 1.5))
                        .onTapGesture {
                            Haptics.tap()
                            draft.backgroundColorHex = hex
                        }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Theme.inkMuted)
            content()
        }
    }

    private func pickerTile<Content: View>(isSelected: Bool, @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            content()
                .foregroundStyle(isSelected ? Theme.primary : Theme.ink)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12).fill(isSelected ? Theme.primary.opacity(0.14) : Theme.canvas))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

/// One kawaii portrait in the picker grid: square art, orange ring and a
/// check badge when chosen, with a small pop on selection.
private struct IllustrationTile: View {
    let imageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                        .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Theme.primary : Theme.line, lineWidth: isSelected ? 4 : 1.5)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Theme.primary)
                            .padding(6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(isSelected ? 1.04 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
