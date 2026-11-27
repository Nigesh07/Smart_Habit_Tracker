import SwiftUI
struct HabitCardView: View {
    let habit: Habit
    let status: RecordStatus
    let action: () -> Void
    let onDelete: () -> Void
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.icon).font(.title3).foregroundStyle(.green).frame(width: 46, height: 46).background(.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) { Text(habit.name).font(.headline); Text(habit.category.rawValue).font(.caption).foregroundStyle(.secondary) }
            Spacer()
            Button(action: action) { Image(systemName: status == .completed ? "checkmark.circle.fill" : status == .skipped ? "minus.circle.fill" : "circle").font(.title2).foregroundStyle(status == .completed ? .green : status == .skipped ? .gray : .secondary) }
                .buttonStyle(.plain).accessibilityLabel("Change status for \(habit.name)")
            Menu {
                Button(role: .destructive, action: onDelete) { Label("Delete habit", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis").font(.headline).foregroundStyle(.secondary).frame(width: 34, height: 40)
            }.accessibilityLabel("More actions for \(habit.name)")
        }.padding().background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
}
