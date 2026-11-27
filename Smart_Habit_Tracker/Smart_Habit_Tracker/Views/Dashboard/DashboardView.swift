import SwiftUI
import SwiftData
struct DashboardView: View {
    @Query(sort: \Habit.createdAt) private var allHabits: [Habit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var trackingError: String?
    @State private var habitToDelete: Habit?
    private var vm: DashboardViewModel { DashboardViewModel(habits: allHabits, date: .now) }
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) { Text(greeting).font(.title2.bold()); Text(Date.now.formatted(date: .complete, time: .omitted)).foregroundStyle(.secondary) }
                        Spacer()
                        Image(systemName: "leaf.fill").font(.title2).foregroundStyle(.green).frame(width: 48, height: 48).background(.green.opacity(0.12), in: Circle())
                    }
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(.green.opacity(0.15), lineWidth: 12)
                            Circle().trim(from: 0, to: vm.progress).stroke(.green, style: StrokeStyle(lineWidth: 12, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack { Text("\(Int(vm.progress * 100))%").font(.title2.bold()); Text("today").font(.caption).foregroundStyle(.secondary) }
                        }.frame(width: 104, height: 104)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(vm.completedCount) of \(vm.scheduledHabits.count) habits complete").font(.headline)
                            Text("\(vm.scheduledHabits.count - vm.completedCount - vm.skippedCount) pending · \(vm.skippedCount) skipped").font(.subheadline).foregroundStyle(.secondary)
                            Label("\(vm.currentStreak) day streak", systemImage: "flame.fill").font(.subheadline.bold()).foregroundStyle(.orange)
                        }
                    }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.background, in: RoundedRectangle(cornerRadius: 22))
                    HStack { Text("Today’s routine").font(.title3.bold()); Spacer(); Button { showingAdd = true } label: { Label("Add", systemImage: "plus") } }
                    if vm.scheduledHabits.isEmpty {
                        ContentUnavailableView("A fresh start", systemImage: "leaf", description: Text("Add a habit to begin building your routine."))
                        Button("Add your first habit") { showingAdd = true }.buttonStyle(.borderedProminent).tint(.green).frame(maxWidth: .infinity)
                    } else {
                        ForEach(vm.scheduledHabits) { habit in
                            HabitCardView(habit: habit, status: vm.status(for: habit), action: { cycle(habit) }, onDelete: { habitToDelete = habit })
                        }
                    }
                }.padding()
            }.background(.background).navigationTitle("Habit Garden").sheet(isPresented: $showingAdd) { AddHabitView() }
                .alert("Could not update habit", isPresented: Binding(get: { trackingError != nil }, set: { if !$0 { trackingError = nil } })) {
                    Button("OK", role: .cancel) { trackingError = nil }
                } message: { Text(trackingError ?? "Please try again.") }
                .confirmationDialog("Delete this habit permanently?", isPresented: Binding(
                    get: { habitToDelete != nil },
                    set: { if !$0 { habitToDelete = nil } }
                ), titleVisibility: .visible) {
                    Button("Delete habit", role: .destructive) { deleteSelectedHabit() }
                    Button("Cancel", role: .cancel) { habitToDelete = nil }
                } message: {
                    Text("This also deletes its completion history.")
                }
        }
    }
    @MainActor private func cycle(_ habit: Habit) {
        let current = vm.status(for: habit)
        let next: RecordStatus = current == .pending ? .completed : current == .completed ? .skipped : .pending
        do { try HabitTrackingService.setStatus(next, for: habit, on: .now, in: context) }
        catch { trackingError = error.localizedDescription }
    }

    @MainActor private func deleteSelectedHabit() {
        guard let habit = habitToDelete else { return }
        NotificationService.shared.cancel(for: habit)
        context.delete(habit)
        do {
            try context.save()
            habitToDelete = nil
        } catch {
            trackingError = "The habit could not be deleted: \(error.localizedDescription)"
        }
    }
}
