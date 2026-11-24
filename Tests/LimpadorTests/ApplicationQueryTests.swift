import Foundation
import Testing
@testable import Limpador

struct ApplicationQueryTests {
    @Test func sortsBySizeWithStableIdentityForMatchingNames() {
        let small = InstalledApplication(url: URL(fileURLWithPath: "/a.app"), name: "Demo", version: nil, size: .init(bytes: 1, unreadableEntries: 0))
        let large = InstalledApplication(url: URL(fileURLWithPath: "/b.app"), name: "Demo", version: nil, size: .init(bytes: 20, unreadableEntries: 1))
        #expect(ApplicationQuery(order: .largest).apply(to: [small, large]).first?.id == large.id)
        #expect(ApplicationQuery(order: .smallest).apply(to: [large, small]).first?.id == small.id)
        #expect(ApplicationQuery(search: "b.app").apply(to: [small, large]).count == 1)
    }
}
