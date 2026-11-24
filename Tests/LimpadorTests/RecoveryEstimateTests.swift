import Foundation
import Testing
@testable import Limpador

struct RecoveryEstimateTests {
    @Test func excludesChangedFilesAndSharedInodesFromAllocatedEstimate() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("a")
        try Data(repeating: 3, count: 4096).write(to: original)
        try FileManager.default.linkItem(at: original, to: root.appendingPathComponent("b"))
        let scan = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        let estimate = try RecoveryEstimate.calculate(scan.files)
        #expect(estimate.sharedLinks == 1)
        #expect(estimate.logicalBytes == 4096)
        #expect(estimate.allocatedBytes == 0)
        try Data([1]).write(to: original)
        #expect(try RecoveryEstimate.calculate(scan.files).unverified == 2)
    }
}
