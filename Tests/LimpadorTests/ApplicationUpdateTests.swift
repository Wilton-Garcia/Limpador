import Foundation
import Testing
@testable import Limpador

struct ApplicationUpdateTests {
    @Test func parsesNamespacedElementAndLegacyAttributeVersions() throws {
        let xml = """
        <rss xmlns:s="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>
        <item><s:version>20</s:version><s:shortVersionString>2.0</s:shortVersionString><s:minimumSystemVersion>14.0</s:minimumSystemVersion></item>
        <item><enclosure s:version="10" s:shortVersionString="1.0" /></item>
        </channel></rss>
        """
        let versions = try ApplicationUpdates.parse(Data(xml.utf8))
        #expect(versions.map(\.build) == ["20", "10"])
        #expect(versions.map(\.display) == ["2.0", "1.0"])
        #expect(ApplicationUpdates.compareNumeric("1.10", "1.9") == .orderedDescending)
        #expect(ApplicationUpdates.compareNumeric("1.0", "1") == .orderedSame)
        #expect(ApplicationUpdates.compareNumeric("2.0-beta", "2.0") == nil)
    }
}
