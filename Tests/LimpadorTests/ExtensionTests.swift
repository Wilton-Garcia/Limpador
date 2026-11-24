import Foundation
import Testing
@testable import Limpador

struct ExtensionTests {
    @Test func readsDeclaredExtensionPointWithoutExecutingTheBundle() throws {
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        let app = root.appendingPathComponent("Demo.app")
        let plugin = app.appendingPathComponent("Contents/PlugIns/Test.appex/Contents")
        try FileManager.default.createDirectory(at: plugin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let info: [String: Any] = ["CFBundleIdentifier": "org.example.extension", "CFBundleName": "Test", "NSExtension": ["NSExtensionPointIdentifier": "com.apple.share-services"]]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plugin.appendingPathComponent("Info.plist"))
        let inventory = try ExtensionInventory.inspect([InstalledApplication(url: app, name: "Demo", version: nil, size: .init(bytes: 0, unreadableEntries: 0))])
        #expect(inventory.entries.count == 1)
        #expect(inventory.entries.first?.identifier == "org.example.extension")
        #expect(inventory.entries.first?.point == "com.apple.share-services")
        #expect(inventory.issues.isEmpty)
    }
}
