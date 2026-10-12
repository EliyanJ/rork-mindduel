import SwiftUI

/// Streak card of the profile: the current streak, a few records and a
/// month-by-month calendar of the days actually played, browsable back to
/// the very first recorded day.
struct StreakCalendarView: View {
    let history: ProgressStore.StreakHistory
    let currentStreak: Int
    let freezes: Int

    @State private var monthIndex: Int = 0
    @State private var isFlameLit: Bool = false

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "fr_FR")
        calendar.firstWeekday = 2
        calendar.timeZone = .current
        return calendar
    }()

    /// First day of every month from the first recorded day up to today.
    private var months: [Date] {
        let calendar = Self.calendar
        let now = Date.now
        guard let current = calendar.dateInterval(of: .month, for: now)?.start else { return [now] }
        let firstDay = history.firstDay ?? now
        guard var month = calendar.dateInterval(of: .month, for: min(firstDay, now))?.start else { return [current] }
        var result: [Date] = []
        while month <= current {
            result.append(month)
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return result.isEmpty ? [current] : result
    }

    var body: some View {
        let months = months
        VStack(spacing: 18) {
            header
            statsRow
            VStack(spacing: 12) {
                monthBar(months: months)
                TabView(selection: $monthIndex) {
                    ForEach(Array(months.enumerated()), id: \.element) { index, month in
                        MonthGrid(month: month, history: history, calendar: Self.calendar)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: MonthGrid.height)
                monthFooter(months: months)
            }
            legend
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1.5))
        .onAppear {
            monthIndex = max(0, months.count - 1)
            isFlameLit = currentStreak > 0
        }
        .onChange(of: months.count) { _, count in
            monthIndex = max(0, count - 1)
        }
        .sensoryFeedback(.selection, trigger: monthIndex)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(
                    currentStreak > 0
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.gold, Theme.primary], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(Theme.inkMuted)
                )
                .scaleEffect(isFlameLit ? 1.06 : 0.96)
                .animation(currentStreak > 0 ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : .default, value: isFlameLit)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(currentStreak) jour\(currentStreak > 1 ? "s" : "") consécutif\(currentStreak > 1 ? "s" : "")")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(currentStreak > 0 ? "Ne casse pas ta série !" : "Termine une leçon pour allumer la flamme")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.inkMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat(value: "\(history.bestStreak)", label: "Record", icon: "trophy.fill", color: Theme.gold)
            stat(value: "\(history.activeDays.count)", label: "Jours joués", icon: "calendar", color: Theme.primary)
            stat(value: "\(freezes)", label: "Protections", icon: "snowflake", color: Theme.link)
        }
    }

    private func stat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }

    private func monthBar(months: [Date]) -> some View {
        let month = months[min(monthIndex, months.count - 1)]
        return HStack {
            Button {
                withAnimation(.snappy) { monthIndex = max(0, monthIndex - 1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 44, height: 44)
            }
            .disabled(monthIndex == 0)
            .accessibilityLabel("Mois précédent")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .contentTransition(.opacity)
            Spacer()
            Button {
                withAnimation(.snappy) { monthIndex = min(months.count - 1, monthIndex + 1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .frame(width: 44, height: 44)
            }
            .disabled(monthIndex >= months.count - 1)
            .accessibilityLabel("Mois suivant")
        }
        .foregroundStyle(Theme.primary)
        .buttonStyle(.plain)
    }

    private func monthFooter(months: [Date]) -> some View {
        let month = months[min(monthIndex, months.count - 1)]
        let played = playedDays(in: month)
        let isCurrentMonth = monthIndex >= months.count - 1
        return HStack {
            Text(played == 0 ? "Aucun jour joué ce mois-ci" : "\(played) jour\(played > 1 ? "s" : "") joué\(played > 1 ? "s" : "") ce mois-ci")
                .font(.system(.footnote, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.inkMuted)
            Spacer()
            if !isCurrentMonth {
                Button("Aujourd'hui") {
                    Haptics.tap()
                    withAnimation(.snappy) { monthIndex = months.count - 1 }
                }
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .foregroundStyle(Theme.link)
                .frame(minHeight: 32)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: Theme.primary, icon: nil, text: "Jour joué")
            legendItem(color: Theme.link.opacity(0.25), icon: "snowflake", text: "Série protégée")
            Spacer(minLength: 0)
        }
        .font(.system(.caption2, design: .rounded, weight: .bold))
        .foregroundStyle(Theme.inkMuted)
    }

    private func legendItem(color: Color, icon: String?, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Theme.link)
                    }
                }
            Text(text)
        }
    }

    private func playedDays(in month: Date) -> Int {
        let calendar = Self.calendar
        let target = calendar.dateComponents([.year, .month], from: month)
        return history.activeDays.filter { $0.year == target.year && $0.month == target.month }.count
    }
}

/// One month, Monday first, with played days linked like a chain.
private struct MonthGrid: View {
    let month: Date
    let history: ProgressStore.StreakHistory
    let calendar: Calendar

    static let rowHeight: CGFloat = 40
    static let height: CGFloat = 24 + 6 * rowHeight + 5 * 4

    private static let weekdaySymbols: [String] = ["L", "M", "M", "J", "V", "S", "D"]

    /// Six weeks of cells; nil pads the days outside the month.
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = calendar.component(.weekday, from: month)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in range {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: month))
        }
        while result.count < 42 { result.append(nil) }
        return result
    }

    var body: some View {
        let cells = cells
        let today = calendar.startOfDay(for: .now)
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Theme.inkMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 24)
            ForEach(0..<6, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { column in
                        let index = row * 7 + column
                        DayCell(
                            date: cells[index],
                            state: state(of: cells[index], today: today),
                            linksLeft: column > 0 && isFilled(cells[index - 1]) && isFilled(cells[index]),
                            linksRight: column < 6 && isFilled(cells[index + 1]) && isFilled(cells[index]),
                            isToday: cells[index].map { calendar.isDate($0, inSameDayAs: today) } ?? false,
                            calendar: calendar
                        )
                    }
                }
                .frame(height: Self.rowHeight)
            }
        }
        .padding(.horizontal, 2)
    }

    private func isFilled(_ date: Date?) -> Bool {
        guard let date else { return false }
        return history.isActive(date, calendar: calendar) || history.isProtected(date, calendar: calendar)
    }

    private func state(of date: Date?, today: Date) -> DayCell.State {
        guard let date else { return .empty }
        if history.isActive(date, calendar: calendar) { return .played }
        if history.isProtected(date, calendar: calendar) { return .protected }
        return date > today ? .future : .missed
    }
}

private struct DayCell: View {
    enum State {
        case empty, played, protected, missed, future
    }

    let date: Date?
    let state: State
    let linksLeft: Bool
    let linksRight: Bool
    let isToday: Bool
    let calendar: Calendar

    private static let size: CGFloat = 34

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(linksLeft ? bandColor : .clear)
                Rectangle().fill(linksRight ? bandColor : .clear)
            }
            .frame(height: Self.size - 6)
            if let date {
                Circle()
                    .fill(fill)
                    .frame(width: Self.size, height: Self.size)
                    .overlay {
                        if isToday && state != .played {
                            Circle().stroke(Theme.primary, lineWidth: 2.5)
                        }
                    }
                Group {
                    if state == .protected {
                        Image(systemName: "snowflake")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(Theme.link)
                    } else {
                        Text("\(calendar.component(.day, from: date))")
                            .font(.system(.subheadline, design: .rounded, weight: state == .played || isToday ? .heavy : .semibold))
                            .foregroundStyle(textColor)
                            .monospacedDigit()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var bandColor: Color {
        Theme.primary.opacity(0.28)
    }

    private var fill: Color {
        switch state {
        case .played: return Theme.primary
        case .protected: return Theme.link.opacity(0.22)
        default: return .clear
        }
    }

    private var textColor: Color {
        switch state {
        case .played: return .white
        case .future: return Theme.inkMuted.opacity(0.5)
        case .missed: return Theme.inkMuted
        default: return Theme.ink
        }
    }

    private var accessibilityText: String {
        guard let date else { return "" }
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR")))
        switch state {
        case .played: return "\(day), jour joué"
        case .protected: return "\(day), série protégée"
        case .future: return day
        default: return "\(day), pas joué"
        }
    }
}
