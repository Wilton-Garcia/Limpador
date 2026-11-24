import Foundation
import Testing
@testable import Limpador

struct FileAnalysisTests {
    @Test func preservesPathsDatesAndDoesNotFollowLinks() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Nested"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Nested/photo.png")
        try Data(repeating: 0, count: 123).write(to: file)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("linked"), withDestinationURL: file)
        let scan = try FileAnalyzer.scan(root)
        #expect(scan.files.count == 1)
        #expect(scan.bytes == 123)
        #expect(scan.files.first?.path == file.path)
        #expect(scan.files.first?.modifiedAt != nil)
        #expect(scan.files.first?.category == "Imagens")
        #expect(scan.unreadableEntries == 0)
    }
}
