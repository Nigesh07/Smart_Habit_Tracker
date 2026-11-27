import SwiftUI
import SwiftData
struct HabitListView: View {
    @Query(sort: \Habit.createdAt, order: .reverse) private var habits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var category: HabitCategory?
    @State private var status: RecordStatus?
    @State private var weekday: Int?
    @State private var reminder: Bool?
    @State private var streakOnly = false
    @State private var showArchived = false
    @State private var sort: HabitSort = .newest
    @State private var showingAdd = false
    @State private var deleteError: String?
    private var filtered: [Habit] {
        let matching = HabitAnalytics.filtered(habits, search: search, category: category, status: status, frequencyDay: weekday,
                                               reminderEnabled: reminder, minimumStreak: streakOnly ? 1 : nil,
                                               includeArchived: showArchived, on: .now)
        return HabitAnalytics.sorted(matching, by: sort)
    }
    var body: some View {
        NavigationStack {
            List {
                Section("Filters") {
                    TextField("Search habits", text: $search)
                    Picker("Category", selection: $category) {
                        Text("All categories").tag(HabitCategory?.none)
                        ForEach(HabitCategory.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    Picker("Today’s status", selection: $status) {
                        Text("Any status").tag(RecordStatus?.none)
                        ForEach(RecordStatus.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) }
                    }
                    Picker("Scheduled weekday", selection: $weekday) {
                        Text("Any schedule").tag(Int?.none)
                        ForEach(1...7, id: \.self) { day in Text(Calendar.current.weekdaySymbols[day - 1]).tag(Optional(day)) }
                    }
                    Picker("Reminder", selection: $reminder) {
                        Text("Any").tag(Bool?.none); Text("Enabled").tag(Optional(true)); Text("Disabled").tag(Optional(false))
                    }
                    Toggle("Has a current streak", isOn: $streakOnly)
                    Toggle("Include archived habits", isOn: $showArchived)
                    Picker("Sort", selection: $sort) { ForEach(HabitSort.allCases) { Text($0.rawValue).tag($0) } }
                    Button("Reset filters") {
                        search = ""; category = nil; status = nil; weekday = nil; reminder = nil
                        streakOnly = false; showArchived = false; sort = .newest
                    }
                }
                if filtered.isEmpty {
                    ContentUnavailableView("No matching habits", systemImage: "line.3.horizontal.decrease.circle", description: Text("Adjust or reset the filters."))
                } else {
                    Section("Habits · \(filtered.count)") {
                        ForEach(filtered) { habit in
                            NavigationLink { HabitDetailView(habit: habit) } label: {
                                HStack {
                                    Image(systemName: habit.icon).foregroundStyle(.green)
                                    VStack(alignment: .leading) {
                                        Text(habit.name)
                                        Text("\(habit.category.rawValue) · \(HabitAnalytics.currentStreak(for: habit)) day streak").font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(HabitAnalytics.status(for: habit, on: .now).rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                                }
                            }.swipeActions {
                                Button {
                                    habit.isArchived.toggle()
                                    if habit.isArchived { NotificationService.shared.cancel(for: habit) }
                                    else if habit.reminderEnabled { Task { await NotificationService.shared.schedule(for: habit) } }
                                } label: { Label(habit.isArchived ? "Restore" : "Archive", systemImage: "archivebox") }.tint(.orange)
                                Button(role: .destructive) { deleteHabit(habit) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    }
                }
            }.navigationTitle("My Habits").toolbar {
                ToolbarItem { Button { showingAdd = true } label: { Image(systemName: "plus") } }
                ToolbarItem { NavigationLink("Archive") { ArchivedHabitsView() } }
            }.sheet(isPresented: $showingAdd) { AddHabitView() }
                .alert("Could not delete habit", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                    Button("OK", role: .cancel) { deleteError = nil }
                } message: { Text(deleteError ?? "Please try again.") }
        }
    }

    @MainActor private func deleteHabit(_ habit: Habit) {
        NotificationService.shared.cancel(for: habit)
        context.delete(habit)
        do { try context.save() }
        catch { deleteError = error.localizedDescription }
    }
}
