import Foundation
import Testing
@testable import Limpador

struct PreferenceResetTests {
    @Test func backsUpOnlyRequestedDomainAndRestoresItsValues() throws {
        let identifier = "local.limpador.test." + UUID().uuidString
        let root = URL(fileURLWithPath: "/private/tmp").appendingPathComponent(UUID().uuidString)
        defer { UserDefaults.standard.removePersistentDomain(forName: identifier); _ = UserDefaults.standard.synchronize(); try? FileManager.default.removeItem(at: root) }
        UserDefaults.standard.setPersistentDomain(["theme": "test"], forName: identifier)
        _ = UserDefaults.standard.synchronize()
        let backup = try PreferenceReset.reset(identifier, running: RunningAppGuard(apps: []), backupRoot: root)
        #expect(UserDefaults.standard.persistentDomain(forName: identifier)?.isEmpty != false)
        try PreferenceReset.restore(backup, running: RunningAppGuard(apps: []))
        #expect(UserDefaults.standard.persistentDomain(forName: identifier)?["theme"] as? String == "test")
        #expect(throws: (any Error).self) { try PreferenceReset.validate("com.apple.finder", running: RunningAppGuard(apps: [])) }
    }
}
