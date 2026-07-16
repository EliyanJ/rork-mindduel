import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @State private var onboardingStore = OnboardingStore()
    @Environment(OnlineModel.self) private var online

    var body: some View {
        Group {
            if onboardingStore.isCompleted {
                mainTabs
                    .transition(.opacity)
            } else {
                OnboardingView(store: onboardingStore, onFinished: finishOnboarding)
                    .environment(model)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboardingStore.isCompleted)
    }

    private func finishOnboarding() {
        // If the user already signed in (via "I already have an account"), sync
        // their server-side profile so they land on the home screen up-to-date.
        if online.auth.user != nil {
            Task {
                await online.syncProfile(localElo: model.store.progress.elo)
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            Tab("Apprendre", systemImage: "map.fill") {
                HomeView()
            }
            Tab("Révisions", systemImage: "brain.head.profile") {
                ReviewView()
            }
            Tab("Duel", systemImage: "bolt.fill") {
                DuelHomeView()
            }
            Tab("Profil", systemImage: "person.crop.circle.fill") {
                ProfileView()
            }
        }
        .tint(Theme.primary)
        .environment(model)
    }
}

#Preview {
    ContentView()
}
