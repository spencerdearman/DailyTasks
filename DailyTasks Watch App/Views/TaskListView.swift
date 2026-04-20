//
//  TaskListView.swift
//  DailyTasks
//
//  Created by Spencer Dearman on 4/12/26.
//

import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \DailyTask.createdAt, order: .reverse) private var tasks: [DailyTask]
    
    // App storage to persist app terminations
    @AppStorage("lastResetDate") private var lastResetDateInterval: TimeInterval = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
    
    // Storing current streak and best streak in App Storage
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("bestStreak") private var bestStreak: Int = 0
    
    @State private var isShowingSheet = false
    @State private var newTaskTitle = ""
    @State private var showConfetti = false
    @State private var showingWalkConfirmation = false
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
                    AllDoneView(totalTasks: tasks.count)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    List {
                        Section {
                            ForEach(visibleTasks) { task in
                                NavigationLink(value: task) {
                                    TaskRow(task: task)
                                }
                            }
                            .onDelete(perform: deleteTasks)
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
                            Circle()
                                .glassEffect(.regular.tint(.blue).interactive())
                            
                            ProgressView(
                                value: Double(tasks.filter(\.isCompleted).count),
                                total: Double(max(1, tasks.count))
                            )
                            .progressViewStyle(.circular)
                            .glassEffect(.regular.tint(.blue).interactive())
//                            .tint(.blue)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tasks.filter(\.isCompleted).count)
                            
                            Text("\(tasks.filter(\.isCompleted).count)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                seedDefaultTasks()
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
                
                // Using generic tasks mapped values explicitly works effectively assuming lengths match locally upon changes
                let wasAllCompleted = !oldValue.isEmpty && oldValue.allSatisfy { $0 }
                let isAllCompleted = !visibleTasks.isEmpty && visibleTasks.allSatisfy(\.isCompleted)
                
                if !wasAllCompleted && isAllCompleted {
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000) // 0.6 second delay
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
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("We noticed you've been walking. Mark your walk task as complete?")
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
    
    // MARK: - Logic Functions
    
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        
        let newTask = DailyTask(title: trimmedTitle)
        modelContext.insert(newTask)
        
        // Reset state
        newTaskTitle = ""
        isShowingSheet = false
    }
    
    private func deleteTasks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(tasks[index])
        }
    }
    
    private func seedDefaultTasks() {
        if tasks.isEmpty {
            let defaults = ["🐕 Walk dog", "🪥 Brush teeth"]
            for title in defaults {
                let task = DailyTask(title: title, streak: 2)
                modelContext.insert(task)
            }
        }
    }
    
    private func dailyReset() {
        let lastReset = Date(timeIntervalSince1970: lastResetDateInterval)
        let today = Calendar.current.startOfDay(for: .now)
        
        // Update tasks and streaks for a new day
        if lastReset < today {
            WalkDetectionManager.shared.resetForNewDay()
            
            // Handle general streak trends (evaluating exactly what was visibly achievable)
            if visibleTasks.allSatisfy(\.isCompleted) && !visibleTasks.isEmpty {
                currentStreak += 1
                if currentStreak > bestStreak {
                    bestStreak = currentStreak
                }
            } else {
                currentStreak = 0
            }
            
            // Handle individual task streaks and completion cleanly skipping heavily hidden tasks indefinitely until revived
            for task in tasks {
                // Determine if this exact task was forcefully hidden over this window cleanly skipping it visually penalizing
                let wasHidden = task.hiddenUntil != nil && task.hiddenUntil! > today
                
                if !wasHidden {
                    if task.isCompleted {
                        task.streak += 1
                    } else {
                        task.streak = 0
                    }
                } else if var hiddenDate = task.hiddenUntil, hiddenDate <= today {
                    // Task emerged normally; clears hidden date flag structurally
                    task.hiddenUntil = nil
                }
                
                task.isCompleted = false
            }
        }
        
        // Update stored interval to today
        lastResetDateInterval = today.timeIntervalSince1970
    }
}

struct TaskRow: View {
    @Bindable var task: DailyTask
    
    var body: some View {
        HStack {
            // Completed button
            Button {
                task.isCompleted.toggle()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // Task title
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if task.streak > 0 {
                HStack (spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(String(task.streak))
                        .fontWeight(.semibold)
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .cornerRadius(20)
            }
        }
    }
}

struct AllDoneView: View {
    var totalTasks: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background dark circle
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 76, height: 76)
                
                // Inner dark blue track
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 10)
                    .frame(width: 76, height: 76)
                
                // Completed solid light blue ring
                Circle()
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 76, height: 76)
                
                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 6)
            
            Text("All Done")
                .font(.headline)
                .bold()
                .foregroundColor(.white)
            
            Text("\(totalTasks) to-dos completed")
                .font(.footnote)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
