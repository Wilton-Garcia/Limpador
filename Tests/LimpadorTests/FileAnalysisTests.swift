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
        #expect(scan.files.first?.relativePath == "Nested/photo.png")
        #expect(scan.distribution(byCategory: false).first?.name == "Nested")
        #expect(scan.distribution(byCategory: true).first?.bytes == 123)
        #expect(scan.unreadableEntries == 0)
    }
}

struct FileQueryTests {
    @Test func filtersAndOrdersWithoutLosingOriginalSelectionIdentities() {
        let files = [AnalyzedFile(path: "/a/photo.png", bytes: 20, modifiedAt: nil),
                     AnalyzedFile(path: "/a/report.txt", bytes: 100, modifiedAt: Date(timeIntervalSince1970: 20)),
                     AnalyzedFile(path: "/b/photo.png", bytes: 50, modifiedAt: Date(timeIntervalSince1970: 10))]
        #expect(FileQuery(order: .largest).apply(to: files).map(\.bytes) == [100, 50, 20])
        #expect(FileQuery(search: "photo", category: "Imagens", order: .newest).apply(to: files).map(\.path) == ["/b/photo.png", "/a/photo.png"])
        #expect(FileQuery(order: .oldest).apply(to: files).last?.modifiedAt == nil)
    }
}
