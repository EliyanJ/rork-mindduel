import SwiftUI

/// iOS top-edge padding aware of the device safe area. On modern phones with a
/// Dynamic Island, the natural safe area is large enough that we should not add
/// extra padding; on classic phones we add a small cushion. Use this for every
/// screen header so content is never clipped by the notch/status bar.
enum SafeTop {
    static let padding: CGFloat = 0
}

extension View {
    /// Adds a small, safe-area-aware top inset to a full-screen view.
    /// The safe area itself already accounts for the notch/Dynamic Island, so
    /// we only add the constant cushion here. This is the standard value used
    /// across Home, Profile, Review, Duel and onboarding screens.
    func safeTopPadding() -> some View {
        self.padding(.top, SafeTop.padding)
    }
}

/// Reads the top safe area inset from a geometry proxy so we can size or
/// position things that must avoid the notch / Dynamic Island.
struct TopSafeAreaInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var topSafeAreaInset: CGFloat {
        get { self[TopSafeAreaInsetKey.self] }
        set { self[TopSafeAreaInsetKey.self] = newValue }
    }
}
