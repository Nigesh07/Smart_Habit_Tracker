import SwiftUI
struct AppTabView: View {
    var body: some View {
        TabView {
            DashboardView().tabItem { Label("Home", systemImage: "house.fill") }
            HabitListView().tabItem { Label("Habits", systemImage: "checklist") }
            StatisticsView().tabItem { Label("Stats", systemImage: "chart.bar.fill") }
            SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }.tint(.green)
    }
}
