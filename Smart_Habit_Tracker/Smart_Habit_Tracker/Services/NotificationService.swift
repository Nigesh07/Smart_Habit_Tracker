import Foundation
import SwiftData
import UserNotifications

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    private(set) var lastError: String?

    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus != .denied else {
            lastError = "Notifications are turned off for this app. Enable them in iPhone Settings to receive reminders."
            return false
        }
        do {
            let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            lastError = allowed ? nil : "Notification permission was not granted. Enable notifications in iPhone Settings."
            return allowed
        } catch {
            lastError = "Could not request notification permission: \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func schedule(for habit: Habit) async -> Bool {
        cancel(for: habit)
        guard habit.reminderEnabled else { lastError = nil; return true }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
                settings.authorizationStatus == .provisional ||
                settings.authorizationStatus == .ephemeral else {
            lastError = "Notifications are not allowed. Enable them in iPhone Settings to receive habit reminders."
            return false
        }
        guard (0...23).contains(habit.reminderHour), (0...59).contains(habit.reminderMinute),
              !habit.frequencyDays.isEmpty, habit.frequencyDays.allSatisfy({ (1...7).contains($0) }) else {
            lastError = "The reminder time or weekly schedule is invalid."
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "Time for \(habit.name)"
        content.body = habit.details.isEmpty ? "Keep your routine going today." : habit.details
        content.sound = .default

        for weekday in Set(habit.frequencyDays) {
            var components = DateComponents()
            components.calendar = .current
            components.timeZone = Calendar.current.timeZone
            components.hour = habit.reminderHour
            components.minute = habit.reminderMinute
            components.weekday = weekday
            let request = UNNotificationRequest(
                identifier: identifier(for: habit, weekday: weekday),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            )
            do {
                try await center.add(request)
            } catch {
                cancel(for: habit)
                lastError = "Could not schedule the reminder: \(error.localizedDescription)"
                return false
            }
        }
        lastError = nil
        return true
    }

    func cancel(for habit: Habit) {
        let identifiers = (1...7).map { identifier(for: habit, weekday: $0) }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    private func identifier(for habit: Habit, weekday: Int) -> String {
        "habit-\(habit.persistentModelID)-\(weekday)"
    }
}
