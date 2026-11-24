import Foundation
import Testing
@testable import Limpador

struct ProjectUpdateTests {
    @Test func acceptsOnlyStableReleaseLinksFromTheConfiguredRepository() throws {
        let valid = Data(#"{"tag_name":"v0.2.0","html_url":"https://github.com/Wilton-Garcia/Limpador/releases/tag/v0.2.0","draft":false,"prerelease":false}"#.utf8)
        #expect(try ProjectUpdates.parse(valid).tag_name == "v0.2.0")
        let invalid = Data(#"{"tag_name":"v0.2.0","html_url":"https://other.example/download","draft":false,"prerelease":false}"#.utf8)
        #expect(throws: (any Error).self) { try ProjectUpdates.parse(invalid) }
    }
}
