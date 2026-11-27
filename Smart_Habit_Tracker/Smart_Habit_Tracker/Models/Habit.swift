import Foundation
import SwiftData

enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case fitness = "Fitness", reading = "Reading", mindfulness = "Mindfulness", hydration = "Hydration", productivity = "Productivity", sleep = "Sleep", learning = "Learning", personal = "Personal", other = "Other"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .fitness: "figure.run"; case .reading: "book"; case .mindfulness: "brain.head.profile"; case .hydration: "drop"; case .productivity: "checkmark.seal"; case .sleep: "moon"; case .learning: "lightbulb"; case .personal: "heart"; case .other: "sparkles"
        }
    }
}
enum RecordStatus: String, Codable, CaseIterable { case pending, completed, skipped }

@Model final class Habit {
    var name: String
    var details: String
    var categoryRaw: String
    var icon: String
    var frequencyDays: [Int]
    var createdAt: Date
    var startDate: Date
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var isArchived: Bool
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \HabitRecord.habit) var records: [HabitRecord] = []
    var category: HabitCategory { HabitCategory(rawValue: categoryRaw) ?? .other }
    init(name: String, details: String = "", category: HabitCategory = .personal, icon: String? = nil, frequencyDays: [Int] = Array(1...7), startDate: Date = .now, reminderEnabled: Bool = false, reminderHour: Int = 9, reminderMinute: Int = 0, notes: String = "") {
        self.name = name; self.details = details; self.categoryRaw = category.rawValue; self.icon = icon ?? category.icon
        self.frequencyDays = frequencyDays; self.createdAt = .now; self.startDate = startDate
        self.reminderEnabled = reminderEnabled; self.reminderHour = reminderHour; self.reminderMinute = reminderMinute
        self.isArchived = false; self.notes = notes
    }
}

@Model final class HabitRecord {
    var date: Date
    var statusRaw: String
    var completedAt: Date?
    var notes: String
    var habit: Habit?
    var status: RecordStatus { RecordStatus(rawValue: statusRaw) ?? .pending }
    init(date: Date, status: RecordStatus, habit: Habit? = nil, notes: String = "", calendar: Calendar = .current) {
        self.date = calendar.startOfDay(for: date); self.statusRaw = status.rawValue
        self.completedAt = status == .completed ? .now : nil; self.habit = habit; self.notes = notes
    }
}
