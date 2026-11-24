import Foundation
import Testing
@testable import Limpador

struct LeftoverTests {
    @Test func reportsOnlyCandidatesOutsideKnownInventoryWithoutClaimingOwnership() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Caches")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for name in ["org.example.installed", "org.example.removed", "ordinary-folder"] {
            try FileManager.default.createDirectory(at: cache.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        let report = try LeftoverAnalyzer.inspect(installedIDs: ["org.example.installed"], home: root)
        #expect(report.items.count == 1)
        #expect(report.items.first?.url.lastPathComponent == "org.example.removed")
        #expect(report.issues.isEmpty)
    }
}
