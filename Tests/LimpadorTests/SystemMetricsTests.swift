import Foundation
import Testing
@testable import Limpador

struct SystemMetricsTests {
    @Test func cpuRequiresAnIntervalAndHandlesCounterWrap() {
        let old = CPUTicks(user: 10, system: 10, idle: 50, nice: 0)
        #expect(old.utilization(since: old) == nil)
        #expect(CPUTicks(user: 20, system: 20, idle: 70, nice: 0).utilization(since: old) == 0.5)
        #expect(CPUTicks(user: 1, system: 0, idle: 1, nice: 0).utilization(since: .init(user: UInt32.max, system: 0, idle: 0, nice: 0)) == 2.0 / 3.0)
    }
    @Test func readsKernelMemoryWithoutFabricatingUnavailableValues() throws {
        let memory = try SystemMetrics.memory()
        #expect(memory.physical == ProcessInfo.processInfo.physicalMemory)
        #expect(memory.physical > 0)
        _ = try SystemMetrics.cpu()
    }
}
