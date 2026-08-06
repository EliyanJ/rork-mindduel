import SwiftUI

/// Tab identifiers used to switch tabs programmatically (e.g. jumping from
/// a theme card straight to its dedicated path).
private enum AppTab: Hashable {
    case parcours, themes, duel, profil
}

struct ContentView: View {
    @State private var model = AppModel()
    @State private var onboardingStore = OnboardingStore()
    @State private var showSplash = true
    @State private var selectedTab: AppTab = .parcours
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
            // Leaving the foreground is the last safe moment to push whatever
            // answers are still buffered; iOS may kill the app afterwards.
            if phase != .active { AnswerTelemetry.shared.flush() }
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
                await online.syncProfile(
                    localElo: model.store.progress.elo,
                    dailyGoal: onboardingStore.preferences.dailyGoal
                )
            }
        }
        // Ask for notifications only now: the onboarding has just shown what the
        // app is for, and iOS grants exactly one prompt per install.
        Task {
            await NotificationService.shared.requestAuthorization()
            await refreshReminders()
        }
        // Same reasoning for App Tracking Transparency: only ask once the
        // player has seen the app's value, and only once ever per install.
        Task {
            await TrackingManager.requestAuthorizationIfNeeded()
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
        TabView(selection: $selectedTab) {
            Tab("Parcours", systemImage: "map.fill", value: AppTab.parcours) {
                HomeView()
            }
            Tab("Thèmes", systemImage: "square.grid.2x2.fill", value: AppTab.themes) {
                ThemesView { disciplineId in
                    model.selectedDisciplineId = disciplineId
                    selectedTab = .parcours
                }
            }
            Tab("Duel", systemImage: "bolt.fill", value: AppTab.duel) {
                DuelHomeView()
            }
            Tab("Profil", systemImage: "person.crop.circle.fill", value: AppTab.profil) {
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
