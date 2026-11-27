import SwiftUI
import SwiftData

struct HabitHistoryView: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var context
    @State private var visibleMonth = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selectedDate = Calendar.current.startOfDay(for: .now)
    @State private var errorMessage: String?
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var calendar: Calendar { .current }
    private var monthDates: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth),
              let interval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: interval.start) }.map(Optional.some)
    }
    private var dateStatus: RecordStatus? { habit.records.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }?.status }
    private var isScheduled: Bool {
        selectedDate >= calendar.startOfDay(for: habit.startDate) &&
        habit.frequencyDays.contains(calendar.component(.weekday, from: selectedDate))
    }
    private var missed: Bool { isScheduled && selectedDate < calendar.startOfDay(for: .now) && dateStatus == nil }
    private var monthSummary: HabitPeriodSummary {
        guard let range = calendar.dateInterval(of: .month, for: visibleMonth) else { return HabitPeriodSummary(completed: 0, pending: 0, skipped: 0, eligible: 0) }
        return HabitAnalytics.summary(habits: [habit], from: range.start, through: range.end.addingTimeInterval(-1))
    }
    private var weekSummary: HabitPeriodSummary {
        guard let range = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return HabitPeriodSummary(completed: 0, pending: 0, skipped: 0, eligible: 0) }
        return HabitAnalytics.summary(habits: [habit], from: range.start, through: range.end.addingTimeInterval(-1), asOf: selectedDate)
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Previous month")
                    Spacer()
                    Text(visibleMonth.formatted(.dateTime.month(.wide).year())).font(.headline)
                    Spacer()
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Next month")
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(calendar.veryShortWeekdaySymbols.indices, id: \.self) { index in
                        Text(calendar.veryShortWeekdaySymbols[(index + calendar.firstWeekday - 1) % 7])
                            .font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                    ForEach(Array(monthDates.enumerated()), id: \.offset) { _, date in
                        if let date { dayCell(date) } else { Color.clear.frame(height: 40) }
                    }
                }
                HStack(spacing: 12) { legend("Completed", color: .green); legend("Skipped", color: .orange); legend("Missed", color: .red) }.font(.caption2)
                GroupBox("Selected day") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedDate.formatted(date: .complete, time: .omitted)).font(.headline)
                        Text(statusLabel).font(.subheadline).foregroundStyle(.secondary)
                        if isScheduled && selectedDate <= calendar.startOfDay(for: .now) {
                            HStack { statusButton("Complete", status: .completed); statusButton("Pending", status: .pending); statusButton("Skip", status: .skipped) }
                        }
                        if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { summaryCard("This week", weekSummary); summaryCard("This month", monthSummary) }
                HStack {
                    metric("Current streak", "\(HabitAnalytics.currentStreak(for: habit))")
                    metric("Longest streak", "\(HabitAnalytics.longestStreak(for: habit))")
                }
                Text("Missed means a scheduled past day without a saved record. Unscheduled days do not affect a habit's streak.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }.navigationTitle("Habit History")
    }
    private var statusLabel: String {
        if let dateStatus { return dateStatus.rawValue.capitalized }
        if missed { return "Missed scheduled day" }
        return isScheduled ? "Pending" : "Not scheduled"
    }
    private func dayCell(_ date: Date) -> some View {
        let status = habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }?.status
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        let scheduled = date >= calendar.startOfDay(for: habit.startDate) && habit.frequencyDays.contains(calendar.component(.weekday, from: date))
        let isMissed = scheduled && date < calendar.startOfDay(for: .now) && status == nil
        let fill: Color = status == .completed ? .green.opacity(0.25) : status == .skipped ? .orange.opacity(0.25) : isMissed ? .red.opacity(0.18) : .clear
        return Button { selectedDate = date } label: {
            Text("\(calendar.component(.day, from: date))").font(.subheadline).frame(maxWidth: .infinity).frame(height: 40)
                .background(fill, in: Circle()).overlay(Circle().stroke(selected ? Color.green : Color.clear, lineWidth: 2))
                .foregroundStyle(scheduled ? .primary : .tertiary)
        }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", " + (status?.rawValue ?? (isMissed ? "missed" : scheduled ? "pending" : "not scheduled")))
    }
    private func statusButton(_ title: String, status: RecordStatus) -> some View {
        Button(title) {
            do { try HabitTrackingService.setStatus(status, for: habit, on: selectedDate, in: context); errorMessage = nil }
            catch { errorMessage = error.localizedDescription }
        }.buttonStyle(.bordered).tint(status == .completed ? .green : status == .skipped ? .orange : .gray)
    }
    private func changeMonth(_ value: Int) {
        guard let date = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        visibleMonth = date; selectedDate = calendar.startOfDay(for: date)
    }
    private func legend(_ title: String, color: Color) -> some View { Label(title, systemImage: "circle.fill").foregroundStyle(color) }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) { Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
    private func summaryCard(_ title: String, _ summary: HabitPeriodSummary) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline); Text("\(summary.completed) complete / \(summary.eligible) scheduled").font(.caption)
            Text("\(Int(summary.completionRate * 100))%").font(.title3.bold()).foregroundStyle(.green)
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
