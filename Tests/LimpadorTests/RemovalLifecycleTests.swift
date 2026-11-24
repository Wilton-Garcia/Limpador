import Foundation
import Testing
@testable import Limpador

struct RemovalLifecycleTests {
    @Test func cancellationRetainsCompletedMovesAndMarksRemainingItemsSkipped() async throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let destination = root.appendingPathComponent("destination")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["a", "b"] { try Data([1]).write(to: root.appendingPathComponent(name)) }
        let scan = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        let policy = RemovalPolicy(root: root, expectedRoot: scan.rootIdentity)
        let report = await Task {
            await FileRemoval.run(scan.files, policy: policy, running: { RunningAppGuard(apps: []) }) { url in
                let output = destination.appendingPathComponent(url.lastPathComponent)
                try FileManager.default.moveItem(at: url, to: output)
                withUnsafeCurrentTask { $0?.cancel() }
                return output
            }
        }.value
        #expect(report.movedCount == 1)
        #expect(report.entries.filter { $0.outcome == .skipped }.count == 1)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("b").path))
    }
    @Test func failedTransportCanBeRetriedWithTheOriginalUnchangedIdentity() async throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([1]).write(to: root.appendingPathComponent("sample"))
        let scan = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        let policy = RemovalPolicy(root: root, expectedRoot: scan.rootIdentity)
        let failed = await FileRemoval.run(scan.files, policy: policy, running: { RunningAppGuard(apps: []) }, transport: { _ in throw CocoaError(.fileWriteNoPermission) })
        #expect(failed.entries.first?.outcome == .failed)
        let retried = await FileRemoval.run(scan.files, policy: policy, running: { RunningAppGuard(apps: []) }) { url in
            let moved = root.appendingPathComponent("moved")
            try FileManager.default.moveItem(at: url, to: moved)
            return moved
        }
        #expect(retried.movedCount == 1)
    }
}

struct NativeTrashIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["LIMPADOR_TEST_NATIVE_TRASH"] == "1"))
    func nativeTrashRoundTripUsesOnlyAnOwnedTemporaryFixture() throws {
        let manager = FileManager.default
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent("Limpador-Trash-Test-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("Limpador-test-file.txt")
        let content = Data("Temporary Limpador integration fixture".utf8)
        var destination: URL?
        defer {
            if let destination, !manager.fileExists(atPath: file.path) { try? manager.moveItem(at: destination, to: file) }
            try? manager.removeItem(at: root)
        }
        try content.write(to: file)
        destination = try FileRemoval.trash(file)
        let moved = try #require(destination)
        #expect(!manager.fileExists(atPath: file.path))
        #expect(try Data(contentsOf: moved) == content)
        try manager.moveItem(at: moved, to: file)
        destination = nil
        #expect(try Data(contentsOf: file) == content)
    }
}
