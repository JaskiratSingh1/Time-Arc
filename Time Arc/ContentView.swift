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

// MARK: - Calendar Screen

import SwiftUI

struct CalendarView: View {
    // fetch all entries ordered latest first
    @Query(sort: \DailyTaskTime.date, order: .reverse) private var entries: [DailyTaskTime]

    private var grouped: [Date: [DailyTaskTime]] {
        Dictionary(grouping: entries) { $0.date }
    }

    var body: some View {
        List {
            ForEach(grouped.keys.sorted(by: >), id: \.self) { day in
                if let items = grouped[day] {
                    Section(header: Text(day, format: .dateTime.year().month().day())) {
                        ForEach(items) { item in
                            HStack {
                                Text(item.taskName)
                                Spacer()
                                Text(timeString(item.seconds))
                            }
                        }
                        HStack {
                            Text("Total")
                                .bold()
                            Spacer()
                            Text(
                                timeString(
                                    items.reduce(0) { $0 + $1.seconds }
                                )
                            )
                            .bold()
                        }
                    }
                }
            }
        }
        .navigationTitle("Activity Calendar")
    }

    private func timeString(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
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
                }
                .onDelete { indexSet in
                    if tasks.count > 1 {
                        tasks.remove(atOffsets: indexSet)
                        selectedIndex = min(selectedIndex, tasks.count - 1)
                        elapsedTime = tasks[selectedIndex].elapsedTime
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
        }
    }
}
