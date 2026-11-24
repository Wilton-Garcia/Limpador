import Foundation
import Testing
@testable import Limpador

struct RemovalTests {
    @Test func refusesChangedFilesAndRetainsMixedOutcomes() async throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["good", "changed", "failed"] { try Data([1]).write(to: root.appendingPathComponent(name)) }
        let scan = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        try Data([2, 3]).write(to: root.appendingPathComponent("changed"))
        let report = await FileRemoval.run(scan.files, policy: RemovalPolicy(root: root), running: { RunningAppGuard(apps: []) }) { url in
            if url.lastPathComponent == "failed" { throw CocoaError(.fileWriteNoPermission) }
            let output = destination.appendingPathComponent(url.lastPathComponent)
            try FileManager.default.moveItem(at: url, to: output)
            return output
        }
        #expect(report.movedCount == 1)
        #expect(report.entries.filter { $0.outcome == .failed }.count == 1)
        #expect(report.entries.filter { $0.outcome == .skipped }.count == 1)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("changed").path))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("good").path))
    }
}
