import Foundation
import SwiftData

enum HabitValidationError: Error, Equatable, LocalizedError {
    case emptyName, nameTooLong, invalidCategory, invalidFrequency, invalidStartDate, invalidReminderTime, invalidRecordDate, invalidCompletionTime, missingHabit
    var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a habit name."
        case .nameTooLong: "Habit names must be 50 characters or fewer."
        case .invalidCategory: "Choose a supported category."
        case .invalidFrequency: "Choose one or more valid weekdays."
        case .invalidStartDate: "Choose a valid start date."
        case .invalidReminderTime: "Choose a valid reminder time."
        case .invalidRecordDate: "This record has an invalid date."
        case .invalidCompletionTime: "This completion time is invalid."
        case .missingHabit: "This record is not connected to a habit."
        }
    }
}
enum HabitRecordServiceError: Error, Equatable { case archivedHabit, beforeStartDate, invalidRecord }

enum HabitValidator {
    static func validate(name: String, categoryRaw: String, frequencyDays: [Int], startDate: Date, reminderEnabled: Bool, hour: Int, minute: Int) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HabitValidationError.emptyName }
        guard trimmed.count <= 50 else { throw HabitValidationError.nameTooLong }
        guard HabitCategory(rawValue: categoryRaw) != nil else { throw HabitValidationError.invalidCategory }
        guard !frequencyDays.isEmpty, Set(frequencyDays).count == frequencyDays.count, frequencyDays.allSatisfy({ (1...7).contains($0) }) else { throw HabitValidationError.invalidFrequency }
        guard startDate.timeIntervalSince1970.isFinite else { throw HabitValidationError.invalidStartDate }
        if reminderEnabled && (!(0...23).contains(hour) || !(0...59).contains(minute)) { throw HabitValidationError.invalidReminderTime }
    }
    static func validate(record: HabitRecord, calendar: Calendar = .current) throws {
        guard let habit = record.habit else { throw HabitValidationError.missingHabit }
        guard RecordStatus(rawValue: record.statusRaw) != nil,
              record.date.timeIntervalSince1970.isFinite,
              calendar.startOfDay(for: record.date) >= calendar.startOfDay(for: habit.startDate) else { throw HabitValidationError.invalidRecordDate }
        if let completedAt = record.completedAt,
           !completedAt.timeIntervalSince1970.isFinite || completedAt < record.date {
            throw HabitValidationError.invalidCompletionTime
        }
    }
}

@MainActor
enum HabitTrackingService {
    @discardableResult
    static func setStatus(_ status: RecordStatus, for habit: Habit, on date: Date, in context: ModelContext, calendar: Calendar = .current) throws -> HabitRecord {
        guard !habit.isArchived else { throw HabitRecordServiceError.archivedHabit }
        guard date.timeIntervalSince1970.isFinite,
              calendar.startOfDay(for: date) >= calendar.startOfDay(for: habit.startDate) else { throw HabitRecordServiceError.beforeStartDate }
        guard calendar.startOfDay(for: date) <= calendar.startOfDay(for: .now) else { throw HabitRecordServiceError.invalidRecord }
        try HabitValidator.validate(name: habit.name, categoryRaw: habit.categoryRaw, frequencyDays: habit.frequencyDays,
                                    startDate: habit.startDate, reminderEnabled: habit.reminderEnabled,
                                    hour: habit.reminderHour, minute: habit.reminderMinute)
        let day = calendar.startOfDay(for: date)
        let records = try context.fetch(FetchDescriptor<HabitRecord>())
        let matching = records.filter { $0.habit?.persistentModelID == habit.persistentModelID && calendar.isDate($0.date, inSameDayAs: day) }
        guard matching.count <= 1 else { throw HabitRecordServiceError.invalidRecord }
        let record: HabitRecord
        if let existing = matching.first { record = existing; record.statusRaw = status.rawValue }
        else { record = HabitRecord(date: day, status: status, habit: habit, calendar: calendar); context.insert(record) }
        record.completedAt = status == .completed ? .now : nil
        try HabitValidator.validate(record: record, calendar: calendar)
        return record
    }
}

struct HabitPeriodSummary {
    let completed: Int
    let pending: Int
    let skipped: Int
    let eligible: Int
    var completionRate: Double { eligible == 0 ? 0 : Double(completed) / Double(eligible) }
}

enum HabitSort: String, CaseIterable, Identifiable {
    case nameAscending = "Name A–Z", nameDescending = "Name Z–A", newest = "Recently created", oldest = "Oldest created"
    case highestStreak = "Highest streak", lowestStreak = "Lowest streak", completedFirst = "Completed first", pendingFirst = "Pending first"
    var id: String { rawValue }
}

enum HabitAnalytics {
    static func status(for habit: Habit, on date: Date, calendar: Calendar = .current) -> RecordStatus {
        habit.records.first { calendar.isDate($0.date, inSameDayAs: date) }?.status ?? .pending
    }
    static func summary(habits: [Habit], from start: Date, through end: Date, asOf: Date = .now, calendar: Calendar = .current) -> HabitPeriodSummary {
        guard start <= end else { return HabitPeriodSummary(completed: 0, pending: 0, skipped: 0, eligible: 0) }
        var completed = 0, pending = 0, skipped = 0, eligible = 0
        let lastDay = min(calendar.startOfDay(for: end), calendar.startOfDay(for: asOf))
        var day = calendar.startOfDay(for: start)
        while day <= lastDay {
            let weekday = calendar.component(.weekday, from: day)
            for habit in habits where !habit.isArchived && calendar.startOfDay(for: habit.startDate) <= day && habit.frequencyDays.contains(weekday) {
                eligible += 1
                switch status(for: habit, on: day, calendar: calendar) {
                case .completed: completed += 1
                case .pending: pending += 1
                case .skipped: skipped += 1
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return HabitPeriodSummary(completed: completed, pending: pending, skipped: skipped, eligible: eligible)
    }
    static func currentStreak(for habit: Habit, through date: Date = .now, calendar: Calendar = .current) -> Int {
        let completed = Set(habit.records.filter { $0.status == .completed }.map { calendar.startOfDay(for: $0.date) })
        var day = calendar.startOfDay(for: date)
        if !completed.contains(day), let yesterday = calendar.date(byAdding: .day, value: -1, to: day) { day = yesterday }
        var count = 0
        while day >= calendar.startOfDay(for: habit.startDate) {
            if habit.frequencyDays.contains(calendar.component(.weekday, from: day)) {
                guard completed.contains(day) else { break }
                count += 1
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
    static func longestStreak(for habit: Habit, calendar: Calendar = .current) -> Int {
        let completed = Set(habit.records.filter { $0.status == .completed }.map { calendar.startOfDay(for: $0.date) })
        guard let first = completed.min(), let last = completed.max() else { return 0 }
        var day = first, current = 0, longest = 0
        while day <= last {
            if habit.frequencyDays.contains(calendar.component(.weekday, from: day)) {
                if completed.contains(day) { current += 1; longest = max(longest, current) } else { current = 0 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return longest
    }
    static func filtered(_ habits: [Habit], search: String = "", category: HabitCategory? = nil, status: RecordStatus? = nil,
                         frequencyDay: Int? = nil, reminderEnabled: Bool? = nil, minimumStreak: Int? = nil,
                         includeArchived: Bool = false, on date: Date = .now, calendar: Calendar = .current) -> [Habit] {
        habits.filter { habit in
            (includeArchived || !habit.isArchived) &&
            (search.isEmpty || habit.name.localizedCaseInsensitiveContains(search)) &&
            (category == nil || habit.category == category) &&
            (status == nil || self.status(for: habit, on: date, calendar: calendar) == status) &&
            (frequencyDay.map { habit.frequencyDays.contains($0) } ?? true) &&
            (reminderEnabled.map { habit.reminderEnabled == $0 } ?? true) &&
            (minimumStreak.map { currentStreak(for: habit, through: date, calendar: calendar) >= $0 } ?? true)
        }
    }
    static func sorted(_ habits: [Habit], by sort: HabitSort, on date: Date = .now, calendar: Calendar = .current) -> [Habit] {
        habits.sorted { left, right in
            switch sort {
            case .nameAscending: left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            case .nameDescending: left.name.localizedCaseInsensitiveCompare(right.name) == .orderedDescending
            case .newest: left.createdAt > right.createdAt
            case .oldest: left.createdAt < right.createdAt
            case .highestStreak: currentStreak(for: left, through: date, calendar: calendar) > currentStreak(for: right, through: date, calendar: calendar)
            case .lowestStreak: currentStreak(for: left, through: date, calendar: calendar) < currentStreak(for: right, through: date, calendar: calendar)
            case .completedFirst: status(for: left, on: date, calendar: calendar) == .completed && status(for: right, on: date, calendar: calendar) != .completed
            case .pendingFirst: status(for: left, on: date, calendar: calendar) == .pending && status(for: right, on: date, calendar: calendar) != .pending
            }
        }
    }
}
