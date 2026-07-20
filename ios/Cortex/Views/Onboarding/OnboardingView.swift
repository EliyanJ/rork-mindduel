import SwiftUI

/// Ordered steps of the first-run onboarding flow (v3).
private enum OnboardingStep: Int, CaseIterable {
    case welcome, nickname, goal, topics, dailyGoal, qualification, screenTime, miniQuiz, quizResult, diagnosticPropose, diagnosticQuiz, diagnosticResult, commitment, plan, paywall, account
}

/// First-run onboarding: collects light preferences, a nickname, a qualification,
/// a typed commitment, builds momentum with an animated "plan" reveal, then hands
/// off into the main app. Existing signed-in users can skip straight to the app.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(OnlineModel.self) private var online
    @Environment(StoreViewModel.self) private var storeViewModel
    let store: OnboardingStore
    let onFinished: () -> Void

    @State private var step: OnboardingStep = .welcome
    @State private var nickname: String = ""
    @State private var goal: LearningGoal?
    @State private var selectedTopicIds: Set<String> = []
    @State private var dailyGoal: Int = 3
    @State private var perceivedLevel: PerceivedLevel?
    @State private var preferredTime: PreferredLearningTime?
    @State private var screenTimeBracket: ScreenTimeBracket?
    @State private var quizScore: Int = 0
    @State private var diagnosticQuestions: [LessonItem] = []
    @State private var diagnosticSession: DiagnosticSession?
    @State private var diagnosticScore: Int = 0
    @State private var diagnosticResults: [DisciplineDiagnosticResult] = []
    @State private var commitmentText: String = ""
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
            }

            Group {
                switch step {
                case .welcome:
                    OnboardingWelcomeStep(
                        onStart: goNext,
                        onSkip: signInAndSkip
                    )
                case .nickname:
                    OnboardingNicknameStep(nickname: $nickname, onNext: goNext)
                case .goal:
                    OnboardingGoalStep(selection: $goal, onNext: goNext)
                case .topics:
                    OnboardingTopicsStep(
                        disciplines: model.catalog.disciplines,
                        selection: $selectedTopicIds,
                        onNext: goNext
                    )
                case .dailyGoal:
                    OnboardingDailyGoalStep(count: $dailyGoal, onNext: goNext)
                case .qualification:
                    OnboardingQualificationStep(
                        perceivedLevel: $perceivedLevel,
                        preferredTime: $preferredTime,
                        onNext: goNext
                    )
                case .screenTime:
                    OnboardingScreenTimeStep(selection: $screenTimeBracket, onNext: goNext)
                case .miniQuiz:
                    OnboardingMiniQuizStep(onFinished: { score in
                        quizScore = score
                        goNext()
                    })
                case .quizResult:
                    OnboardingQuizResultStep(score: quizScore, total: 5, onFinished: goNext)
                case .diagnosticPropose:
                    OnboardingDiagnosticProposeStep(
                        onStart: startDiagnostic,
                        onSkip: skipDiagnostic
                    )
                case .diagnosticQuiz:
                    if !diagnosticQuestions.isEmpty {
                        OnboardingDiagnosticQuizStep(
                            items: diagnosticQuestions,
                            store: model.store,
                            onCompleted: { session in
                                self.diagnosticSession = session
                                self.diagnosticScore = session.wasCorrect.filter { $0 }.count
                                self.diagnosticResults = DiagnosticGenerator.computeResults(session: session, catalog: model.catalog)
                                goNext()
                            }
                        )
                    }
                case .diagnosticResult:
                    OnboardingDiagnosticResultStep(
                        results: diagnosticResults,
                        score: diagnosticScore,
                        total: diagnosticQuestions.count,
                        onStartWeakest: { result in
                            model.selectedDisciplineId = result.disciplineId
                            goNext()
                        },
                        onViewFullPath: {
                            goNext()
                        },
                        onClose: {
                            goNext()
                        }
                    )
                case .commitment:
                    OnboardingCommitmentStep(
                        nickname: nickname,
                        commitmentText: $commitmentText,
                        onNext: goNext
                    )
                case .plan:
                    OnboardingPlanStep(
                        goal: goal,
                        topics: model.catalog.disciplines.filter { selectedTopicIds.contains($0.id) },
                        dailyGoal: dailyGoal,
                        onFinish: goNext
                    )
                case .paywall:
                    OnboardingPaywallStep(store: storeViewModel, onFinished: goNext)
                case .account:
                    OnboardingAccountStep(onFinished: finish)
                }
            }
            .transition(
                .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isSigningIn {
                ZStack {
                    Theme.background.opacity(0.8)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.4)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Button {
                Haptics.tap()
                goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(headerForeground)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(headerForeground.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .opacity(canGoBack ? 1 : 0)
            .disabled(!canGoBack)

            Capsule()
                .fill(headerForeground.opacity(0.15))
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(headerForeground)
                            .frame(width: geo.size.width * progress, height: 8)
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(step == .quizResult ? Theme.gold : Theme.background)
    }

    private var headerForeground: Color {
        Theme.ink
    }

    private var progress: Double {
        Double(step.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }

    private var canGoBack: Bool {
        step != .welcome && step != .quizResult && step != .miniQuiz && step != .diagnosticResult
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        withAnimation(.spring(duration: 0.32)) { step = previous }
    }

    private func goNext() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
            finish()
            return
        }
        withAnimation(.spring(duration: 0.32)) { step = next }
    }

    /// Sign in an existing user and skip onboarding entirely; their server-side
    /// progress (ELO, friends) is restored and they land straight on the home screen.
    private func signInAndSkip() {
        Haptics.tap()
        isSigningIn = true
        Task { @MainActor in
            await online.auth.signIn(provider: "apple")
            if online.auth.user != nil {
                store.complete()
                onFinished()
            }
            isSigningIn = false
        }
    }

    private func startDiagnostic() {
        Haptics.medium()
        diagnosticQuestions = DiagnosticGenerator.generateDiagnosticQuestions(catalog: model.catalog)
            .map { question in
                let disciplineId = model.catalog.disciplines.first { discipline in
                    discipline.chapters.contains { chapter in
                        chapter.allQuestions.contains { $0.id == question.id }
                    }
                }?.id ?? ""
                return LessonItem(question: question, disciplineId: disciplineId)
            }
        goNext()
    }

    private func skipDiagnostic() {
        Haptics.tap()
        diagnosticResults = []
        diagnosticScore = 0
        let diagnostic = OnboardingDiagnostic(completed: false, skipped: true, completedAt: Date(), results: [])
        store.saveDiagnostic(diagnostic)
        withAnimation(.spring(duration: 0.32)) { step = .commitment }
    }

    private func finish() {
        let diagnostic = OnboardingDiagnostic(
            completed: diagnosticResults.isEmpty == false,
            skipped: diagnosticResults.isEmpty && diagnosticScore == 0,
            completedAt: diagnosticResults.isEmpty ? nil : Date(),
            results: diagnosticResults
        )
        let preferences = OnboardingPreferences(
            nickname: nickname,
            goal: goal,
            topicIds: Array(selectedTopicIds),
            dailyGoal: dailyGoal,
            perceivedLevel: perceivedLevel,
            preferredLearningTime: preferredTime,
            screenTimeBracket: screenTimeBracket,
            quizScore: quizScore,
            commitmentText: commitmentText,
            signedAt: Date(),
            diagnostic: diagnostic
        )
        store.save(preferences)
        if selectedTopicIds.count == 1, let onlyTopic = selectedTopicIds.first {
            model.selectedDisciplineId = onlyTopic
        }
        store.complete()
        onFinished()
    }
}
