import AppKit

struct RunningAppGuard: Sendable {
    struct App: Sendable {
        let name: String
        let bundleID: String?
        let bundlePath: String?
    }
    let apps: [App]
    @MainActor static func snapshot() -> Self {
        Self(apps: NSWorkspace.shared.runningApplications.map {
            App(name: $0.localizedName ?? "Aplicativo", bundleID: $0.bundleIdentifier, bundlePath: $0.bundleURL?.path)
        })
    }
    func associations(for path: String) -> [String] {
        let components = URL(fileURLWithPath: path).pathComponents
        return apps.filter { app in
            if let bundle = app.bundlePath, path == bundle || path.hasPrefix(bundle + "/") { return true }
            if let bundleID = app.bundleID, components.contains(bundleID) { return true }
            return false
        }.map(\.name)
    }
}
