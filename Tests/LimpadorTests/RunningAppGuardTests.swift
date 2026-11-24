import Testing
@testable import Limpador

struct RunningAppGuardTests {
    @Test func associatesExactBundlesAndIdentifiersWithoutPrefixGuessing() {
        let guardState = RunningAppGuard(apps: [.init(name: "Demo", bundleID: "org.example.demo", bundlePath: "/Applications/Demo.app")])
        #expect(guardState.associations(for: "/Applications/Demo.app/Contents/file") == ["Demo"])
        #expect(guardState.associations(for: "/Users/me/Library/Caches/org.example.demo/cache") == ["Demo"])
        #expect(guardState.associations(for: "/Applications/Demo.app.other/file").isEmpty)
        #expect(guardState.associations(for: "/Users/me/Library/Caches/org.example.demo.other/file").isEmpty)
    }
}
