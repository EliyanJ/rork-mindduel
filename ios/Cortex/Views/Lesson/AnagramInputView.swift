import SwiftUI

/// Letter-tile input: tap tiles to build the word, backspace to undo.
struct AnagramInputView: View {
    let letters: [Character]
    @Binding var selection: String
    let locked: Bool

    @State private var pickedIndices: [Int] = []

    var body: some View {
        VStack(spacing: 24) {
            assembledWord
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48), spacing: 10)], spacing: 10) {
                ForEach(letters.indices, id: \.self) { index in
                    tile(at: index)
                }
            }
            if !pickedIndices.isEmpty && !locked {
                Button {
                    Haptics.tap()
                    pickedIndices.removeLast()
                    syncSelection()
                } label: {
                    Label("Effacer", systemImage: "delete.left.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var assembledWord: some View {
        let assembled = pickedIndices.map { String(letters[$0]) }.joined()
        let placeholders = String(repeating: "•", count: max(0, letters.count - pickedIndices.count))
        return (Text(assembled).foregroundStyle(Theme.ink)
                + Text(placeholders).foregroundStyle(Theme.line))
            .font(.system(size: 32, weight: .heavy, design: .rounded))
            .tracking(5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 2))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }

    private func tile(at index: Int) -> some View {
        let isUsed = pickedIndices.contains(index)
        return Button {
            guard !locked, !isUsed else { return }
            Haptics.tap()
            pickedIndices.append(index)
            syncSelection()
        } label: {
            Text(String(letters[index]))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(isUsed ? Theme.line : Theme.ink)
                .frame(width: 48, height: 54)
                .background(RoundedRectangle(cornerRadius: 12).fill(isUsed ? Theme.background : Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(locked || isUsed)
        .animation(.easeOut(duration: 0.12), value: isUsed)
    }

    private func syncSelection() {
        selection = pickedIndices.count == letters.count
            ? pickedIndices.map { String(letters[$0]) }.joined()
            : ""
    }
}
