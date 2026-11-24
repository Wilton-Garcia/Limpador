import Foundation
import CoreFoundation

struct LaunchdRecord: Identifiable, Sendable {
    let url: URL
    let label: String?
    let program: String?
    let runAtLoad: Bool?
    let disabled: Bool?
    let keepAlive: String?
    let issues: [String]
    var id: String { url.path }
}
struct LaunchdReport: Sendable {
    let records: [LaunchdRecord]
    let issues: [String]
}

enum LaunchdInventory {
    static var agentRoots: [URL] {
        [FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"), URL(fileURLWithPath: "/Library/LaunchAgents"), URL(fileURLWithPath: "/System/Library/LaunchAgents")]
    }
    static var daemonRoots: [URL] { [URL(fileURLWithPath: "/Library/LaunchDaemons"), URL(fileURLWithPath: "/System/Library/LaunchDaemons")] }
    static func parse(_ data: Data, url: URL) throws -> LaunchdRecord {
        let raw = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = raw as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        var issues: [String] = []
        let label = dictionary["Label"] as? String
        if label == nil || label?.isEmpty == true { issues.append("Label ausente ou inválido.") }
        func boolean(_ key: String) -> Bool? {
            guard let raw = dictionary[key] else { return nil }
            guard let number = raw as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { issues.append(key + " não é booleano."); return nil }
            return number.boolValue
        }
        let runAtLoad = boolean("RunAtLoad"), disabled = boolean("Disabled")
        var program: String?
        if let raw = dictionary["Program"] {
            program = raw as? String
            if program == nil { issues.append("Program possui tipo inválido.") }
        } else if let raw = dictionary["ProgramArguments"] {
            if let arguments = raw as? [String], !arguments.isEmpty { program = arguments.first }
            else { issues.append("ProgramArguments ausente de argumentos válidos.") }
        }
        var keepAlive: String?
        if let raw = dictionary["KeepAlive"] {
            if let number = raw as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() { keepAlive = number.boolValue ? "Sim" : "Não" }
            else if let conditions = raw as? [String: Any] {
                keepAlive = conditions.keys.sorted().map { $0 + "=" + String(describing: conditions[$0]!) }.joined(separator: ", ")
            } else { issues.append("KeepAlive possui tipo inválido.") }
        }
        return LaunchdRecord(url: url, label: label, program: program, runAtLoad: runAtLoad, disabled: disabled, keepAlive: keepAlive, issues: issues)
    }
    static func inspect(roots: [URL] = agentRoots) throws -> LaunchdReport {
        var records: [LaunchdRecord] = [], issues: [String] = []
        for root in roots {
            try Task.checkCancellation()
            do {
                let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                for url in files where url.pathExtension == "plist" {
                    try Task.checkCancellation()
                    do {
                        let facts = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                        guard facts.isRegularFile == true, facts.isSymbolicLink != true else {
                            records.append(LaunchdRecord(url: url, label: nil, program: nil, runAtLoad: nil, disabled: nil, keepAlive: nil, issues: ["Entrada não regular ou link não seguido."])); continue
                        }
                        records.append(try parse(Data(contentsOf: url), url: url))
                    } catch { records.append(LaunchdRecord(url: url, label: nil, program: nil, runAtLoad: nil, disabled: nil, keepAlive: nil, issues: [error.localizedDescription])) }
                }
            } catch is CancellationError { throw CancellationError() }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile { }
            catch { issues.append(root.path + ": " + error.localizedDescription) }
        }
        return LaunchdReport(records: records.sorted { $0.id < $1.id }, issues: issues)
    }
}
