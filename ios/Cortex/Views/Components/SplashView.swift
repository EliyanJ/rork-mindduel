import SwiftUI

/// Branded launch screen shown for a couple of seconds before the app
/// reveals itself — the logo settles in, holds, then flies off screen.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0
    @State private var underlineWidth: CGFloat = 0
    @State private var isExiting: Bool = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            OnboardingDecor(variant: 2)

            VStack(spacing: 18) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(.rect(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                VStack(spacing: 14) {
                    HStack(spacing: 2) {
                        Text("Min")
                            .foregroundStyle(Theme.ink)
                        Text("duel")
                            .foregroundStyle(Theme.primary)
                    }
                    .font(.system(size: 50, weight: .black, design: .rounded))

                    Capsule()
                        .fill(Theme.primary)
                        .frame(width: underlineWidth, height: 6)
                }
            }
            .scaleEffect(logoScale)
            .opacity(logoOpacity)
            .offset(y: isExiting ? -160 : 0)
            .rotationEffect(.degrees(isExiting ? -8 : 0))
        }
        .task {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                logoScale = 1
                logoOpacity = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.15)) {
                underlineWidth = 46
            }
            try? await Task.sleep(for: .seconds(1.05))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                isExiting = true
                logoScale = 1.12
            }
            try? await Task.sleep(for: .seconds(0.28))
            withAnimation(.easeOut(duration: 0.2)) {
                logoOpacity = 0
            }
            try? await Task.sleep(for: .seconds(0.2))
            onFinished()
        }
    }
}

#Preview {
    SplashView(onFinished: {})
}
