import SwiftUI

/// Duolingo-style chunky 3D button: raised face with a darker bottom edge
/// that "presses down" on touch.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.primary
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color)
            )
            .offset(y: configuration.isPressed ? 5 : 0)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.mix(with: .black, by: 0.28))
                    .offset(y: 5)
            )
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}
