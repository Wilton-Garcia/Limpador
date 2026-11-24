import Foundation
import Testing
@testable import Limpador

struct DuplicateTests {
    @Test func confirmsContentsSkipsHardLinksAndRejectsChangedSizes() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (name, text) in [("a", "same"), ("b", "same"), ("c", "diff")] { try Data(text.utf8).write(to: root.appendingPathComponent(name)) }
        try FileManager.default.linkItem(at: root.appendingPathComponent("a"), to: root.appendingPathComponent("hardlink"))
        let scan = try FileAnalyzer.scan(root)
        let report = try DuplicateAnalyzer.find(in: scan.files)
        #expect(report.groups.count == 1)
        #expect(report.groups.first?.count == 2)
        try Data("changed length".utf8).write(to: root.appendingPathComponent("b"))
        let changed = try DuplicateAnalyzer.find(in: scan.files)
        #expect(changed.groups.isEmpty)
        #expect(changed.skipped == 1)
    }
}
