import SwiftUI
import SwiftData
struct ArchivedHabitsView: View {
    @Query private var habits: [Habit]
    var body: some View {
        List(habits.filter(\.isArchived)) { habit in
            HStack { Label(habit.name, systemImage: habit.icon); Spacer(); Button("Restore") {
                habit.isArchived = false
                if habit.reminderEnabled { Task { await NotificationService.shared.schedule(for: habit) } }
            } }
        }.navigationTitle("Archived Habits").overlay {
            if habits.allSatisfy({ !$0.isArchived }) { ContentUnavailableView("Nothing archived", systemImage: "archivebox") }
        }
    }
}
