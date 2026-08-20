import SwiftUI

/// Full "build your avatar" screen: a live preview up top, then either a
/// face-part picker (skin tone, eyes, mouth, background) or a big emoji grid
/// to swap the whole face for a fun stand-in (an octopus, a robot...).
struct AvatarEditorView: View {
    let store: AvatarStore
    let onDone: () -> Void

    @State private var draft: AvatarConfig

    init(store: AvatarStore, onDone: @escaping () -> Void) {
        self.store = store
        self.onDone = onDone
        _draft = State(initialValue: store.config)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    AvatarView(config: draft, size: 132)
                        .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
                        .padding(.top, 12)

                    Picker("Mode", selection: $draft.mode) {
                        Text("Visage").tag(AvatarMode.face)
                        Text("Emoji").tag(AvatarMode.emoji)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)

                    if draft.mode == .face {
                        faceEditor
                    } else {
                        emojiGrid
                    }

                    backgroundPicker
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

    private var faceEditor: some View {
        VStack(alignment: .leading, spacing: 22) {
            section("Teint") {
                HStack(spacing: 12) {
                    ForEach(AvatarSkinTone.allCases) { tone in
                        Circle()
                            .fill(tone.color)
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(draft.skinTone == tone ? Theme.primary : .clear, lineWidth: 3))
                            .onTapGesture {
                                Haptics.tap()
                                draft.skinTone = tone
                            }
                    }
                }
            }
            section("Yeux") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(AvatarEyeStyle.allCases) { style in
                        pickerTile(isSelected: draft.eyeStyle == style) {
                            Image(systemName: style.symbol)
                                .font(.system(size: 16, weight: .bold))
                        } action: {
                            draft.eyeStyle = style
                        }
                    }
                }
            }
            section("Bouche") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(AvatarMouthStyle.allCases) { style in
                        pickerTile(isSelected: draft.mouthStyle == style) {
                            Text(mouthEmoji(style)).font(.system(size: 18))
                        } action: {
                            draft.mouthStyle = style
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
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

    private func mouthEmoji(_ style: AvatarMouthStyle) -> String {
        switch style {
        case .smile: return "🙂"
        case .grin: return "😁"
        case .surprised: return "😮"
        case .cool: return "😎"
        case .shy: return "☺️"
        case .laugh: return "😂"
        }
    }
}
