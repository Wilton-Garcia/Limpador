import Foundation
import Darwin

struct TreeItemIdentity: Sendable, Equatable {
    let device: Int32
    let inode: UInt64
    let mode: UInt16
    let owner: UInt32
    let size: Int64
    let modifiedSeconds: Int64
    let modifiedNanos: Int64
    let changedSeconds: Int64
    let changedNanos: Int64
    static func read(_ path: String) throws -> Self {
        var value = stat()
        guard lstat(path, &value) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        return Self(device: value.st_dev, inode: value.st_ino, mode: value.st_mode, owner: value.st_uid, size: value.st_size,
                    modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanos: Int64(value.st_mtimespec.tv_nsec),
                    changedSeconds: Int64(value.st_ctimespec.tv_sec), changedNanos: Int64(value.st_ctimespec.tv_nsec))
    }
}

struct BundleSnapshot: Sendable {
    let url: URL
    let entries: [String: TreeItemIdentity]
    static func prepare(_ url: URL) throws -> Self {
        let identity = try TreeItemIdentity.read(url.path)
        guard url.pathExtension.lowercased() == "app", identity.mode & S_IFMT == S_IFDIR else { throw CocoaError(.fileReadUnsupportedScheme) }
        var entries = [url.path: identity]
        var error: Error?
        guard let reader = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [], options: [], errorHandler: { _, issue in error = issue; return false }) else { throw CocoaError(.fileReadNoPermission) }
        for case let entry as URL in reader {
            try Task.checkCancellation()
            entries[entry.path] = try TreeItemIdentity.read(entry.path)
        }
        if let error { throw error }
        guard try TreeItemIdentity.read(url.path) == identity else { throw CocoaError(.fileReadUnknown) }
        return Self(url: url, entries: entries)
    }
}

enum BundleUninstaller {
    static var installRoots: [URL] { [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")] }
    static func run(_ snapshot: BundleSnapshot, roots: [URL] = installRoots,
                    running: @Sendable () async -> RunningAppGuard = { await RunningAppGuard.snapshot() },
                    transport: @Sendable (URL) throws -> URL? = { try FileRemoval.trash($0) }) async -> RemovalReport {
        func report(_ outcome: RemovalEntry.Outcome, _ detail: String, destination: String? = nil) -> RemovalReport {
            RemovalReport(date: Date(), entries: [RemovalEntry(path: snapshot.url.path, outcome: outcome, detail: detail, destination: destination)])
        }
        guard roots.contains(where: { FileLocation.contains(snapshot.url.path, inside: $0.path) }),
              snapshot.entries[snapshot.url.path]?.owner == getuid(), snapshot.url.pathExtension.lowercased() == "app" else {
            return report(.skipped, "Aplicativo fora das pastas permitidas ou pertencente a outra conta. Use o Finder para aplicativos protegidos.")
        }
        guard !AnalysisExclusions.load().contains(snapshot.url.path) else { return report(.skipped, "Aplicativo excluído nas preferências.") }
        do {
            try Task.checkCancellation()
            let current = try BundleSnapshot.prepare(snapshot.url)
            guard current.entries == snapshot.entries else { return report(.skipped, "O pacote mudou desde a revisão. Analise novamente.") }
            let apps = await running()
            guard apps.associations(for: snapshot.url.path).isEmpty else { return report(.skipped, "Encerre o aplicativo antes de desinstalar.") }
            try Task.checkCancellation()
            guard try TreeItemIdentity.read(snapshot.url.path) == snapshot.entries[snapshot.url.path] else { return report(.skipped, "A identidade do aplicativo mudou.") }
            let destination = try transport(snapshot.url)
            return report(.trashed, "Aplicativo enviado à Lixeira. Dados associados exigem revisão separada.", destination: destination?.path)
        } catch is CancellationError { return report(.skipped, "Desinstalação cancelada.") }
        catch { return report(.failed, error.localizedDescription) }
    }
}
