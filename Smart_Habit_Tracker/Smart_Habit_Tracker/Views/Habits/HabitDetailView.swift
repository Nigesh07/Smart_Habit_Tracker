import SwiftUI
import SwiftData
struct HabitDetailView: View {
    @Bindable var habit: Habit
    @Environment(\.modelContext) private var context
    @State private var showingEdit = false
    @State private var showingDelete = false
    @State private var deleteError: String?
    private var completed: Int { habit.records.filter { $0.status == .completed }.count }
    var body: some View {
        List {
            Section {
                Label(habit.name, systemImage: habit.icon).font(.title2.bold())
                Text(habit.details.isEmpty ? "No description" : habit.details).foregroundStyle(.secondary)
                LabeledContent("Category", value: habit.category.rawValue)
                LabeledContent("Started", value: habit.startDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Completed days", value: "\(completed)")
                LabeledContent("Reminder", value: habit.reminderEnabled ? String(format: "%02d:%02d", habit.reminderHour, habit.reminderMinute) : "Off")
            }
            Section("Progress") {
                NavigationLink("View calendar history") { HabitHistoryView(habit: habit) }
                LabeledContent("Current streak", value: "\(HabitAnalytics.currentStreak(for: habit)) days")
                LabeledContent("Longest streak", value: "\(HabitAnalytics.longestStreak(for: habit)) days")
            }
            Section("Recent history") {
                ForEach(habit.records.sorted { $0.date > $1.date }) { record in LabeledContent(record.date.formatted(date: .abbreviated, time: .omitted), value: record.status.rawValue.capitalized) }
                if habit.records.isEmpty { Text("Your history will appear here.").foregroundStyle(.secondary) }
            }
            Section {
                Button(habit.isArchived ? "Restore habit" : "Archive habit") {
                    habit.isArchived.toggle()
                    if habit.isArchived { NotificationService.shared.cancel(for: habit) }
                    else if habit.reminderEnabled { Task { await NotificationService.shared.schedule(for: habit) } }
                }
                Button("Delete habit", role: .destructive) { showingDelete = true }
            }
        }.navigationTitle("Habit details")
            .toolbar { ToolbarItem(placement: .automatic) { Button("Edit") { showingEdit = true } } }
            .sheet(isPresented: $showingEdit) { EditHabitView(habit: habit) }
            .confirmationDialog("Delete this habit and its history?", isPresented: $showingDelete, titleVisibility: .visible) {
                Button("Delete permanently", role: .destructive) { deleteHabit() }
            }
            .alert("Could not delete habit", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: { Text(deleteError ?? "Please try again.") }
    }

    @MainActor private func deleteHabit() {
        NotificationService.shared.cancel(for: habit)
        context.delete(habit)
        do { try context.save() }
        catch { deleteError = error.localizedDescription }
    }
}

struct EditHabitView: View {
    @Bindable var habit: Habit
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name: String
    @State private var details: String
    @State private var category: HabitCategory
    @State private var days: Set<Int>
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date
    @State private var reminderAlert: String?
    @State private var isSaving = false
    init(habit: Habit) {
        self.habit = habit; _name = State(initialValue: habit.name); _details = State(initialValue: habit.details)
        _category = State(initialValue: habit.category); _days = State(initialValue: Set(habit.frequencyDays))
        _reminderEnabled = State(initialValue: habit.reminderEnabled)
        _reminderTime = State(initialValue: Calendar.current.date(from: DateComponents(hour: habit.reminderHour, minute: habit.reminderMinute)) ?? .now)
    }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Description", text: $details, axis: .vertical)
                Picker("Category", selection: $category) { ForEach(HabitCategory.allCases) { Text($0.rawValue).tag($0) } }
                ForEach(1...7, id: \.self) { day in
                    Toggle(Calendar.current.shortWeekdaySymbols[day - 1], isOn: Binding(get: { days.contains(day) }, set: { if $0 { days.insert(day) } else { days.remove(day) } }))
                }
                Section("Reminder") {
                    Toggle("Daily reminder", isOn: $reminderEnabled)
                    if reminderEnabled { DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                }
            }.navigationTitle("Edit Habit").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let time = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                        do {
                            try HabitValidator.validate(name: value, categoryRaw: category.rawValue, frequencyDays: days.sorted(),
                                                        startDate: habit.startDate, reminderEnabled: reminderEnabled,
                                                        hour: time.hour ?? 9, minute: time.minute ?? 0)
                            habit.name = value; habit.details = details; habit.categoryRaw = category.rawValue
                            habit.icon = category.icon; habit.frequencyDays = days.sorted()
                            habit.reminderEnabled = reminderEnabled
                            habit.reminderHour = time.hour ?? 9; habit.reminderMinute = time.minute ?? 0
                            try context.save()
                            isSaving = true
                            Task {
                                let service = NotificationService.shared
                                var permissionGranted = true
                                if reminderEnabled {
                                    permissionGranted = await service.requestPermission()
                                }
                                if !permissionGranted {
                                    habit.reminderEnabled = false
                                    try? context.save()
                                    reminderAlert = service.lastError
                                    isSaving = false
                                    return
                                }
                                if !(await service.schedule(for: habit)) {
                                    habit.reminderEnabled = false
                                    try? context.save()
                                    reminderAlert = service.lastError
                                    isSaving = false
                                    return
                                }
                                dismiss()
                            }
                        } catch { reminderAlert = error.localizedDescription }
                    }.disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || days.isEmpty)
                }
            }
            .alert("Reminder unavailable", isPresented: Binding(get: { reminderAlert != nil }, set: { if !$0 { reminderAlert = nil } })) {
                Button("OK", role: .cancel) { reminderAlert = nil }
            } message: { Text(reminderAlert ?? "Please check the reminder settings.") }
        }
    }
}
