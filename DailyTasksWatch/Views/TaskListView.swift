//
//  TaskListView.swift
//  DailyTasks Watch App
//
//  Created by Spencer Dearman.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyTask.createdAt, order: .reverse) private var tasks: [DailyTask]
    @AppStorage("lastResetDate") private var lastResetDateInterval: TimeInterval = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("bestStreak") private var bestStreak: Int = 0
    
    @State private var isShowingSheet = false
    @State private var newTaskTitle = ""
    @State private var showConfetti = false
    @State private var showingWalkConfirmation = false
    @State private var taskToDelete: DailyTask?
    
    var walkManager = WalkDetectionManager.shared
    
    private var visibleTasks: [DailyTask] {
        tasks.filter { task in
            if let hiddenDate = task.hiddenUntil {
                return hiddenDate <= Date()
            }
            return true
        }
    }
    
    private var allCompleted: Bool {
        !visibleTasks.isEmpty && visibleTasks.allSatisfy(\.isCompleted)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if allCompleted {
                    TasksCompleteView(totalTasks: visibleTasks.count)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    List {
                        Section {
                            ForEach(visibleTasks) { task in
                                NavigationLink(value: task) {
                                    TaskRowView(task: task)
                                }
                                .simultaneousGesture(
                                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                        taskToDelete = task
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: allCompleted)
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !allCompleted {
                    ToolbarItem(placement: .topBarLeading) {
                        ZStack {
                            ProgressView(
                                value: Double(visibleTasks.filter(\.isCompleted).count),
                                total: Double(max(1, visibleTasks.count))
                            )
                            .progressViewStyle(.circular)
                            .tint(.accentColor)
                            .glassEffect()
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: visibleTasks.filter(\.isCompleted).count)
                            
                            Text("\(visibleTasks.filter(\.isCompleted).count)")
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
            .navigationDestination(for: DailyTask.self) { targetTask in
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
                    dailyReset()
                    refreshWidget()
                }
                updateWalkMonitoring()
            }
            .onChange(of: tasks.map { $0.isCompleted }) { oldValue, newValue in
                refreshWidget()
                
                let completedCount = visibleTasks.filter(\.isCompleted).count
                let total = visibleTasks.count
                let remaining = total - completedCount
                SmartReminderManager.scheduleSmartReminder(total: total, remaining: remaining)
                updateWalkMonitoring()
                let wasAllCompleted = !oldValue.isEmpty && oldValue.allSatisfy { $0 }
                let isAllCompleted = !visibleTasks.isEmpty && visibleTasks.allSatisfy(\.isCompleted)
                
                if !wasAllCompleted && isAllCompleted {
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showConfetti = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showConfetti = false
                    }
                }
            }
            .onChange(of: visibleTasks.count) { _, newCount in
                refreshWidget()
                
                let completedCount = visibleTasks.filter(\.isCompleted).count
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
                    if let walkTask = tasks.first(where: { $0.title.lowercased().contains("walk") && !$0.isCompleted }) {
                        walkTask.isCompleted = true
                        saveChanges()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("We noticed you've been walking. Mark your walk task as complete?")
            }
            .confirmationDialog("Delete Task?", 
                                isPresented: Binding(
                                    get: { taskToDelete != nil },
                                    set: { if !$0 { taskToDelete = nil } }
                                ), 
                                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        deleteTask(task)
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
            .onReceive(NotificationCenter.default.publisher(for: .testNotification)) { _ in
#if DEBUG
                let remaining = tasks.filter { !$0.isCompleted }.count
                SmartReminderManager.scheduleSmartReminder(total: tasks.count, remaining: remaining)
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
                dailyReset()
                refreshWidget()
#endif
            }
        }
    }
    
    private func refreshWidget() {
        let completed = visibleTasks.filter(\.isCompleted).count
        WidgetDataManager.shared.updateWidgetData(completed: completed, total: visibleTasks.count)
    }
    
    private func updateWalkMonitoring() {
        let hasIncompleteWalk = visibleTasks.contains { $0.title.lowercased().contains("walk") && !$0.isCompleted }
        if scenePhase == .active && hasIncompleteWalk && !walkManager.walkDetected {
            walkManager.startMonitoring()
        } else {
            walkManager.stopMonitoring()
        }
    }
    
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = DailyTask(title: trimmedTitle)
        modelContext.insert(newTask)
        saveChanges()
        newTaskTitle = ""
        isShowingSheet = false
    }
    
    private func deleteTask(_ task: DailyTask) {
        modelContext.delete(task)
        saveChanges()
    }
    
    private func seedDefaultTasks() {
        if tasks.isEmpty {
            let defaults = ["🐕 Walk dog", "🪥 Brush teeth"]
            for title in defaults {
                let task = DailyTask(title: title, streak: 2)
                modelContext.insert(task)
            }
            
            saveChanges()
        }
    }
    
    private func dailyReset() {
        let lastReset = Date(timeIntervalSince1970: lastResetDateInterval)
        let today = Calendar.current.startOfDay(for: .now)
        if lastReset < today {
            WalkDetectionManager.shared.resetForNewDay()
            if visibleTasks.allSatisfy(\.isCompleted) && !visibleTasks.isEmpty {
                currentStreak += 1
                if currentStreak > bestStreak {
                    bestStreak = currentStreak
                }
            } else {
                currentStreak = 0
            }
            for task in tasks {
                let wasHidden = task.hiddenUntil != nil && task.hiddenUntil! > today
                
                if !wasHidden {
                    if task.isCompleted {
                        task.streak += 1
                    } else {
                        task.streak = 0
                    }
                } else if let hiddenDate = task.hiddenUntil, hiddenDate <= today {
                    task.hiddenUntil = nil
                }
                
                task.isCompleted = false
            }
            
            saveChanges()
        }
        lastResetDateInterval = today.timeIntervalSince1970
    }
    
    private func saveChanges() {
        guard modelContext.hasChanges else { return }
        
        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to save Daily Tasks changes: \(error)")
        }
    }
}
