import XCTest
import SwiftData
@testable import MyApp

final class SmartHabitTrackerTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        value.firstWeekday = 2
        return value
    }
    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? .distantPast
    }
    private func makeHabit(days: [Int] = Array(1...7), start: Date? = nil) -> Habit {
        Habit(name: "Read", category: .reading, frequencyDays: days, startDate: start ?? date(2025, 1, 1))
    }
    private func record(_ habit: Habit, _ day: Date, _ status: RecordStatus) {
        habit.records.append(HabitRecord(date: day, status: status, habit: habit))
    }

    func testHabitValidationAcceptsValidAndRejectsEmptyNameAndInvalidFrequency() throws {
        XCTAssertNoThrow(try HabitValidator.validate(name: " Read ", categoryRaw: HabitCategory.reading.rawValue, frequencyDays: [2, 4], startDate: date(2025, 1, 1), reminderEnabled: true, hour: 8, minute: 30))
        XCTAssertThrowsError(try HabitValidator.validate(name: "   ", categoryRaw: "Reading", frequencyDays: [2], startDate: date(2025, 1, 1), reminderEnabled: false, hour: 9, minute: 0))
        XCTAssertThrowsError(try HabitValidator.validate(name: "Read", categoryRaw: "Unknown", frequencyDays: [2], startDate: date(2025, 1, 1), reminderEnabled: false, hour: 9, minute: 0))
        XCTAssertThrowsError(try HabitValidator.validate(name: "Read", categoryRaw: "Reading", frequencyDays: [0, 2], startDate: date(2025, 1, 1), reminderEnabled: false, hour: 9, minute: 0))
        XCTAssertThrowsError(try HabitValidator.validate(name: "Read", categoryRaw: "Reading", frequencyDays: [2], startDate: date(2025, 1, 1), reminderEnabled: true, hour: 25, minute: 0))
    }

    func testStatusChangesUpdateSingleDailyRecord() async throws {
        let container = try ModelContainer(for: Habit.self, HabitRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let habit = makeHabit()
        context.insert(habit)
        try await MainActor.run {
            try HabitTrackingService.setStatus(.completed, for: habit, on: date(2025, 1, 2, hour: 23), in: context, calendar: calendar)
            try HabitTrackingService.setStatus(.skipped, for: habit, on: date(2025, 1, 2, hour: 1), in: context, calendar: calendar)
        }
        XCTAssertEqual(habit.records.count, 1)
        XCTAssertEqual(habit.records.first?.status, .skipped)
        XCTAssertNil(habit.records.first?.completedAt)
        try await MainActor.run { try HabitTrackingService.setStatus(.completed, for: habit, on: date(2025, 1, 2), in: context, calendar: calendar) }
        XCTAssertEqual(habit.records.count, 1)
        XCTAssertEqual(habit.records.first?.status, .completed)
        XCTAssertNotNil(habit.records.first?.completedAt)
        try await MainActor.run { try HabitTrackingService.setStatus(.pending, for: habit, on: date(2025, 1, 2), in: context, calendar: calendar) }
        XCTAssertEqual(habit.records.first?.status, .pending)
    }

    func testCurrentStreakAndLongestStreakAndBrokenDay() {
        let habit = makeHabit()
        record(habit, date(2025, 1, 1), .completed)
        record(habit, date(2025, 1, 2), .completed)
        record(habit, date(2025, 1, 3), .skipped)
        record(habit, date(2025, 1, 4), .completed)
        XCTAssertEqual(HabitAnalytics.currentStreak(for: habit, through: date(2025, 1, 4), calendar: calendar), 1)
        XCTAssertEqual(HabitAnalytics.longestStreak(for: habit, calendar: calendar), 2)
    }

    func testWeeklyFrequencyDoesNotBreakAcrossUnscheduledDays() {
        let monday = calendar.component(.weekday, from: date(2025, 1, 6))
        let nextMonday = date(2025, 1, 13)
        let habit = makeHabit(days: [monday])
        record(habit, date(2025, 1, 6), .completed)
        record(habit, nextMonday, .completed)
        XCTAssertEqual(HabitAnalytics.currentStreak(for: habit, through: nextMonday, calendar: calendar), 2)
        XCTAssertEqual(HabitAnalytics.longestStreak(for: habit, calendar: calendar), 2)
    }

    func testDateBoundaryUsesCalendarDayAndTimezone() {
        var newYork = calendar
        newYork.timeZone = TimeZone(identifier: "America/New_York") ?? calendar.timeZone
        let habit = makeHabit(start: newYork.startOfDay(for: date(2025, 3, 8)))
        let firstInstant = date(2025, 3, 9, hour: 4)
        let sameLocalDay = date(2025, 3, 9, hour: 23)
        record(habit, firstInstant, .completed)
        XCTAssertEqual(HabitAnalytics.status(for: habit, on: sameLocalDay, calendar: newYork), .completed)
    }

    func testSummaryCountsCompletedPendingSkippedAndPercentage() {
        let start = date(2025, 1, 6)
        let habit = makeHabit(days: [calendar.component(.weekday, from: start), calendar.component(.weekday, from: date(2025, 1, 7))])
        record(habit, start, .completed)
        record(habit, date(2025, 1, 7), .skipped)
        let summary = HabitAnalytics.summary(habits: [habit], from: start, through: date(2025, 1, 7), asOf: date(2025, 1, 7), calendar: calendar)
        XCTAssertEqual(summary.eligible, 2)
        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.skipped, 1)
        XCTAssertEqual(summary.pending, 0)
        XCTAssertEqual(summary.completionRate, 0.5, accuracy: 0.001)
    }

    func testSummaryCountsPendingHabitsAndExcludesArchived() {
        let start = date(2025, 1, 6)
        let active = makeHabit(days: [calendar.component(.weekday, from: start)])
        let archived = makeHabit(days: [calendar.component(.weekday, from: start)])
        archived.isArchived = true
        let summary = HabitAnalytics.summary(habits: [active, archived], from: start, through: start, asOf: start, calendar: calendar)
        XCTAssertEqual(summary.eligible, 1)
        XCTAssertEqual(summary.pending, 1)
    }

    func testSearchCategoryStatusAndCombinedFilters() {
        let today = date(2025, 1, 6)
        let reading = makeHabit(days: [calendar.component(.weekday, from: today)])
        reading.name = "Read a book"
        reading.categoryRaw = HabitCategory.reading.rawValue
        record(reading, today, .completed)
        let fitness = makeHabit(days: [calendar.component(.weekday, from: today)])
        fitness.name = "Run"
        fitness.categoryRaw = HabitCategory.fitness.rawValue
        let habits = [reading, fitness]
        XCTAssertEqual(HabitAnalytics.filtered(habits, search: "book", on: today, calendar: calendar).count, 1)
        XCTAssertEqual(HabitAnalytics.filtered(habits, category: .fitness, on: today, calendar: calendar).first?.name, "Run")
        XCTAssertEqual(HabitAnalytics.filtered(habits, status: .completed, on: today, calendar: calendar).first?.name, "Read a book")
        XCTAssertEqual(HabitAnalytics.filtered(habits, search: "read", category: .reading, status: .completed, on: today, calendar: calendar).count, 1)
    }

    func testReminderAndFrequencyFiltersAndSorting() {
        let first = makeHabit()
        first.name = "Zebra"
        first.reminderEnabled = true
        let second = makeHabit()
        second.name = "Apple"
        let sorted = HabitAnalytics.sorted([first, second], by: .nameAscending, calendar: calendar)
        XCTAssertEqual(sorted.first?.name, "Apple")
        XCTAssertEqual(HabitAnalytics.filtered([first, second], reminderEnabled: true, on: .now).count, 1)
        XCTAssertEqual(HabitAnalytics.filtered([first, second], frequencyDay: 1, on: .now).count, 2)
    }

    func testArchiveRestoreAndActiveStatistics() {
        let today = date(2025, 1, 6)
        let habit = makeHabit(days: [calendar.component(.weekday, from: today)])
        habit.isArchived = true
        XCTAssertTrue(HabitAnalytics.filtered([habit], on: today, calendar: calendar).isEmpty)
        XCTAssertEqual(HabitAnalytics.filtered([habit], includeArchived: true, on: today, calendar: calendar).count, 1)
        habit.isArchived = false
        XCTAssertEqual(HabitAnalytics.summary(habits: [habit], from: today, through: today, asOf: today, calendar: calendar).eligible, 1)
    }
}
