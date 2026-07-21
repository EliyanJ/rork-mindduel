import SwiftUI

/// Full-screen Friends page: add by code, incoming/outgoing requests, and
/// the friends list with world ELO. Reuses all the working logic that used
/// to live compacted inside the Profile's `FriendsSection` card — this is
/// just a roomier, dedicated layout, reachable from the Duel screen.
struct FriendsView: View {
    @Environment(OnlineModel.self) private var online
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                FriendsSection()
                    .padding(16)
                    .padding(.bottom, 32)
            }
            .background(Theme.background)
            .navigationTitle("Amis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.primary)
                }
            }
            .task { await online.refreshFriends() }
        }
    }
}
