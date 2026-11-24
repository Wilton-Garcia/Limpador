import Foundation
import Darwin
import Testing
@testable import Limpador

struct ProcessResourceTests {
    @Test func readsOwnedProcessAndNeverCarriesUsageAcrossPIDReuse() {
        let own = ProcessResources.read(.init(pid: getpid(), name: "Test"))
        #expect(own.residentBytes != nil)
        #expect(own.start != nil)
        let old = ProcessResource(pid: 123, name: "Old", start: 1, cpuNanoseconds: 100, residentBytes: 1, readBytes: 0, writtenBytes: 0, observedUptime: 100, issue: nil)
        let reused = ProcessResource(pid: 123, name: "New", start: 2, cpuNanoseconds: 200, residentBytes: 1, readBytes: 0, writtenBytes: 0, observedUptime: 200, issue: nil)
        #expect(reused.cpu(since: old) == nil)
        #expect(ProcessResources.read(.init(pid: -1, name: "Invalid")).issue != nil)
    }
}
