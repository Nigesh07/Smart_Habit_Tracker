import Foundation
enum StreakCalculationService {
    static func currentStreak(for habit: Habit, through date: Date = .now, calendar: Calendar = .current) -> Int {
        HabitAnalytics.currentStreak(for: habit, through: date, calendar: calendar)
    }
    static func longestStreak(for habit: Habit, calendar: Calendar = .current) -> Int {
        HabitAnalytics.longestStreak(for: habit, calendar: calendar)
    }
}
