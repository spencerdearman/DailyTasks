//
//  TaskListView.swift
//  FluxWatch
//
//  Created by Spencer Dearman.
//

import SwiftData
import SwiftUI

// MARK: - TaskListView

/// Primary task list view showing today's tasks, progress, and supporting walk detection.
struct TaskListView: View {

    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(
        filter: #Predicate<TaskItem> { task in
            task.statusRaw != "completed" && task.statusRaw != "someday"
        },
        sort: \TaskItem.sortOrder
    ) private var activeTasks: [TaskItem]

    @AppStorage("lastResetDate") private var lastResetDateInterval: TimeInterval = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("bestStreak") private var bestStreak: Int = 0

    @State private var isShowingSheet = false
    @State private var newTaskTitle = ""
    @State private var showConfetti = false
    @State private var showingWalkConfirmation = false

    var walkManager = WalkDetectionManager.shared

    // MARK: - Computed Properties

    /// Tasks scheduled for today (whenDate is today) or overdue.
    private var todayTasks: [TaskItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        return activeTasks.filter { task in
            guard let whenDate = task.whenDate else { return false }
            return whenDate < tomorrow
        }
    }

    private var allCompleted: Bool {
        !todayTasks.isEmpty && todayTasks.allSatisfy(\.isCompleted)
    }

    private var completedCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if todayTasks.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No tasks today")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if allCompleted {
                    TasksCompleteView(totalTasks: todayTasks.count)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    List {
                        Section {
                            ForEach(todayTasks) { task in
                                NavigationLink(value: task) {
                                    TaskRowView(task: task)
                                }
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: allCompleted)
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !todayTasks.isEmpty && !allCompleted {
                    ToolbarItem(placement: .topBarLeading) {
                        ZStack {
                            ProgressView(
                                value: Double(completedCount),
                                total: Double(max(1, todayTasks.count))
                            )
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
                            .glassEffect()
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completedCount)

                            Text("\(completedCount)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.accentColor)
                        }
                        .frame(width: 34, height: 34)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSheet = true
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .navigationDestination(for: TaskItem.self) { targetTask in
                TaskDetailView(task: targetTask)
            }
            .sheet(isPresented: $isShowingSheet) {
                NavigationStack {
                    Form {
                        TextField("Task Title", text: $newTaskTitle)
                    }
                    .navigationTitle("New Task")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .close) {
                                isShowingSheet = false
                                newTaskTitle = ""
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            let inputEmpty = newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            Button(role: .confirm) {
                                addTask()
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .disabled(inputEmpty)
                            .tint(inputEmpty ? .clear : .accentColor)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .onAppear {
                refreshWidget()
                updateWalkMonitoring()

                if walkManager.walkDetected {
                    walkManager.resetWalkDetected()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingWalkConfirmation = true
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    dailyStreakCheck()
                    refreshWidget()
                }
                updateWalkMonitoring()
            }
            .onChange(of: completedCount) { oldValue, newValue in
                refreshWidget()

                let remaining = todayTasks.count - newValue
                SmartReminderManager.scheduleSmartReminder(total: todayTasks.count, remaining: remaining)
                updateWalkMonitoring()

                let wasAllCompleted = oldValue == todayTasks.count && todayTasks.count > 0
                let isAllCompleted = allCompleted

                if !wasAllCompleted && isAllCompleted {
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showConfetti = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showConfetti = false
                    }
                }
            }
            .onChange(of: todayTasks.count) { _, newCount in
                refreshWidget()

                let remaining = newCount - completedCount
                SmartReminderManager.scheduleSmartReminder(total: newCount, remaining: remaining)
                updateWalkMonitoring()
            }
            .overlay {
                if showConfetti {
                    ConfettiView()
                }
            }
            .sensoryFeedback(.success, trigger: showConfetti) { oldValue, newValue in
                !oldValue && newValue
            }
            .onChange(of: walkManager.walkDetected) { _, detected in
                if detected {
                    walkManager.resetWalkDetected()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingWalkConfirmation = true
                    }
                }
            }
            .confirmationDialog("Walk Detected", isPresented: $showingWalkConfirmation, titleVisibility: .visible) {
                Button("Mark Complete") {
                    if let walkTask = todayTasks.first(where: { $0.title.lowercased().contains("walk") && !$0.isCompleted }) {
                        walkTask.markComplete()
                        saveChanges()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("We noticed you've been walking. Mark your walk task as complete?")
            }
            .onReceive(NotificationCenter.default.publisher(for: .testNotification)) { _ in
#if DEBUG
                let remaining = todayTasks.filter { !$0.isCompleted }.count
                SmartReminderManager.scheduleSmartReminder(total: todayTasks.count, remaining: remaining)
#endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .testWalkSimulation)) { _ in
#if DEBUG
                walkManager.simulateWalkDetected()
#endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .testMidnightReset)) { _ in
#if DEBUG
                lastResetDateInterval = Date().addingTimeInterval(-86400 * 2).timeIntervalSince1970
                dailyStreakCheck()
                refreshWidget()
#endif
            }
        }
    }

    // MARK: - Private Methods

    /// Updates the widget with the latest completion counts.
    private func refreshWidget() {
        WidgetDataManager.shared.updateWidgetData(completed: completedCount, total: todayTasks.count)
    }

    /// Starts or stops walk monitoring based on task state and scene phase.
    private func updateWalkMonitoring() {
        let hasIncompleteWalk = todayTasks.contains { $0.title.lowercased().contains("walk") && !$0.isCompleted }
        if scenePhase == .active && hasIncompleteWalk && !walkManager.walkDetected {
            walkManager.startMonitoring()
        } else {
            walkManager.stopMonitoring()
        }
    }

    /// Creates a new task scheduled for today and saves it.
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let newTask = TaskItem(
            title: trimmedTitle,
            whenDate: Calendar.current.startOfDay(for: .now),
            isInInbox: false
        )
        modelContext.insert(newTask)
        saveChanges()
        newTaskTitle = ""
        isShowingSheet = false
    }

    /// Checks if a new day has started and updates the streak accordingly.
    private func dailyStreakCheck() {
        let lastReset = Date(timeIntervalSince1970: lastResetDateInterval)
        let today = Calendar.current.startOfDay(for: .now)
        if lastReset < today {
            WalkDetectionManager.shared.resetForNewDay()

            // Check yesterday's completion for streak
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
            let yesterdayEnd = today

            let yesterdayCompleted = activeTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= yesterday && completedAt < yesterdayEnd
            }

            if !yesterdayCompleted.isEmpty {
                currentStreak += 1
                if currentStreak > bestStreak {
                    bestStreak = currentStreak
                }
            } else {
                currentStreak = 0
            }

            lastResetDateInterval = today.timeIntervalSince1970
        }
    }

    /// Persists any pending model context changes.
    private func saveChanges() {
        guard modelContext.hasChanges else { return }

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Flux changes: \(error)")
        }
    }
}
