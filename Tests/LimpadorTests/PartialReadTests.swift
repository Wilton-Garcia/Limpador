import Foundation
import Darwin
import Testing
@testable import Limpador

struct PartialReadTests {
    @Test func retainsReadableSiblingsAndPermissionFailureProvenance() throws {
        guard getuid() != 0 else { return }
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let denied = root.appendingPathComponent("protected")
        try FileManager.default.createDirectory(at: denied, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: denied.path)
            try? FileManager.default.removeItem(at: root)
        }
        try Data([1]).write(to: root.appendingPathComponent("readable"))
        try Data([2]).write(to: denied.appendingPathComponent("private"))
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: denied.path)
        let result = try FileAnalyzer.scan(root, excluding: .init(paths: []))
        #expect(result.files.map(\.url.lastPathComponent) == ["readable"])
        #expect(result.unreadableEntries > 0)
        #expect(result.issues.contains { $0.path == denied.path && !$0.reason.isEmpty })
        #expect(PermissionProbe.inspect(denied).status == .denied)
    }
}
