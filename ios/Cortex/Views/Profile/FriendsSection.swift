import SwiftUI

/// Friends card in the profile: add by friend code, incoming requests,
/// and the friends list with their world ELO.
struct FriendsSection: View {
    @Environment(OnlineModel.self) private var online
    @State private var codeInput: String = ""
    @State private var isSubmitting: Bool = false
    @State private var confirmationMessage: String?

    var body: some View {
        @Bindable var online = online

        VStack(alignment: .leading, spacing: 14) {
            Text("Amis")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)

            addFriendField

            if let confirmationMessage {
                Text(confirmationMessage)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.success)
            }

            if !online.incomingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEMANDES REÇUES")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                    ForEach(online.incomingRequests) { request in
                        requestRow(request)
                    }
                }
            }

            if !online.outgoingRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("EN ATTENTE")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                    ForEach(online.outgoingRequests) { pending in
                        HStack(spacing: 10) {
                            Text(pending.emoji).font(.system(size: 22))
                            Text(pending.name)
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                .foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Text("envoyée")
                                .font(.system(.caption2, design: .rounded, weight: .heavy))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if online.friends.isEmpty {
                Text("Aucun ami pour l'instant. Partage ton code ami pour te connecter avec d'autres joueurs !")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 4) {
                    ForEach(online.friends) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        .alert("Oups", isPresented: Binding(
            get: { online.friendActionError != nil },
            set: { if !$0 { online.friendActionError = nil } }
        )) {
            Button("OK") { online.friendActionError = nil }
        } message: {
            Text(online.friendActionError ?? "")
        }
    }

    private var addFriendField: some View {
        HStack(spacing: 10) {
            TextField("Code ami (ex : Florent#003)", text: $codeInput)
                .font(.system(.body, design: .rounded, weight: .bold))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.background))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
            Button {
                Haptics.tap()
                submitCode()
            } label: {
                if isSubmitting {
                    ProgressView().tint(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.primary))
                } else {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.primary))
                }
            }
            .disabled(isSubmitting || codeInput.trimmingCharacters(in: .whitespaces).count < 4)
        }
    }

    private func submitCode() {
        let code = codeInput.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        isSubmitting = true
        confirmationMessage = nil
        Task {
            let success = await online.addFriend(code: code)
            isSubmitting = false
            if success {
                codeInput = ""
                confirmationMessage = "Demande envoyée ✅"
                Haptics.success()
            }
        }
    }

    private func requestRow(_ request: PlayerProfile) -> some View {
        HStack(spacing: 10) {
            Text(request.emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 1) {
                Text(request.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("ELO \(request.elo)")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Button {
                Haptics.success()
                Task { await online.respondToRequest(from: request, accept: true) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.success))
            }
            Button {
                Haptics.tap()
                Task { await online.respondToRequest(from: request, accept: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Theme.background))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1.5))
            }
        }
        .padding(.vertical, 4)
    }

    private func friendRow(_ friend: PlayerProfile) -> some View {
        HStack(spacing: 10) {
            Text(friend.emoji).font(.system(size: 24))
            VStack(alignment: .leading, spacing: 1) {
                Text(friend.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(friend.wins) V · \(friend.losses) D")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer()
            Text("ELO \(friend.elo)")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.duelAccent.mix(with: .black, by: 0.2))
            Menu {
                Button(role: .destructive) {
                    Task { await online.removeFriend(friend) }
                } label: {
                    Label("Retirer cet ami", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.inkMuted)
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.vertical, 4)
    }
}
