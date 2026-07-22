import SwiftUI

/// Shown once, right after the player completes their first successful
/// lesson of the day: highlights the current streak and the week's
/// activity at a glance, à la Duolingo/GenK.
struct StreakCelebrationView: View {
    let streak: Int
    let week: [LessonSession.DayActivity]
    let onContinue: () -> Void

    @State private var hasAppeared: Bool = false
    @State private var flameBounce: Bool = false

    private static let messages = [
        "Back in the game ! On y va à fond !",
        "Une nouvelle journée, une nouvelle victoire.",
        "Ta régularité paie, continue comme ça !",
        "Chaque jour compte. Bravo pour ta constance !",
        "La flamme ne s'éteint pas, bravo !"
    ]

    private var message: String {
        Self.messages[max(0, streak - 1) % Self.messages.count]
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer(minLength: 8)

            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.12))
                    .frame(width: 184, height: 184)
                    .scaleEffect(hasAppeared ? 1 : 0.4)
                Image(systemName: "flame.fill")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.primary, Color(hex: "FF8A5B")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .scaleEffect(flameBounce ? 1 : 0.3)
                    .rotationEffect(.degrees(hasAppeared ? 0 : -14))
            }

            VStack(spacing: 6) {
                Text("\(streak)")
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(streak > 1 ? "Jours de suite" : "Jour de suite")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
            .opacity(hasAppeared ? 1 : 0)

            HStack(spacing: 8) {
                ForEach(week) { day in
                    dayColumn(day)
                }
            }
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 16)

            Text(message)
                .font(.system(.body, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .opacity(hasAppeared ? 1 : 0)

            Spacer()

            Button("Continuer", action: onContinue)
                .buttonStyle(ChunkyButtonStyle(color: Theme.primary))
        }
        .padding(20)
        .background(Theme.background)
        .onAppear {
            Haptics.success()
            withAnimation(.spring(response: 0.55, dampingFraction: 0.62).delay(0.1)) {
                hasAppeared = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.45).delay(0.2)) {
                flameBounce = true
            }
        }
    }

    private func dayColumn(_ day: LessonSession.DayActivity) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(day.isActive ? Theme.primary.opacity(0.16) : Theme.lockedFill.opacity(0.5))
                    .frame(width: 36, height: 36)
                Circle()
                    .stroke(day.isActive ? Theme.primary : Theme.line, lineWidth: 2)
                    .frame(width: 36, height: 36)
                Image(systemName: day.isActive ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(day.isActive ? Theme.primary : Theme.inkMuted)
            }
            Text(dayLabel(for: day.date))
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(isToday ? Theme.primary : Theme.inkMuted)
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).lowercased()
    }
}

#Preview {
    StreakCelebrationView(
        streak: 4,
        week: (0..<7).map { offset in
            LessonSession.DayActivity(
                date: Calendar.current.date(byAdding: .day, value: -6 + offset, to: .now) ?? .now,
                isActive: offset % 2 == 0
            )
        },
        onContinue: {}
    )
}
