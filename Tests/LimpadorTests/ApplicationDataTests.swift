import Foundation
import Testing
@testable import Limpador

struct ApplicationDataTests {
    @Test func usesDeclaredIdentifierAndKeepsMissingSeparateFromUnknown() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let cache = root.appendingPathComponent("Library/Caches/org.example.demo")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data([1, 2]).write(to: cache.appendingPathComponent("cache"))
        var app = InstalledApplication(url: root.appendingPathComponent("Demo.app"), name: "Demo", version: nil, size: .init(bytes: 0, unreadableEntries: 0), bundleID: "org.example.demo")
        let report = try ApplicationDataAnalyzer.inspect(app, home: root)
        #expect(report.items.first?.state == .present)
        #expect(report.items.first?.bytes == 2)
        #expect(report.items.filter { $0.state == .absent }.count == 5)
        let shared = try ApplicationDataAnalyzer.inspect(app, home: root, identityMatches: 2, declaredGroups: ["group.example.shared"])
        #expect(shared.items.allSatisfy { $0.shared })
        #expect(shared.items.last?.url.lastPathComponent == "group.example.shared")
        #expect(!ApplicationGroups.validComponent("../shared"))
        app.bundleID = "../escape"
        #expect(try ApplicationDataAnalyzer.inspect(app, home: root).items.isEmpty)
    }
}
