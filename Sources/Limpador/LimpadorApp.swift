import SwiftUI

@main
struct LimpadorApp: App {
    @NSApplicationDelegateAdaptor(LimpadorApplicationDelegate.self) private var delegate
    @AppStorage("showMenuBar") private var showMenuBar = true
    @AppStorage("appearance") private var appearance = "system"
    var body: some Scene {
        WindowGroup("Limpador", id: "main") {
            ContentView()
                .frame(minWidth: 760, minHeight: 720)
                .preferredColorScheme(appearance == "system" ? nil : appearance == "dark" ? .dark : .light)
        }
        .defaultSize(width: 1160, height: 800)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        MenuBarExtra("Limpador", systemImage: "sparkles", isInserted: $showMenuBar) {
            MenuBarStatusView()
        }.menuBarExtraStyle(.window)
    }
}
