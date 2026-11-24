import Foundation

struct DiskSnapshot: Sendable {
    let name: String
    let total: Int64
    let available: Int64
    let observedAt: Date
    var used: Int64 { total - available }

    static func read(at url: URL = FileManager.default.homeDirectoryForCurrentUser) throws -> Self {
        let values = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity,
              total > 0, available >= 0, available <= total else {
            throw CocoaError(.fileReadUnknown)
        }
        return Self(name: values.volumeName ?? url.path, total: Int64(total), available: Int64(available), observedAt: Date())
    }
}

struct PackageSize: Sendable {
    let bytes: Int64
    let unreadableEntries: Int
    var complete: Bool { unreadableEntries == 0 }
}

struct InstalledApplication: Identifiable, Sendable {
    let url: URL
    let name: String
    let version: String?
    let size: PackageSize
    var bundleID: String? = nil
    var buildVersion: String? = nil
    var id: String { url.path }
}

struct ApplicationInventory: Sendable {
    let apps: [InstalledApplication]
    let issues: [String]
    let observedAt: Date
}

struct InventoryProgress: Sendable, Equatable {
    enum Stage: Sendable { case discovering, measuring }
    let stage: Stage
    let completed: Int
    let total: Int
    let currentName: String
}

enum MacInventory {
    static var defaultRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"), URL(fileURLWithPath: "/System/Applications"),
         URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    }

    // Logical file bytes, not allocated disk usage or reclaimable space. Never follow symlinks.
    static func packageSize(at url: URL) throws -> PackageSize {
        let manager = FileManager.default
        var failures = 0
        var total: Int64 = 0
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let entries = manager.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, _ in
            failures += 1
            return true
        }) else { return PackageSize(bytes: 0, unreadableEntries: 1) }
        for case let file as URL in entries {
            try Task.checkCancellation()
            do {
                let facts = try file.resourceValues(forKeys: keys)
                if facts.isSymbolicLink == true { continue }
                if facts.isRegularFile == true {
                    if let count = facts.fileSize { total += Int64(count) }
                    else { failures += 1 }
                }
            } catch { failures += 1 }
        }
        return PackageSize(bytes: total, unreadableEntries: failures)
    }

    static func applications(roots: [URL] = defaultRoots,
                             onProgress: @Sendable (InventoryProgress) async -> Void = { _ in }) async throws -> ApplicationInventory {
        let manager = FileManager.default
        var apps: [InstalledApplication] = []
        var issues: [String] = []
        var found = Set<String>()
        var candidates: [(url: URL, name: String, version: String?, bundleID: String?, build: String?)] = []
        await onProgress(InventoryProgress(stage: .discovering, completed: 0, total: 0, currentName: ""))
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .localizedNameKey]
        for root in roots {
            try Task.checkCancellation()
            do {
                _ = try root.resourceValues(forKeys: [.isDirectoryKey])
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
                continue // The optional per-user Applications directory often does not exist.
            } catch {
                issues.append("\(root.path): \(error.localizedDescription)")
                continue
            }
            var discoveryFailures = 0
            guard let entries = manager.enumerator(at: root, includingPropertiesForKeys: Array(keys),
                                                    options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in
                discoveryFailures += 1
                return true
            }) else {
                issues.append("Não foi possível listar \(root.path).")
                continue
            }
            while let url = entries.nextObject() as? URL {
                try Task.checkCancellation()
                do {
                    let facts = try url.resourceValues(forKeys: keys)
                    if facts.isSymbolicLink == true { continue }
                    guard facts.isDirectory == true, url.pathExtension.lowercased() == "app" else { continue }
                    guard found.insert(url.standardizedFileURL.path).inserted else { continue }
                    // Bundle metadata does not load or execute the application's code.
                    let bundle = Bundle(url: url)
                    let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                        ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                        ?? url.deletingPathExtension().lastPathComponent
                    candidates.append((url, name, bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String, bundle?.bundleIdentifier, bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String))
                } catch is CancellationError { throw CancellationError() }
                catch { discoveryFailures += 1 }
            }
            if discoveryFailures > 0 { issues.append("\(root.path): \(discoveryFailures) entradas não puderam ser lidas.") }
        }
        for (index, candidate) in candidates.enumerated() {
            try Task.checkCancellation()
            await onProgress(InventoryProgress(stage: .measuring, completed: index, total: candidates.count, currentName: candidate.name))
            try Task.checkCancellation()
            let size = try packageSize(at: candidate.url)
            apps.append(InstalledApplication(url: candidate.url, name: candidate.name, version: candidate.version, size: size, bundleID: candidate.bundleID, buildVersion: candidate.build))
            await onProgress(InventoryProgress(stage: .measuring, completed: index + 1, total: candidates.count, currentName: candidate.name))
        }
        try Task.checkCancellation()
        return ApplicationInventory(apps: apps.sorted {
            let order = $0.name.localizedStandardCompare($1.name)
            return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
        }, issues: issues, observedAt: Date())
    }
}
