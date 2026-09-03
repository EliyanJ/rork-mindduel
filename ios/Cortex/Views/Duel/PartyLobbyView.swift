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
    @State private var countdown: Int = 3
    @State private var isCountingDown = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.quizBackground.ignoresSafeArea()
            if let session {
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
            countdownBody
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
        if mode == .oneVsTen { return "1 vs 10" }
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
                    if index < players.count {
                        VStack(spacing: 4) {
                            Text(players[index].emoji)
                                .font(.system(size: 20))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(Theme.quizCanvas))
                                .overlay(Circle().stroke(Theme.duelAccent.opacity(0.5), lineWidth: 1.5))
                            Text(players[index].name)
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.quizInkMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    } else {
                        Circle()
                            .fill(Theme.quizCanvas)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Theme.quizLine, lineWidth: 1, antialiased: true))
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 8)

            if session.isHost {
                VStack(spacing: 10) {
                    Button("Démarrer maintenant") {
                        Haptics.medium()
                        session.forceStart()
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.duelAccent, textColor: .white))
                    Text("Les places vides seront comblées par des bots")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.quizInkMuted.opacity(0.8))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            } else {
                Text("Les places vides seront comblées automatiquement")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.quizInkMuted.opacity(0.8))
                    .padding(.bottom, 24)
            }
        }
        .onChange(of: session.phase) { _, phase in
            if phase == .countdown { runCountdown() }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.duelAccent.opacity(0.1)))
    }

    private var countdownBody: some View {
        VStack(spacing: 12) {
            Text("La partie commence")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.quizInkMuted)
            CountdownDigits(value: countdown)
        }
    }

    private func runCountdown() {
        guard !isCountingDown else { return }
        isCountingDown = true
        countdown = 3
        Task {
            for value in stride(from: 2, through: 1, by: -1) {
                try? await Task.sleep(for: .seconds(1))
                countdown = value
                Haptics.tap()
            }
        }
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
