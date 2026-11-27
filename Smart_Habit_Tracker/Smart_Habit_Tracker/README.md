# Smart Habit & Daily Routine Tracker

A SwiftUI app for planning habits, recording daily outcomes, and reviewing progress.

## Problem and objectives
Routines are easier to maintain when goals and progress are visible. This app lets people organize habits, track completion on calendar days, and review consistency over time.

## Features
- SwiftData persistence for habits and their completion records
- Weekday schedules, nine habit categories, reminders, and archive/restore
- Daily completion dashboard with progress and streak data
- Habit creation, editing, search, category/status/schedule/reminder/streak filters, and sorting
- Calendar history with completed, skipped, and missed scheduled days
- Daily, weekly, monthly, overall, streak, and category statistics with Swift Charts
- Optional LocalAuthentication using Face ID, Touch ID, or device passcode

## Technology and architecture
SwiftUI renders the screens. SwiftData stores Habit and HabitRecord models. HabitAnalytics and HabitTrackingService contain reusable validation, tracking, filtering, streak, and period-summary logic. Views use those services and @Query to stay current with stored data.

## Folder structure
- Models: persistent habit and record types
- Services: validation, tracking, analytics, streaks, and notifications
- ViewModels: dashboard presentation calculations
- Views: dashboard, habits, history, statistics, settings, and reusable cards
- Navigation: bottom tab view
- SmartHabitTrackerTests: XCTest coverage for validation and business calculations

## Data and history
Each habit owns completion records with a cascading delete relationship. A record is normalized to a local calendar day. The tracking service updates an existing record for that habit/day rather than adding a duplicate. Scheduled past dates without records appear as missed in the calendar history; unscheduled days do not count against a weekly streak.

## Authentication
Authentication is an optional app lock using LocalAuthentication's device-owner policy. The system can use biometrics or the device passcode. The app does not store a password.

## Notifications
Reminders use repeating local calendar triggers and stable per-habit/per-weekday identifiers. Permission can be requested in Settings. If permission is denied, iOS Settings is where it can be changed.

## Run
Open Untitled Project 3.xcodeproj in Xcode, choose the MyApp scheme and an iPhone simulator, then run. The app deployment target is iOS 17.0.

## Tests
The XCTest target contains tests for input validation, completion status changes, daily duplicate prevention, streaks, weekly frequencies, calendar/timezone behavior, period summaries, search, combined filters, sorting, reminders, and archived-habit handling. The target currently needs an Xcode app-target dependency/link configuration before the suite can execute; this is noted so test results are not mistaken for passing.

## Limitations and future work
Authentication is an optional local device lock, not a user account system. Notification scheduling is best-effort when permission is unavailable. Additional future work could include data export, more chart types, and a shareable project demo.
