import Foundation
import CryptoKit
import Darwin

struct DuplicateReport: Sendable {
    let groups: [[AnalyzedFile]]
    let skipped: Int
}

enum DuplicateAnalyzer {
    static func find(in files: [AnalyzedFile]) throws -> DuplicateReport {
        let candidates = Dictionary(grouping: files, by: \.bytes).values.filter { $0.count > 1 }
        var hashes: [String: [AnalyzedFile]] = [:]
        var identities = Set<String>()
        var skipped = 0
        for group in candidates {
            for file in group {
                try Task.checkCancellation()
                let descriptor = Darwin.open(file.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
                guard descriptor >= 0 else { skipped += 1; continue }
                let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
                defer { try? handle.close() }
                var before = stat()
                guard fstat(descriptor, &before) == 0, before.st_mode & S_IFMT == S_IFREG,
                      before.st_size == file.bytes else { skipped += 1; continue }
                let identity = "\(before.st_dev):\(before.st_ino)"
                guard !identities.contains(identity) else { continue } // Multiple names for the same inode are not copies.
                do {
                    var hash = SHA256()
                    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                        try Task.checkCancellation()
                        hash.update(data: chunk)
                    }
                    var after = stat()
                    guard fstat(descriptor, &after) == 0,
                          before.st_size == after.st_size,
                          before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
                          before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
                          before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
                          before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else { skipped += 1; continue }
                    identities.insert(identity)
                    let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
                    hashes["\(file.bytes):\(digest)", default: []].append(file)
                } catch is CancellationError { throw CancellationError() }
                catch { skipped += 1 }
            }
        }
        return DuplicateReport(groups: hashes.values.filter { $0.count > 1 }.map { $0.sorted { $0.path < $1.path } }.sorted { $0[0].path < $1[0].path }, skipped: skipped)
    }
}
