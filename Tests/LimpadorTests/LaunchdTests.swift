import Foundation
import Testing
@testable import Limpador

struct LaunchdTests {
    @Test func parsesBinaryPlistsAndPreservesMalformedBooleanUnknowns() throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["Label": "org.example.agent", "ProgramArguments": ["/path with spaces/program", "argument"], "RunAtLoad": true, "Disabled": 1, "KeepAlive": ["SuccessfulExit": false]], format: .binary, options: 0)
        let item = try LaunchdInventory.parse(data, url: URL(fileURLWithPath: "/test.plist"))
        #expect(item.runAtLoad == true)
        #expect(item.disabled == nil)
        #expect(item.program == "/path with spaces/program")
        #expect(item.issues.count == 1)
        #expect(item.keepAlive?.contains("SuccessfulExit") == true)
    }
}
