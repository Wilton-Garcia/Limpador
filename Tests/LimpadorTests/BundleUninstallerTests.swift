import Foundation
import Testing
@testable import Limpador

struct BundleUninstallerTests {
    @Test func reviewsWholeTreeAndRejectsChangedNestedFiles() async throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Demo.app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/Nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = app.appendingPathComponent("Contents/Nested/file")
        try Data([1]).write(to: file)
        let snapshot = try BundleSnapshot.prepare(app)
        try Data([1, 2]).write(to: file)
        let changed = await BundleUninstaller.run(snapshot, roots: [root], running: { RunningAppGuard(apps: []) }, transport: { _ in Issue.record("Changed bundle must not move"); return nil })
        #expect(changed.entries.first?.outcome == .skipped)
        let fresh = try BundleSnapshot.prepare(app)
        let destination = root.appendingPathComponent("Moved.app")
        let moved = await BundleUninstaller.run(fresh, roots: [root], running: { RunningAppGuard(apps: []) }) { url in
            try FileManager.default.moveItem(at: url, to: destination); return destination
        }
        #expect(moved.movedCount == 1)
        #expect(FileManager.default.fileExists(atPath: destination.path))
    }
}
