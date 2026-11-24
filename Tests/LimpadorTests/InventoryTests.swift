import Foundation
import Testing
@testable import Limpador

struct InventoryTests {
    @Test func inventoryIncludesNestedAppsAndSkipsSymlinksAndNestedBundles() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }
        let app = root.appendingPathComponent("Utilities/Demo.app")
        try manager.createDirectory(at: app.appendingPathComponent("Contents/Helpers/Nested.app"), withIntermediateDirectories: true)
        try Data(repeating: 42, count: 1024).write(to: app.appendingPathComponent("Contents/data"))
        try Data(repeating: 1, count: 128).write(to: app.appendingPathComponent("Contents/Helpers/Nested.app/data"))
        try manager.createSymbolicLink(at: app.appendingPathComponent("Contents/link"), withDestinationURL: app.appendingPathComponent("Contents/data"))
        try manager.createSymbolicLink(at: root.appendingPathComponent("Alias.app"), withDestinationURL: app)
        try manager.createDirectory(at: root.appendingPathComponent("Other/Second.app/Contents"), withIntermediateDirectories: true)
        let inventory = try await MacInventory.applications(roots: [root, root])
        #expect(inventory.apps.count == 2)
        #expect(inventory.apps.first?.name == "Demo")
        #expect(inventory.apps.first?.size.bytes == 1152)
        #expect(inventory.apps.first?.size.complete == true)
        #expect(inventory.issues.isEmpty)
    }

    @Test func missingOptionalDirectoryIsAllowed() async throws {
        let inventory = try await MacInventory.applications(roots: [URL(fileURLWithPath: "/private/tmp/" + UUID().uuidString)])
        #expect(inventory.apps.isEmpty)
        #expect(inventory.issues.isEmpty)
    }

    @Test func cancellationStopsDiscovery() async throws {
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await MacInventory.applications(roots: [URL(fileURLWithPath: "/Applications")])
        }
        do { _ = try await task.value; Issue.record("Expected cancellation") }
        catch is CancellationError {}
    }

    @Test func diskMatchesFilesystemCapacity() throws {
        let url = FileManager.default.homeDirectoryForCurrentUser
        let snapshot = try DiskSnapshot.read(at: url)
        let facts = try url.resourceValues(forKeys: [.volumeTotalCapacityKey])
        #expect(snapshot.total == Int64(try #require(facts.volumeTotalCapacity)))
        #expect(snapshot.available >= 0)
        #expect(snapshot.used + snapshot.available == snapshot.total)
    }
}

actor ProgressLog {
    var values: [InventoryProgress] = []
    func append(_ value: InventoryProgress) { values.append(value) }
}
struct ProgressTests {
    @Test func reportsRealCoverageAndCanCancelBetweenApps() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Demo.app/Contents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let log = ProgressLog()
        let result = try await MacInventory.applications(roots: [root]) { await log.append($0) }
        let progress = await log.values
        #expect(progress.first?.stage == .discovering)
        #expect(progress.last?.completed == result.apps.count)
        #expect(progress.last?.total == 1)
        do {
            _ = try await Task {
                try await MacInventory.applications(roots: [root]) { value in
                    if value.stage == .measuring { withUnsafeCurrentTask { $0?.cancel() } }
                }
            }.value
            Issue.record("Expected cancellation during measurement")
        } catch is CancellationError {}
    }
}
