import Foundation
import Testing
@testable import Limpador

struct RemovalProtectionTests {
    @Test func protectsSharedContainersKeychainsAndRecoveryWhileAllowingSiblingCaches() throws {
        let home = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let paths = ["Library/Group Containers/group.example/shared", "Library/Keychains/private", "Library/Application Support/Limpador/history", "Library/Caches/org.example/cache"]
        for path in paths {
            let file = home.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data([1]).write(to: file)
        }
        let scan = try FileAnalyzer.scan(home, excluding: .init(paths: []))
        let policy = RemovalPolicy(root: home, home: home)
        let running = RunningAppGuard(apps: [])
        for file in scan.files {
            if file.path.contains("/Caches/") { #expect(policy.refusal(for: file, running: running) == nil) }
            else { #expect(policy.refusal(for: file, running: running) != nil) }
        }
        let active = RunningAppGuard(apps: [.init(name: "Example", bundleID: "org.example", bundlePath: nil)])
        let cache = try #require(scan.files.first { $0.path.contains("/Caches/") })
        #expect(policy.refusal(for: cache, running: active) != nil)
    }
}
