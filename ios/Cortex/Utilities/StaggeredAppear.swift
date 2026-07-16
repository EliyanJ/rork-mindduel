import SwiftUI

/// Fades + slides a view in shortly after it appears, optionally delayed —
/// used to stagger a list of elements in so they feel alive instead of
/// popping in all at once.
private struct StaggeredAppear: ViewModifier {
    let index: Int
    let baseDelay: Double

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.94)
            .offset(y: isVisible ? 0 : 14)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(baseDelay + Double(index) * 0.08)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Apply a smooth staggered entrance animation. `index` controls the
    /// stagger order (0 = first), `delay` adds a shared base offset.
    func staggeredAppear(_ index: Int, delay: Double = 0.05) -> some View {
        modifier(StaggeredAppear(index: index, baseDelay: delay))
    }
}
