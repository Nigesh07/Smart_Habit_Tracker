import SwiftUI
import SwiftData
struct AddHabitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var details = ""
    @State private var category: HabitCategory = .fitness
    @State private var selectedDays = Set(1...7)
    @State private var reminder = false
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 9)) ?? .now
    @State private var error: String?
    @State private var reminderAlert: String?
    @State private var isSaving = false
    private let days = Calendar.current.shortWeekdaySymbols
    var body: some View {
        NavigationStack {
            Form {
                Section("Your habit") {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $details, axis: .vertical)
                    Picker("Category", selection: $category) { ForEach(HabitCategory.allCases) { Text($0.rawValue).tag($0) } }
                }
                Section("Schedule") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(days[day - 1], isOn: Binding(get: { selectedDays.contains(day) }, set: { if $0 { selectedDays.insert(day) } else { selectedDays.remove(day) } }))
                    }
                }
                Section("Reminder") {
                    Toggle("Daily reminder", isOn: $reminder)
                    if reminder { DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.navigationTitle("New Habit").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .alert("Reminder unavailable", isPresented: Binding(get: { reminderAlert != nil }, set: { if !$0 { reminderAlert = nil } })) {
                Button("OK", role: .cancel) { reminderAlert = nil }
            } message: { Text(reminderAlert ?? "Check notification access in Settings.") }
        }
    }
    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        do {
            try HabitValidator.validate(name: cleanName, categoryRaw: category.rawValue, frequencyDays: selectedDays.sorted(),
                                        startDate: .now, reminderEnabled: reminder, hour: time.hour ?? 9, minute: time.minute ?? 0)
            let habit = Habit(name: cleanName, details: details, category: category, frequencyDays: selectedDays.sorted(),
                              reminderEnabled: reminder, reminderHour: time.hour ?? 9, reminderMinute: time.minute ?? 0)
            context.insert(habit)
            try context.save()
            guard reminder else { dismiss(); return }

            isSaving = true
            Task {
                let service = NotificationService.shared
                guard await service.requestPermission() else {
                    habit.reminderEnabled = false
                    try? context.save()
                    reminderAlert = service.lastError
                    isSaving = false
                    return
                }
                guard await service.schedule(for: habit) else {
                    habit.reminderEnabled = false
                    try? context.save()
                    reminderAlert = service.lastError
                    isSaving = false
                    return
                }
                dismiss()
            }
        } catch let validationError as LocalizedError { error = validationError.errorDescription ?? "Please check your habit details." }
        catch { self.error = "Please check your habit details." }
    }
}
