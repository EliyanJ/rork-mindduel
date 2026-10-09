import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var updates: AppUpdateService = .shared
    @State private var model = AppModel()
    @State private var onboardingStore = OnboardingStore()
    @State private var showSplash = true
    @State private var selectedTab: AppTab = .parcours
    @State private var isMoreMenuOpen: Bool = false
    @State private var moreSheet: MoreSheet?
    @State private var isWelcomeBackPresented: Bool = false
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                if updates.requiresUpdate {
                    UpdateRequiredView(isPartyOnly: false, onDismiss: nil)
                } else if onboardingStore.isCompleted {
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
        // Premium perks that live in the progress store (duel points) follow
        // the RevenueCat entitlement, and purchases follow the Minduel account.
        .onChange(of: store.isPremium, initial: true) { _, isPremium in
            model.store.hasUnlimitedDuels = isPremium
        }
        .onChange(of: online.auth.user?.id, initial: true) { _, userId in
            Task { await store.identify(userId: userId) }
        }
        // Rewarded videos (and the EU consent form) only start once the
        // onboarding is over, never on top of the first screens.
        .onChange(of: onboardingStore.isCompleted, initial: true) { _, isCompleted in
            if isCompleted { AdsManager.shared.start() }
        }
        // The first frame already shows the bundled catalogue; the freshest
        // questions published from the admin panel arrive in the background
        // and rebuild the path without ever blocking the launch.
        .task {
            checkWelcomeBack()
            await updates.refresh()
            guard !updates.requiresUpdate else { return }
            await model.refreshFromBackend()
        }
        // Reminders are rebuilt every time the app comes forward: that is what
        // lets today's remaining slots disappear once the player has practised.
        .onChange(of: scenePhase) { _, phase in
            // Leaving the foreground is the last safe moment to push whatever
            // answers are still buffered; iOS may kill the app afterwards.
            if phase != .active { AnswerTelemetry.shared.flush() }
            if phase == .active {
                Task { await updates.refresh() }
                checkWelcomeBack()
            }
            guard phase == .active, onboardingStore.isCompleted else { return }
            Task { await refreshReminders() }
        }

            if onboardingStore.isCompleted && !showSplash && !updates.requiresUpdate {
                FeedbackBubble()
            }

            if isWelcomeBackPresented && !showSplash && onboardingStore.isCompleted {
                WelcomeBackView(name: welcomeName) {
                    withAnimation(.easeInOut(duration: 0.35)) { isWelcomeBackPresented = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 1.04)))
                .zIndex(5)
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
        Analytics.capture("onboarding_completed")
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
        // The tracking permission is asked later, right before the first
        // rewarded video the player chooses to watch.
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

    private var welcomeName: String {
        if let name = online.profile?.name, !name.isEmpty { return name }
        let nickname = onboardingStore.preferences.nickname
        return nickname.isEmpty ? "Toi" : nickname
    }

    /// Greets players coming back after several days away (never right
    /// after the onboarding, which records the first visit).
    private func checkWelcomeBack() {
        guard onboardingStore.isCompleted else {
            ReturnTracker.touch()
            return
        }
        if ReturnTracker.checkAndRecord() {
            Analytics.capture("welcome_back_shown")
            withAnimation(.easeInOut(duration: 0.35)) { isWelcomeBackPresented = true }
        }
    }

    private enum MoreSheet: String, Identifiable {
        case friends, qrCode, settings, support
        var id: String { rawValue }
    }

    private func select(_ tab: AppTab) {
        Haptics.tap()
        if tab == .plus {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMoreMenuOpen.toggle() }
            return
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { isMoreMenuOpen = false }
        selectedTab = tab
    }

    private func openFromMenu(_ action: () -> Void) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { isMoreMenuOpen = false }
        action()
    }

    @ViewBuilder
    private var currentTab: some View {
        switch selectedTab {
        case .parcours:
            HomeView()
        case .duel:
            DuelHomeView()
        case .classement:
            LeaguesView()
        case .actus:
            NewsFeedView { destination in
                switch destination {
                case .tab(let tab):
                    selectedTab = tab
                case .chapters:
                    selectedTab = .parcours
                    model.isChaptersMenuRequested = true
                }
            }
        case .premium:
            if store.isPremium {
                PremiumActiveView()
            } else {
                PaywallView(source: "tab", isEmbedded: true)
            }
        case .plus:
            ProfileView()
        }
    }

    private var mainTabs: some View {
        currentTab
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isMoreMenuOpen {
                    MoreMenuPanel(
                        incomingRequests: online.incomingRequests.count,
                        onProfile: { openFromMenu { selectedTab = .plus } },
                        onFriends: { openFromMenu { moreSheet = .friends } },
                        onQRCode: { openFromMenu { moreSheet = .qrCode } },
                        onSettings: { openFromMenu { moreSheet = .settings } },
                        onSupport: { openFromMenu { moreSheet = .support } },
                        onClose: { withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { isMoreMenuOpen = false } }
                    )
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MainTabBar(
                    selected: selectedTab,
                    isMoreMenuOpen: isMoreMenuOpen,
                    plusBadge: online.incomingRequests.count,
                    onSelect: select
                )
            }
            .environment(model)
            .sheet(item: $moreSheet) { sheet in
                Group {
                    switch sheet {
                    case .friends: FriendsView()
                    case .qrCode: FriendQRView()
                    case .settings: SettingsView()
                    case .support: LegalWebView(title: "Aide et support", url: WebLinks.support)
                    }
                }
                .environment(model)
            }
            .onAppear { Analytics.capture("screen_viewed", ["screen": selectedTab.rawValue]) }
            .onChange(of: selectedTab) { _, tab in
                Analytics.capture("screen_viewed", ["screen": tab.rawValue])
            }
    }
}

/// "Premium" tab once subscribed: a thank-you card with the perks and a
/// shortcut to manage the subscription.
private struct PremiumActiveView: View {
    @State private var isManaging: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image("MascotCelebrate")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .accessibilityHidden(true)
                Label("MINDUEL PREMIUM ACTIF", systemImage: "crown.fill")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .tracking(1)
                    .foregroundStyle(Theme.primary)
                Text("Merci de soutenir Minduel !")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 12) {
                    perk("Leçons illimitées")
                    perk("Choix libre des thèmes")
                    perk("Mode classé et classement mondial")
                    perk("Duels illimités")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
                Button("Gérer mon abonnement") {
                    Haptics.tap()
                    isManaging = true
                }
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.primary)
                .frame(minHeight: 44)
            }
            .padding(20)
            .padding(.top, 20)
        }
        .background(Theme.background.ignoresSafeArea())
        .manageSubscriptionsSheet(isPresented: $isManaging)
    }

    private func perk(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.success)
            Text(text)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
    }
}

#Preview {
    ContentView()
}
