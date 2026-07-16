import SwiftUI

/// Duolingo-style chunky 3D button: raised face with a darker bottom edge
/// that "presses down" on touch.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
            )
            .offset(y: configuration.isPressed ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.mix(with: .black, by: 0.28))
                    .offset(y: 4)
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
