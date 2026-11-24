import SwiftUI

@main
struct LimpadorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1160, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
