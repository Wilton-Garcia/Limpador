import Foundation
import Testing
@testable import Limpador

struct IdentityChangeTests {
    @Test func rejectsReplacedFilesAndReplacedRootsEvenIfContentMatches() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = folder.appendingPathComponent("file")
        try Data([1]).write(to: file)
        let scan = try FileAnalyzer.scan(folder, excluding: .init(paths: []))
        let observed = try #require(scan.files.first)
        let policy = RemovalPolicy(root: folder, expectedRoot: scan.rootIdentity)
        try FileManager.default.moveItem(at: file, to: folder.appendingPathComponent("old"))
        try Data([1]).write(to: file)
        #expect(policy.refusal(for: observed, running: RunningAppGuard(apps: [])) != nil)
        let fresh = try FileAnalyzer.scan(folder, excluding: .init(paths: []))
        let currentFile = try #require(fresh.files.first { $0.url.lastPathComponent == "file" })
        let currentPolicy = RemovalPolicy(root: folder, expectedRoot: fresh.rootIdentity)
        let moved = root.appendingPathComponent("moved")
        try FileManager.default.moveItem(at: folder, to: moved)
        try FileManager.default.createSymbolicLink(at: folder, withDestinationURL: moved)
        #expect(currentPolicy.refusal(for: currentFile, running: RunningAppGuard(apps: [])) != nil)
    }
}
