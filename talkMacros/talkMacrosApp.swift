import SwiftUI
import SwiftData

@main
struct talkMacrosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [DailyLog.self, MealEntry.self])
    }
}
