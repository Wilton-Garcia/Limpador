import Foundation

struct LeftoverReport: Sendable {
    let items: [AssociatedData]
    let issues: [String]
}

enum LeftoverAnalyzer {
    static func inspect(installedIDs: Set<String>, home: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> LeftoverReport {
        let locations = ["Caches", "Application Support", "Preferences", "Logs", "Saved Application State", "Containers"]
        var items: [AssociatedData] = []
        var issues: [String] = []
        for location in locations {
            try Task.checkCancellation()
            let root = home.appendingPathComponent("Library/" + location)
            do {
                let children = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
                for url in children {
                    try Task.checkCancellation()
                    let name = url.lastPathComponent
                    let identifier = name.hasSuffix(".plist") ? String(name.dropLast(6)) : name.hasSuffix(".savedState") ? String(name.dropLast(11)) : name
                    guard ApplicationGroups.validComponent(identifier), identifier.split(separator: ".").count >= 3,
                          identifier.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }),
                          !installedIDs.contains(identifier) else { continue }
                    items.append(try ApplicationDataAnalyzer.inspectLocation(title: identifier + " · " + location, url: url))
                }
            } catch is CancellationError { throw CancellationError() }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile { }
            catch { issues.append(root.path + ": " + error.localizedDescription) }
        }
        return LeftoverReport(items: items.sorted { $0.id < $1.id }, issues: issues)
    }
}
