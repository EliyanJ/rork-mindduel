import SwiftUI

/// Every destination reachable from the fixed bottom bar. `.plus` hosts the
/// profile and opens the "more" menu (profile, friends, settings…).
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case parcours, duel, classement, actus, premium, plus

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .parcours: return "house.fill"
        case .duel: return "bolt.fill"
        case .classement: return "trophy.fill"
        case .actus: return "newspaper.fill"
        case .premium: return "crown.fill"
        case .plus: return "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .parcours: return Theme.primary
        case .duel: return Color(hex: "14B8AB")
        case .classement: return Color(hex: "C68A4A")
        case .actus: return Color(hex: "FF3D8A")
        case .premium: return Color(hex: "F2B400")
        case .plus: return Color(hex: "9B4DFF")
        }
    }

    var accessibilityName: String {
        switch self {
        case .parcours: return "Parcours"
        case .duel: return "Duel"
        case .classement: return "Classement"
        case .actus: return "Fil d'actualité"
        case .premium: return "Premium"
        case .plus: return "Plus"
        }
    }
}

/// Fixed, opaque bottom bar in the Duolingo spirit: colourful icons only, the
/// active one framed in a tinted rounded square.
struct MainTabBar: View {
    let selected: AppTab
    let isMoreMenuOpen: Bool
    let plusBadge: Int
    let onSelect: (AppTab) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.line)
                .frame(height: 1.5)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    item(tab)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 4)
        }
        .background(Theme.background.ignoresSafeArea(edges: .bottom))
    }

    private func item(_ tab: AppTab) -> some View {
        let isActive = tab == .plus ? (selected == .plus || isMoreMenuOpen) : (selected == tab && !isMoreMenuOpen)
        return Button {
            onSelect(tab)
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 23, weight: .bold))
                .foregroundStyle(tab.color)
                .symbolEffect(.bounce, value: isActive)
                .frame(width: 46, height: 42)
                .background {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(isActive ? tab.color.opacity(0.12) : .clear)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isActive ? tab.color.opacity(0.6) : .clear, lineWidth: 2)
                }
                .overlay(alignment: .topTrailing) {
                    if tab == .plus && plusBadge > 0 {
                        Circle()
                            .fill(Theme.danger)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Theme.card, lineWidth: 2))
                            .offset(x: -4, y: 4)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(Rectangle())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.accessibilityName)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// Pop-up list above the bar opened by the "…" button: everything about the
/// player's profile and the app settings in one place.
struct MoreMenuPanel: View {
    let incomingRequests: Int
    let onProfile: () -> Void
    let onFriends: () -> Void
    let onQRCode: () -> Void
    let onSettings: () -> Void
    let onSupport: () -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
                .accessibilityLabel("Fermer le menu")
                .accessibilityAddTraits(.isButton)
            VStack(spacing: 0) {
                row(icon: "person.crop.circle.fill", color: Color(hex: "1CB0F6"), title: "Profil", action: onProfile)
                divider
                row(icon: "person.2.fill", color: Theme.success, title: "Amis", badge: incomingRequests, action: onFriends)
                divider
                row(icon: "qrcode", color: Theme.ink, title: "Mon code ami", action: onQRCode)
                divider
                row(icon: "gearshape.fill", color: Theme.inkMuted, title: "Réglages", action: onSettings)
                divider
                row(icon: "questionmark.circle.fill", color: Theme.primary, title: "Aide et support", action: onSupport)
            }
            .background(Theme.background)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
            .shadow(color: .black.opacity(0.12), radius: 16, y: -4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 1.5)
    }

    private func row(icon: String, color: Color, title: String, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 18) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 36)
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(Circle().fill(Theme.danger))
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted.opacity(0.6))
            }
            .padding(.horizontal, 24)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
