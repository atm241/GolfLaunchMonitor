import SwiftUI
import SwiftData

@main
struct GolfLaunchMonitorApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: Shot.self)
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            RecordView()
                .tabItem { Label("Record", systemImage: "camera.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "list.bullet") }

            SetupView()
                .tabItem { Label("Setup", systemImage: "questionmark.circle.fill") }
        }
    }
}
