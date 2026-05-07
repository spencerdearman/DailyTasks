//
//  BackgroundScheduler.swift
//  FluxMac
//
//  Created by Spencer Dearman.
//

import Foundation
import SwiftData

// MARK: - BackgroundScheduler

/// Schedules overnight background jobs using `NSBackgroundActivityScheduler`.
///
/// Runs synthesis generation and proactive rescheduling while the Mac is idle.
final class BackgroundScheduler {

    // MARK: Shared Instance

    static let shared = BackgroundScheduler()

    // MARK: Private Properties

    private var synthesisActivity: NSBackgroundActivityScheduler?
    private var rescheduleActivity: NSBackgroundActivityScheduler?
    private var modelContainer: ModelContainer?

    private init() {}

    // MARK: Public Methods

    /// Registers overnight background activities with the provided container. Idempotent.
    func register(with container: ModelContainer) {
        guard modelContainer == nil else { return }
        modelContainer = container

        // Synthesis: run once between midnight and 6 AM
        let synthesis = NSBackgroundActivityScheduler(
            identifier: "com.spencerdearman.Flux.overnightSynthesis"
        )
        synthesis.repeats = true
        synthesis.interval = 24 * 60 * 60
        synthesis.tolerance = 6 * 60 * 60
        synthesis.qualityOfService = .utility
        synthesis.schedule { [weak self] completion in
            guard let self else { completion(.finished); return }
            Task {
                await self.runSynthesis()
                completion(.finished)
            }
        }
        synthesisActivity = synthesis

        // Reschedule: run overnight to clean up overdue tasks
        let reschedule = NSBackgroundActivityScheduler(
            identifier: "com.spencerdearman.Flux.overnightReschedule"
        )
        reschedule.repeats = true
        reschedule.interval = 24 * 60 * 60
        reschedule.tolerance = 6 * 60 * 60
        reschedule.qualityOfService = .utility
        reschedule.schedule { [weak self] completion in
            guard let self else { completion(.finished); return }
            Task {
                await self.runReschedule()
                completion(.finished)
            }
        }
        rescheduleActivity = reschedule

        print("[BackgroundScheduler] Registered overnight jobs")
    }

    // MARK: - Overnight Synthesis

    @MainActor
    private func runSynthesis() async {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else {
            print("[BackgroundScheduler] No API key, skipping synthesis")
            return
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        // Check if we already generated one for today
        let descriptor = FetchDescriptor<DailySynthesis>(
            predicate: #Predicate { $0.date >= today }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            print("[BackgroundScheduler] Synthesis already exists for today")
            return
        }

        // Fetch data
        let taskDescriptor = FetchDescriptor<TaskItem>()
        let areaDescriptor = FetchDescriptor<Area>(sortBy: [SortDescriptor(\.sortOrder)])
        guard let allTasks = try? context.fetch(taskDescriptor),
              let areas = try? context.fetch(areaDescriptor) else {
            return
        }

        let activeTasks = allTasks.filter { $0.status == .active }
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today
        let completedYesterday = allTasks.filter {
            guard let d = $0.completedAt else { return false }
            return d >= yesterday && d < today
        }

        // Get calendar events
        let calendarStore = CalendarStore()
        calendarStore.refresh()
        try? await Task.sleep(for: .seconds(2))

        let service = SynthesisService()
        do {
            let result = try await service.generate(
                activeTasks: activeTasks,
                calendarEvents: calendarStore.allEvents,
                areas: areas,
                completedYesterday: completedYesterday,
                apiKey: apiKey
            )

            let overdue = activeTasks.filter {
                guard let d = $0.effectiveDate else { return false }
                return d < today
            }

            let synthesis = DailySynthesis(
                date: today,
                greeting: result.greeting,
                conflicts: result.conflicts,
                overdueCount: overdue.count,
                suggestedPlan: result.suggestedPlan
            )
            context.insert(synthesis)
            try? context.save()
            print("[BackgroundScheduler] Generated overnight synthesis")
        } catch {
            print("[BackgroundScheduler] Synthesis failed: \(error)")
        }
    }

    // MARK: - Overnight Reschedule

    /// Pushes all overdue tasks to today so they appear in the daily view.
    @MainActor
    private func runReschedule() async {
        guard let container = modelContainer else { return }
        let context = container.mainContext
        let apiKey = UserDefaults.standard.string(forKey: "geminiAPIKey") ?? ""
        guard !apiKey.isEmpty else { return }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let taskDescriptor = FetchDescriptor<TaskItem>()
        guard let allTasks = try? context.fetch(taskDescriptor) else { return }

        let overdue = allTasks.filter {
            $0.status == .active &&
            $0.effectiveDate != nil &&
            $0.effectiveDate! < today
        }

        guard !overdue.isEmpty else {
            print("[BackgroundScheduler] No overdue tasks to reschedule")
            return
        }

        for task in overdue {
            task.whenDate = today
            task.updatedAt = .now
        }
        try? context.save()
        print("[BackgroundScheduler] Rescheduled \(overdue.count) overdue tasks to today")
    }
}
