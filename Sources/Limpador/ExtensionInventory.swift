import Foundation

struct ExtensionEntry: Identifiable, Sendable {
    let url: URL
    let name: String
    let identifier: String?
    let kind: String
    let point: String?
    var id: String { url.path }
}
struct ExtensionReport: Sendable {
    let entries: [ExtensionEntry]
    let issues: [String]
}

enum ExtensionInventory {
    static func inspect(_ applications: [InstalledApplication]) throws -> ExtensionReport {
        let directories = [("Contents/PlugIns", "Extensão de aplicativo"), ("Contents/Library/SystemExtensions", "Extensão de sistema"),
                           ("Contents/Library/LoginItems", "Item de login incorporado"), ("Contents/Library/LaunchServices", "Serviço auxiliar incorporado")]
        var entries: [ExtensionEntry] = [], issues: [String] = []
        for app in applications {
            try Task.checkCancellation()
            for (relative, kind) in directories {
                let root = app.url.appendingPathComponent(relative)
                do {
                    let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey])
                    for url in children {
                        try Task.checkCancellation()
                        do {
                            let facts = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
                            guard facts.isSymbolicLink != true else { issues.append("Link não seguido: " + url.path); continue }
                            let bundle = Bundle(url: url)
                            let point = (bundle?.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"] as? String
                            entries.append(ExtensionEntry(url: url, name: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String ?? url.lastPathComponent, identifier: bundle?.bundleIdentifier, kind: kind, point: point))
                        } catch { issues.append(url.path + ": " + error.localizedDescription) }
                    }
                } catch is CancellationError { throw CancellationError() }
                catch let error as CocoaError where error.code == .fileReadNoSuchFile { }
                catch { issues.append(root.path + ": " + error.localizedDescription) }
            }
        }
        return ExtensionReport(entries: entries.sorted { $0.id < $1.id }, issues: issues)
    }
}
