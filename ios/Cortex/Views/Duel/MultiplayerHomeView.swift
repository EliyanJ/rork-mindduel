import SwiftUI

/// Entry screen for the two party formats (10 vs 10 teams, 1 vs 19 individual
/// ranking), reached from the Duel tab. The existing ranked 1v1 duel is shown
/// dimmed underneath purely to place these new modes in context.
struct MultiplayerHomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss
    @State private var pendingMode: PartyMode?
    @State private var isSignInPresented: Bool = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Choisis ton format de compétition")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        modeCard(
                            mode: .team10,
                            icon: "person.3.fill",
                            iconColor: Color(hex: "22D3C5"),
                            title: "10 vs 10",
                            subtitle: "Équipes · score cumulé"
                        )
                        modeCard(
                            mode: .solo,
                            icon: "trophy.fill",
                            iconColor: Theme.gold,
                            title: "1 vs 19",
                            subtitle: "Classement individuel"
                        )
                        duelCard
                    }
                    .padding(16)
                    .padding(.bottom, 32)
                }
            }
            .background(Theme.background)
            .navigationBarHidden(true)
        }
        .fullScreenCover(item: $pendingMode) { mode in
            PartyLobbyView(catalog: model.catalog, store: model.store, online: online, mode: mode)
        }
        .sheet(isPresented: $isSignInPresented) {
            SignInSheet()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.card))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1.5))
            }
            Text("Multijoueur")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func modeCard(mode: PartyMode, icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(iconColor)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(iconColor.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                        Text(subtitle)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                Spacer()
                Text("3 MANCHES")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(iconColor.mix(with: .black, by: 0.15))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(iconColor.opacity(0.14)))
            }
            HStack(spacing: 8) {
                tag(text: "vote rapide", icon: "bolt.fill")
                tag(text: "thème imposé", icon: "shuffle")
            }
            Button {
                Haptics.medium()
                joinLobby(mode)
            } label: {
                Label("Rejoindre un lobby", systemImage: "person.2.wave.2.fill")
            }
            .buttonStyle(ChunkyButtonStyle(color: iconColor, textColor: .white))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.line, lineWidth: 1.5))
    }

    private func tag(text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(.caption, design: .rounded, weight: .bold))
        }
        .foregroundStyle(Theme.inkMuted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.background))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1.25))
    }

    /// The existing 1v1 mode, dimmed here purely to place the new formats.
    private var duelCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.line.opacity(0.5)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Duel 1v1")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                Text("Le mode classé habituel")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted.opacity(0.7))
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        .opacity(0.55)
    }

    private func joinLobby(_ mode: PartyMode) {
        guard online.isSignedIn else {
            isSignInPresented = true
            return
        }
        pendingMode = mode
    }
}

extension PartyMode: Identifiable {
    public var id: String { rawValue }
}
