import SwiftUI
import SwiftData

@main
struct MyApp: App {
    init() {
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationView()
        }
        .modelContainer(for: [Habit.self, HabitRecord.self])
    }
}
