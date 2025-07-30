import SwiftUI
import SwiftData

struct Task: Identifiable {
    let id = UUID()
    var name: String
    var elapsedTime: TimeInterval
}

struct ContentView: View {
    @State private var elapsedTime: TimeInterval = 0
    @State private var isRunning = false
    @State private var timer: Timer? = nil
    @State private var tasks: [Task] = [
        Task(name: "Default", elapsedTime: 0)
    ]
    @State private var selectedTaskIndex: Int = 0
    @State private var showingTaskSheet = false
    @State private var showingCalendar = false
    
    @Environment(\.modelContext) private var modelContext
    @State private var lastTickDate = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.7, green: 0.90, blue: 1.0),
                        Color(red: 0.7, green: 0.95, blue: 0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack {
                    VStack {
                        // Task chooser button
                        HStack {
                            Spacer()
                            Button {
                                showingTaskSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(tasks[selectedTaskIndex].name)
                                        .font(.system(size: 40, weight: .semibold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 30, weight: .semibold))
                                }
                            }
                            .sheet(isPresented: $showingTaskSheet) {
                                TaskSheet(
                                    tasks: $tasks,
                                    selectedIndex: $selectedTaskIndex,
                                    elapsedTime: $elapsedTime
                                )
                            }
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)

                    Spacer()

                    Text(formattedTime)
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)

                    Spacer()

                    Button(action: {
                        if isRunning {
                            stopTimer()
                        } else {
                            startTimer()
                        }
                    }) {
                        Text(isRunning ? "Stop" : "Start")
                            .font(.system(size: 40, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white.opacity(0.7))
                            .foregroundColor(.black)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 50)
                }
            }
            .tint(.black)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title)
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showingCalendar) {
                CalendarView()
            }
            .onAppear {
                seedDemoDataIfNeeded()
            }
        } // end NavigationStack
    }

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let centiseconds = Int((elapsedTime - floor(elapsedTime)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private func startTimer() {
        isRunning = true
        lastTickDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            let now = Date()
            // If date rolled over, persist yesterday’s time and reset
            if !Calendar.current.isDate(now, inSameDayAs: lastTickDate) {
                saveDailyTime(taskName: tasks[selectedTaskIndex].name, seconds: elapsedTime)
                elapsedTime = 0
                tasks[selectedTaskIndex].elapsedTime = 0
            }
            
            elapsedTime += 0.01
            tasks[selectedTaskIndex].elapsedTime = elapsedTime
            lastTickDate = now
        }
    }

    private func stopTimer() {
        saveDailyTime(taskName: tasks[selectedTaskIndex].name, seconds: elapsedTime)
        isRunning = false
        timer?.invalidate()
        tasks[selectedTaskIndex].elapsedTime = elapsedTime
        timer = nil
    }
    
    // MARK: - SwiftData persistence per‑day
    private func saveDailyTime(taskName: String, seconds: TimeInterval) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let predicate = #Predicate<DailyTaskTime> { entry in
            entry.date == today && entry.taskName == taskName
        }
        if let existing = try? modelContext.fetch(FetchDescriptor(predicate: predicate)).first {
            existing.seconds = min(existing.seconds + seconds, 86_400)
        } else {
            let newEntry = DailyTaskTime(date: today, taskName: taskName, seconds: min(seconds, 86_400))
            modelContext.insert(newEntry)
        }
    }
    
    // MARK: - Demo data seeding
    private func seedDemoDataIfNeeded() {
        // Only seed if we have no entries yet
        let existing = (try? modelContext.fetch(FetchDescriptor<DailyTaskTime>())) ?? []
        guard existing.isEmpty else { return }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let taskNames = ["LeetCode", "Reading", "Workout"]
        
        // Seed 10 days of history
        for offset in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            for task in taskNames {
                let seconds = Double(Int.random(in: 900...7200)) // 15 min–2 h
                modelContext.insert(
                    DailyTaskTime(date: date, taskName: task, seconds: seconds)
                )
            }
        }
        
        // Also replace the in‑memory task list so UI shows them
        tasks = taskNames.map { Task(name: $0, elapsedTime: 0) }
        selectedTaskIndex = 0
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - SwiftData Model

import SwiftData

@Model
final class DailyTaskTime {
    var date: Date
    var taskName: String
    var seconds: Double

    init(date: Date, taskName: String, seconds: Double) {
        // always normalize to start‑of‑day
        self.date = Calendar.current.startOfDay(for: date)
        self.taskName = taskName
        self.seconds = seconds
    }
}

// MARK: - Calendar Screen (month grid)

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \DailyTaskTime.date) private var entries: [DailyTaskTime]
    
    /// The month being displayed (defaults to today’s month).
    @State private var displayedMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedDay: Date? = nil
    
    private var calendar: Calendar { Calendar.current }
    
    // Group entries by day for quick lookup
    private var secondsByDay: [Date: Double] {
        Dictionary(entries.map { (calendar.startOfDay(for: $0.date), $0.seconds) },
                   uniquingKeysWith: +)
    }
    
    var body: some View {
        VStack {
            // Month header
            HStack {
                Button(action: { displayedMonth = previousMonth(of: displayedMonth) }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(displayedMonth, format: .dateTime.year().month())
                    .font(.title2).bold()
                Spacer()
                Button(action: { displayedMonth = nextMonth(of: displayedMonth) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal)
            
            // Day of week headers
            let symbols = calendar.shortWeekdaySymbols
            HStack {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Grid of dates
            let days = daysForMonth(displayedMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                ForEach(days, id: \.self) { day in
                    Button(action: {
                        selectedDay = calendar.startOfDay(for: day)
                    }) {
                        VStack(spacing: 4) {
                            Text(String(calendar.component(.day, from: day)))
                                .font(.headline)

                            if let seconds = secondsByDay[day], seconds > 0 {
                                Text(timeString(seconds))
                                    .font(.caption2)
                                    .foregroundColor(.accentColor)
                            } else {
                                Text(" ")
                                    .font(.caption2)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .padding(4)
                        .background(
                            calendar.isDate(day, equalTo: Date(), toGranularity: .day)
                            ? Color.accentColor.opacity(0.15) : Color.clear
                        )
                        .opacity(calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month) ? 1 : 0.3)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 2)
            
            // Detailed breakdown for selected day
            if let day = selectedDay {
                let dailyEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
                let byTask = Dictionary(dailyEntries.map { ($0.taskName, $0.seconds) },
                                        uniquingKeysWith: +)
                if !byTask.isEmpty {
                    Divider().padding(.top, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day, format: .dateTime.year().month().day())
                            .font(.title3)
                            .bold()
                            .padding(.bottom, 2)
                        ForEach(byTask.keys.sorted(), id: \.self) { task in
                            HStack {
                                Text(task)
                                Spacer()
                                Text(timeString(byTask[task] ?? 0))
                            }
                            .font(.system(size: 20))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .padding(.top)
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func previousMonth(of date: Date) -> Date {
        calendar.date(byAdding: .month, value: -1, to: date)!
    }
    private func nextMonth(of date: Date) -> Date {
        calendar.date(byAdding: .month, value: 1, to: date)!
    }
    
    private func daysForMonth(_ referenceDate: Date) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: referenceDate),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth,
                                                   for: calendar.date(byAdding: .day, value: -1, to: monthInterval.end)!) else {
            return []
        }
        var days: [Date] = []
        var current = firstWeek.start
        while current <= lastWeek.end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
    
    private func timeString(_ seconds: Double) -> String {
        let hrs = Int(seconds) / 3600
        let mins = (Int(seconds) / 60) % 60
        if hrs > 0 {
            return String(format: "%dh %dm", hrs, mins)
        } else {
            return String(format: "%dm", mins)
        }
    }
}


// MARK: - Task selection sheet

struct TaskSheet: View {
    @Binding var tasks: [Task]
    @Binding var selectedIndex: Int
    @Binding var elapsedTime: TimeInterval

    @Environment(\.dismiss) private var dismiss
    @State private var newTaskName = ""
    @State private var showingAddAlert = false
    @State private var renameTaskName = ""
    @State private var renameIndex: Int? = nil
    @State private var showingRenameAlert = false
    // Removed editMode state as swipe actions are used for rename/delete

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks.indices, id: \.self) { idx in
                    Button {
                        selectedIndex = idx
                        elapsedTime = tasks[idx].elapsedTime
                        dismiss()
                    } label: {
                        HStack {
                            Text(tasks[idx].name)
                                .font(.title2)
                            if idx == selectedIndex {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        // Delete action
                        Button(role: .destructive) {
                            if tasks.count > 1 {
                                tasks.remove(at: idx)
                                selectedIndex = min(selectedIndex, tasks.count - 1)
                                elapsedTime = tasks[selectedIndex].elapsedTime
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        // Rename action
                        Button {
                            renameIndex = idx
                            renameTaskName = tasks[idx].name
                            showingRenameAlert = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                }
            }
            .navigationTitle("Select Task")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") { showingAddAlert = true }
                }
            }
            .alert("New Task", isPresented: $showingAddAlert) {
                TextField("Name", text: $newTaskName)
                Button("Add") {
                    let trimmed = newTaskName.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    tasks.append(Task(name: trimmed, elapsedTime: 0))
                    selectedIndex = tasks.count - 1
                    elapsedTime = 0
                    newTaskName = ""
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Rename Task", isPresented: $showingRenameAlert) {
                TextField("Name", text: $renameTaskName)
                Button("Save") {
                    if let index = renameIndex {
                        let trimmed = renameTaskName.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        tasks[index].name = trimmed
                    }
                }
                Button("Cancel", role: .cancel) { }
            }
        }
    }
}
