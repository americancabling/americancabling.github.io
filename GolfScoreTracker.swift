import SwiftUI

struct Course: Identifiable, Codable {
    var id = UUID()
    var name: String
    var pars: [Int] // 18 values
}

struct Player: Identifiable, Codable {
    var id = UUID()
    var name: String
}

struct ScoreEntry: Identifiable {
    var id = UUID()
    var player: Player
    var scores: [Int] = Array(repeating: 0, count: 18)

    var total: Int {
        scores.reduce(0, +)
    }

    func relativeToPar(for course: Course, upTo hole: Int) -> Int {
        let coursePar = course.pars.prefix(hole).reduce(0, +)
        let playerScore = scores.prefix(hole).reduce(0, +)
        return playerScore - coursePar
    }
}

class GolfData: ObservableObject {
    @Published var courses: [Course] = []
    @Published var players: [Player] = []

    // Active round state
    @Published var selectedCourse: Course? = nil
    @Published var selectedPlayers: [Player] = []
    @Published var scores: [ScoreEntry] = []
    @Published var currentHole: Int = 1

    func startRound() {
        guard let course = selectedCourse else { return }
        scores = selectedPlayers.map { ScoreEntry(player: $0, scores: Array(repeating: course.pars[0], count: 18)) }
        currentHole = 1
    }
}

struct ContentView: View {
    @StateObject var data = GolfData()

    var body: some View {
        NavigationView {
            CourseListView()
                .environmentObject(data)
        }
    }
}

struct CourseListView: View {
    @EnvironmentObject var data: GolfData
    @State private var showingNewCourse = false

    var body: some View {
        List {
            ForEach(data.courses) { course in
                NavigationLink(destination: PlayerSelectionView(course: course)) {
                    Text(course.name)
                }
            }
        }
        .navigationTitle("Choose Course")
        .toolbar {
            Button("Add Course") {
                showingNewCourse = true
            }
        }
        .sheet(isPresented: $showingNewCourse) {
            CourseEditorView(course: Course(name: "", pars: Array(repeating: 4, count: 18))) { course in
                data.courses.append(course)
            }
        }
    }
}

struct CourseEditorView: View {
    @Environment(\.presentationMode) var presentation
    @State var course: Course
    var onSave: (Course) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Course Name")) {
                    TextField("Name", text: $course.name)
                }
                Section(header: Text("Holes")) {
                    ForEach(0..<18) { index in
                        Picker("Hole \(index + 1)", selection: $course.pars[index]) {
                            Text("3").tag(3)
                            Text("4").tag(4)
                            Text("5").tag(5)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
            }
            .navigationTitle("New Course")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(course)
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentation.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct PlayerSelectionView: View {
    @EnvironmentObject var data: GolfData
    var course: Course
    @State private var playerNames: [String] = []
    @State private var showingAddPlayer = false

    var body: some View {
        Form {
            Section(header: Text("Players")) {
                ForEach(0..<4) { index in
                    Picker("Player \(index + 1)", selection: Binding(
                        get: { playerNames.indices.contains(index) ? playerNames[index] : "" },
                        set: { value in
                            if playerNames.indices.contains(index) {
                                playerNames[index] = value
                            } else {
                                playerNames.append(value)
                            }
                        })) {
                        ForEach(data.players) { player in
                            Text(player.name).tag(player.name)
                        }
                    }
                }
            }
        }
        .navigationTitle("Select Players")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start Round") {
                    data.selectedCourse = course
                    data.selectedPlayers = data.players.filter { playerNames.contains($0.name) }
                    data.startRound()
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Add Player") {
                    showingAddPlayer = true
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            NewPlayerView { player in
                data.players.append(player)
            }
        }
    }
}

struct NewPlayerView: View {
    @Environment(\.presentationMode) var presentation
    @State private var name: String = ""
    var onSave: (Player) -> Void

    var body: some View {
        NavigationView {
            Form {
                TextField("Player Name", text: $name)
            }
            .navigationTitle("New Player")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(Player(name: name))
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentation.wrappedValue.dismiss() }
                }
            }
        }
    }
}

struct ScoreEntryView: View {
    @EnvironmentObject var data: GolfData

    var body: some View {
        if let course = data.selectedCourse {
            VStack {
                List {
                    ForEach(data.scores.indices, id: \ .self) { index in
                        let entry = data.scores[index]
                        HStack {
                            Text(entry.player.name)
                            Spacer()
                            Stepper(value: Binding(
                                get: { entry.scores[data.currentHole - 1] },
                                set: { value in
                                    data.scores[index].scores[data.currentHole - 1] = value
                                }), in: 1...10) {
                                Text("\(entry.scores[data.currentHole - 1])")
                            }
                            Text(relativeText(for: entry))
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                }
                HStack {
                    if data.currentHole > 1 {
                        Button("Prev Hole") { data.currentHole -= 1 }
                    }
                    Spacer()
                    if data.currentHole < 18 {
                        Button("Next Hole") { data.currentHole += 1 }
                    } else {
                        NavigationLink("Finish", destination: FinalScoreView())
                    }
                }
                .padding()
            }
            .navigationTitle("Hole \(data.currentHole) – Par \(course.pars[data.currentHole - 1])")
        } else {
            Text("No course selected")
        }
    }

    func relativeText(for entry: ScoreEntry) -> String {
        guard let course = data.selectedCourse else { return "" }
        let rel = entry.relativeToPar(for: course, upTo: data.currentHole)
        if rel == 0 { return "E" } else if rel > 0 { return "+\(rel)" } else { return "\(rel)" }
    }
}

struct FinalScoreView: View {
    @EnvironmentObject var data: GolfData

    var body: some View {
        if let course = data.selectedCourse {
            List {
                ForEach(data.scores) { entry in
                    HStack {
                        Text(entry.player.name)
                        Spacer()
                        Text("\(entry.total)")
                        Text(finalRelativeText(entry: entry, course: course))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("Final Scores")
        } else {
            Text("No course")
        }
    }

    func finalRelativeText(entry: ScoreEntry, course: Course) -> String {
        let rel = entry.total - course.pars.reduce(0, +)
        if rel == 0 { return "E" } else if rel > 0 { return "+\(rel)" } else { return "\(rel)" }
    }
}

@main
struct GolfScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

