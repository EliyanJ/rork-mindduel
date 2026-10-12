import SwiftUI

/// Waiting room shown while a party lobby fills up. Polls the server through
/// `PartySession`, which hands back the live member grid; once the ticket
/// arrives (real players + bots, decided server-side) this same view runs
/// the 3-2-1 countdown then hands off to `PartyMatchView`.
struct PartyLobbyView: View {
    let catalog: ContentCatalog
    let store: ProgressStore
    let online: OnlineModel
    let origin: PartySession.Origin

    @State private var session: PartySession?
    @Environment(\.dismiss) private var dismiss
    @Environment(AvatarStore.self) private var avatarStore: AvatarStore?

    var body: some View {
        ZStack {
            Theme.quizBackground.ignoresSafeArea()
            if let session, session.requiresUpdate {
                UpdateRequiredView(isPartyOnly: true, onDismiss: { dismiss() })
            } else if let session {
                content(session)
            } else {
                ProgressView().tint(Theme.duelAccent)
            }
        }
        .task {
            let s = PartySession(catalog: catalog, store: store, online: online, origin: origin)
            session = s
            s.start()
        }
        .onDisappear { session?.cancel() }
    }

    @ViewBuilder
    private func content(_ session: PartySession) -> some View {
        switch session.phase {
        case .queued, .connecting:
            waitingBody(session)
        case .countdown:
            PartyCountdownStage()
        case .cancelled(let reason):
            statusBody(icon: "xmark.circle.fill", color: Theme.danger, title: "Partie annulée", message: reason)
        case .failed(let reason):
            statusBody(icon: "wifi.exclamationmark", color: Theme.danger, title: "Connexion impossible", message: reason)
        default:
            PartyMatchView(session: session, mode: session.mode, onExit: { dismiss() })
        }
    }

    /// Human-friendly label for whatever format the session is currently in.
    private func formatLabel(_ mode: PartyMode) -> String {
        if mode == .team10 { return "10 vs 10" }
        if mode == .oneVsTen { return "1 vs 9" }
        if mode.isCustom { return "\(mode.allyCount + 1) vs \(mode.opponentCount)" }
        return "1 vs 19"
    }

    private func waitingBody(_ session: PartySession) -> some View {
        let players = session.lobby?.players ?? []
        let capacity = session.lobby?.capacity ?? 20
        return VStack(spacing: 22) {
            HStack {
                Button {
                    Haptics.tap()
                    session.cancel(voluntary: true)
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.quizInkMuted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Theme.quizCanvas))
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer(minLength: 8)

            VStack(spacing: 6) {
                Text(formatLabel(session.mode))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.quizInk)
                Text("Recherche de joueurs…")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.quizInkMuted)
            }

            if let roomCode = session.roomCode {
                roomCodeBanner(roomCode)
            }

            Text("\(players.count) / \(capacity)")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.duelAccent)
                .contentTransition(.numericText())

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(0..<capacity, id: \.self) { index in
                    LobbySeat(
                        player: index < players.count ? players[index] : nil,
                        isYou: index < players.count && players[index].id == online.profile?.id,
                        avatar: avatarStore?.config
                    )
                }
            }
            .padding(.horizontal, 24)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: players.map(\.id))

            Spacer(minLength: 8)

            if session.isHost {
                Button("Démarrer maintenant") {
                    Haptics.medium()
                    session.forceStart()
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            } else {
                Color.clear.frame(height: 24)
            }
        }
        .onChange(of: players.count) { oldCount, newCount in
            if newCount > oldCount { Haptics.tap() }
        }
    }

    /// The code a custom room's host shares with friends, front and center
    /// with a one-tap share sheet.
    private func roomCodeBanner(_ code: String) -> some View {
        HStack(spacing: 10) {
            Text(code)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundStyle(Theme.duelAccent)
                .kerning(3)
            ShareLink(item: "Rejoins ma partie Minduel avec le code \(code) !") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.duelAccent)
            }
            .simultaneousGesture(TapGesture().onEnded { Analytics.capture("share_tapped") })
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.duelAccent.opacity(0.1)))
    }


    private func statusBody(icon: String, color: Color, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInk)
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.quizInkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Retour") {
                Haptics.tap()
                dismiss()
            }
            .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
            .padding(.horizontal, 60)
            .padding(.top, 8)
        }
    }
}

/// "3-2-1" before the first question. Owns its own clock so it always ticks,
/// whatever the parent was doing when the server started the game.
private struct PartyCountdownStage: View {
    @State private var count: Int = 3

    var body: some View {
        VStack(spacing: 12) {
            Text("La partie commence")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
            CountdownDigits(value: count)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            Haptics.medium()
            for value in [2, 1] {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                count = value
                Haptics.tap()
            }
        }
    }
}

/// One chair of the waiting room: empty ring, or the seated player's face
/// popping in. The local player wears their own avatar.
private struct LobbySeat: View {
    let player: PlayerProfile?
    let isYou: Bool
    let avatar: AvatarConfig?

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Theme.quizCanvas)
                    .overlay(Circle().stroke(player == nil ? Theme.quizLine : Theme.duelAccent.opacity(isYou ? 0.9 : 0.5), lineWidth: isYou ? 2.5 : 1.5))
                if let player {
                    Group {
                        if isYou, let avatar {
                            AvatarView(config: avatar, size: 40)
                        } else {
                            Text(player.emoji)
                                .font(.system(size: 22))
                        }
                    }
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
            }
            .frame(width: 44, height: 44)
            Text(player.map { isYou ? "Toi" : $0.name } ?? " ")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(isYou ? Theme.duelAccent : Theme.quizInkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(player.map { isYou ? "Toi" : $0.name } ?? "Place libre")
    }
}
