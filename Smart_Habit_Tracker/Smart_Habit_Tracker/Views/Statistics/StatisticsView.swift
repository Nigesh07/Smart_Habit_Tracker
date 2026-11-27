import SwiftUI
import SwiftData
import Charts
struct StatisticsView: View {
    @Query private var habits: [Habit]
    private var calendar: Calendar { .current }
    private var active: [Habit] { habits.filter { !$0.isArchived } }
    private var today: Date { calendar.startOfDay(for: .now) }
    private var weekStart: Date { calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today }
    private var monthStart: Date { calendar.dateInterval(of: .month, for: today)?.start ?? today }
    private var daySummary: HabitPeriodSummary { HabitAnalytics.summary(habits: active, from: today, through: today) }
    private var weekSummary: HabitPeriodSummary { HabitAnalytics.summary(habits: active, from: weekStart, through: today) }
    private var monthSummary: HabitPeriodSummary { HabitAnalytics.summary(habits: active, from: monthStart, through: today) }
    private var longestStreak: Int { active.map { HabitAnalytics.longestStreak(for: $0) }.max() ?? 0 }
    private var currentStreak: Int { active.map { HabitAnalytics.currentStreak(for: $0) }.max() ?? 0 }
    private var completedTotal: Int { active.flatMap(\.records).filter { $0.status == .completed }.count }
    private var weeklyData: [ChartDay] { chartDays(start: weekStart, count: 7) }
    private var monthlyData: [ChartDay] { chartDays(start: monthStart, count: calendar.range(of: .day, in: .month, for: today)?.count ?? 30) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Your progress").font(.title2.bold())
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        stat("Today", percent(daySummary), "sun.max")
                        stat("This week", percent(weekSummary), "calendar")
                        stat("This month", percent(monthSummary), "calendar.circle")
                        stat("Overall rate", percent(overallSummary), "chart.pie")
                        stat("Active habits", "\(active.count)", "leaf")
                        stat("Completed days", "\(completedTotal)", "checkmark.circle")
                        stat("Current streak", "\(currentStreak)", "flame")
                        stat("Best streak", "\(longestStreak)", "trophy")
                    }
                    Text("Weekly completions").font(.headline)
                    if weekSummary.eligible == 0 { emptyChart } else {
                        Chart(weeklyData) { item in
                            BarMark(x: .value("Day", item.label), y: .value("Completed", item.completed))
                                .foregroundStyle(.green.gradient)
                        }.frame(height: 190)
                    }
                    Text("Monthly completions").font(.headline)
                    if monthSummary.eligible == 0 { emptyChart } else {
                        Chart(monthlyData) { item in
                            LineMark(x: .value("Day", item.label), y: .value("Completed", item.completed))
                                .foregroundStyle(.green).interpolationMethod(.catmullRom)
                            PointMark(x: .value("Day", item.label), y: .value("Completed", item.completed)).foregroundStyle(.green)
                        }.frame(height: 200)
                    }
                    Text("Completion by category").font(.headline)
                    let categoryCounts = HabitCategory.allCases.map { category in
                        CategoryTotal(category: category, count: active.filter { $0.category == category }.flatMap(\.records).filter { $0.status == .completed }.count)
                    }.filter { $0.count > 0 }
                    if categoryCounts.isEmpty { emptyChart } else {
                        Chart(categoryCounts) { item in
                            BarMark(x: .value("Category", item.category.rawValue), y: .value("Completed", item.count)).foregroundStyle(.green.gradient)
                        }.frame(height: 220)
                    }
                    Text("Completed \(monthSummary.completed) · Pending \(monthSummary.pending) · Skipped \(monthSummary.skipped) this month")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("Statistics")
        }
    }
    private var overallSummary: HabitPeriodSummary {
        guard let first = active.map(\.startDate).min() else { return HabitPeriodSummary(completed: 0, pending: 0, skipped: 0, eligible: 0) }
        return HabitAnalytics.summary(habits: active, from: first, through: today)
    }
    private var emptyChart: some View { ContentUnavailableView("No data yet", systemImage: "chart.bar", description: Text("Track scheduled habits to populate this chart.")) }
    private func percent(_ summary: HabitPeriodSummary) -> String { "\(Int((summary.completionRate * 100).rounded()))%" }
    private func stat(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: icon).foregroundStyle(.green); Text(value).font(.title2.bold()); Text(title).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 96, alignment: .leading).padding().background(.background, in: RoundedRectangle(cornerRadius: 18))
    }
    private func chartDays(start: Date, count: Int) -> [ChartDay] {
        (0..<count).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let summary = HabitAnalytics.summary(habits: active, from: date, through: date)
            return ChartDay(date: date, label: calendar.component(.day, from: date), completed: summary.completed)
        }
    }
}
private struct ChartDay: Identifiable {
    let date: Date
    let label: Int
    let completed: Int
    var id: Date { date }
}
private struct CategoryTotal: Identifiable {
    let category: HabitCategory
    let count: Int
    var id: String { category.rawValue }
}
