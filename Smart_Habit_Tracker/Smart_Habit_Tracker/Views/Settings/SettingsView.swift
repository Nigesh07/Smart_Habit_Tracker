import SwiftUI
import SwiftData
import UserNotifications
struct SettingsView: View {
    @Query private var habits: [Habit]
    @AppStorage("biometricEnabled") private var biometricEnabled = false
    @State private var notificationStatus = "Checking…"
    var body: some View {
        NavigationStack {
            Form {
                Section("Preferences") {
                    Toggle("Require Face ID / Touch ID", isOn: $biometricEnabled)
                    LabeledContent("Notifications", value: notificationStatus)
                    Button("Request notification access") {
                        Task {
                            let allowed = await NotificationService.shared.requestPermission()
                            notificationStatus = allowed ? "Allowed" : "Not allowed"
                            if allowed { for habit in habits where habit.reminderEnabled { await NotificationService.shared.schedule(for: habit) } }
                        }
                    }
                }
                Section("About") {
                    LabeledContent("Smart Habit Tracker", value: "Version 1.0")
                    Text("Your habits and daily history are stored on this device.").font(.footnote).foregroundStyle(.secondary)
                }
            }.navigationTitle("Settings").task {
                let status = await UNUserNotificationCenter.current().notificationSettings()
                notificationStatus = status.authorizationStatus == .authorized ? "Allowed" : "Not allowed"
            }
        }
    }
}
