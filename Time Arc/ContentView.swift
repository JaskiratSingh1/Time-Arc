import SwiftUI

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
    @State private var showingAddTask = false
    @State private var newTaskName = ""

    var body: some View {
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
                    Picker("Select Task", selection: $selectedTaskIndex) {
                        ForEach(tasks.indices, id: \.self) { idx in
                            Text(tasks[idx].name).tag(idx)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    // Load the selected task's time
                    .onChange(of: selectedTaskIndex) { newIndex in
                        elapsedTime = tasks[newIndex].elapsedTime
                    }
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddTask = true
                            DispatchQueue.main.async {
                                // newTaskFieldIsFocused = true
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                        }
                        .padding(.horizontal, 5)
                        .foregroundColor(.black)

                        Button(action: {
                            guard tasks.count > 1 else { return }
                            // Save current time
                            tasks[selectedTaskIndex].elapsedTime = elapsedTime
                            // Remove task and clamp selection
                            tasks.remove(at: selectedTaskIndex)
                            selectedTaskIndex = max(0, selectedTaskIndex - 1)
                            elapsedTime = tasks[selectedTaskIndex].elapsedTime
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                        }
                        .padding(.horizontal, 5)
                        .foregroundColor(.black)
                        .disabled(tasks.count <= 1)
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
        .alert("New Task", isPresented: $showingAddTask) {
            TextField("Task Name", text: $newTaskName)
            Button("Add") {
                let trimmed = newTaskName.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                tasks[selectedTaskIndex].elapsedTime = elapsedTime
                tasks.append(Task(name: trimmed, elapsedTime: 0))
                selectedTaskIndex = tasks.count - 1
                elapsedTime = 0
                newTaskName = ""
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var formattedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        let centiseconds = Int((elapsedTime - floor(elapsedTime)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, centiseconds)
    }

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            elapsedTime += 0.01
        }
    }

    private func stopTimer() {
        isRunning = false
        timer?.invalidate()
        tasks[selectedTaskIndex].elapsedTime = elapsedTime
        timer = nil
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
