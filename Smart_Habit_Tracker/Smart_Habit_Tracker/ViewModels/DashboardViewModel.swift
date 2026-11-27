import Foundation
struct DashboardViewModel {
    let habits: [Habit]
    let date: Date
    private var calendar: Calendar { .current }
    var scheduledHabits: [Habit] {
        habits.filter { !$0.isArchived && calendar.startOfDay(for: $0.startDate) <= calendar.startOfDay(for: date) && $0.frequencyDays.contains(calendar.component(.weekday, from: date)) }
    }
    func status(for habit: Habit) -> RecordStatus { HabitAnalytics.status(for: habit, on: date, calendar: calendar) }
    var completedCount: Int { scheduledHabits.filter { status(for: $0) == .completed }.count }
    var skippedCount: Int { scheduledHabits.filter { status(for: $0) == .skipped }.count }
    var pendingCount: Int { scheduledHabits.filter { status(for: $0) == .pending }.count }
    var progress: Double { scheduledHabits.isEmpty ? 0 : Double(completedCount) / Double(scheduledHabits.count) }
    var currentStreak: Int { habits.filter { !$0.isArchived }.map { HabitAnalytics.currentStreak(for: $0, through: date) }.max() ?? 0 }
}
