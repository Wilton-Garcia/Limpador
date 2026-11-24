import Foundation
import Testing
@testable import Limpador

struct PermissionProbeTests {
    @Test func distinguishesReadableFromMissingPaths() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(PermissionProbe.inspect(root).status == .readable)
        #expect(PermissionProbe.inspect(root.appendingPathComponent("absent")).status == .missing)
    }
}
