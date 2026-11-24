import Foundation
import Darwin

struct FileIdentity: Sendable, Codable, Equatable {
    let device: Int32
    let inode: UInt64
    let bytes: Int64
    let modifiedSeconds: Int64
    let modifiedNanos: Int64
    let changedSeconds: Int64
    let changedNanos: Int64
    let links: UInt16
    let allocatedBytes: Int64
    let owner: UInt32
    var modifiedAt: Date { Date(timeIntervalSince1970: Double(modifiedSeconds) + Double(modifiedNanos) / 1_000_000_000) }
    static func read(_ path: String) throws -> Self {
        var value = stat()
        guard lstat(path, &value) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        guard value.st_mode & S_IFMT == S_IFREG else { throw CocoaError(.fileReadUnsupportedScheme) }
        return Self(device: value.st_dev, inode: value.st_ino, bytes: value.st_size,
                    modifiedSeconds: Int64(value.st_mtimespec.tv_sec), modifiedNanos: Int64(value.st_mtimespec.tv_nsec),
                    changedSeconds: Int64(value.st_ctimespec.tv_sec), changedNanos: Int64(value.st_ctimespec.tv_nsec),
                    links: value.st_nlink, allocatedBytes: max(0, value.st_blocks * 512), owner: value.st_uid)
    }
}

struct RecoveryEstimate: Sendable {
    let logicalBytes: Int64
    let allocatedBytes: Int64
    let unverified: Int
    let sharedLinks: Int
    static func calculate(_ files: [AnalyzedFile]) throws -> Self {
        var logical: Int64 = 0, allocated: Int64 = 0
        var unverified = 0, shared = 0
        var seen = Set<String>()
        for file in files {
            try Task.checkCancellation()
            guard let observed = file.identity, let current = try? FileIdentity.read(file.path), observed == current else { unverified += 1; continue }
            guard seen.insert("\(current.device):\(current.inode)").inserted else { continue }
            logical += current.bytes
            if current.links > 1 { shared += 1 } else { allocated += current.allocatedBytes }
        }
        return Self(logicalBytes: logical, allocatedBytes: allocated, unverified: unverified, sharedLinks: shared)
    }
}
