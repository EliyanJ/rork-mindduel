import SwiftUI

struct ContentView: View {
    @State private var model = AppModel()
    @State private var onboardingStore = OnboardingStore()
    @State private var showSplash = true
    @Environment(OnlineModel.self) private var online
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
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
        // Favourite themes drive how often each discipline comes round on the
        // mixed path, so keep the model in sync with the onboarding answers.
        .onAppear {
            model.preferredDisciplineIds = onboardingStore.preferences.topicIds
        }
        .onChange(of: onboardingStore.preferences.topicIds) { _, newTopics in
            model.preferredDisciplineIds = newTopics
        }
        // Reminders are rebuilt every time the app comes forward: that is what
        // lets today's remaining slots disappear once the player has practised.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, onboardingStore.isCompleted else { return }
            Task { await refreshReminders() }
        }

            if showSplash {
                SplashView {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(10)
            }
        }
    }

    private func finishOnboarding() {
        // If the user already signed in (via "I already have an account"), sync
        // their server-side profile so they land on the home screen up-to-date.
        if online.auth.user != nil {
            Task {
                await online.syncProfile(localElo: model.store.progress.elo)
            }
        }
        // Ask for notifications only now: the onboarding has just shown what the
        // app is for, and iOS grants exactly one prompt per install.
        Task {
            await NotificationService.shared.requestAuthorization()
            await refreshReminders()
        }
    }

    private func refreshReminders() async {
        let hasPracticedToday = model.store.progress.lastActiveDay
            .map { Calendar.current.isDateInToday($0) } ?? false
        await NotificationService.shared.refreshSchedule(
            preferences: onboardingStore.preferences,
            hasPracticedToday: hasPracticedToday,
            streak: model.store.currentStreak
        )
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
