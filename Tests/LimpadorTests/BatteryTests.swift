import Foundation
import IOKit.ps
import Testing
@testable import Limpador

struct BatteryTests {
    @Test func keepsMissingAndInvalidCapacityUnknown() {
        #expect(BatteryMetric.parse([:], index: 0).fraction == nil)
        #expect(BatteryMetric.parse([kIOPSCurrentCapacityKey: 50, kIOPSMaxCapacityKey: 100], index: 0).fraction == 0.5)
        #expect(BatteryMetric.parse([kIOPSCurrentCapacityKey: 50, kIOPSMaxCapacityKey: 0], index: 0).fraction == nil)
        #expect(BatteryMetric.parse([kIOPSTimeToEmptyKey: -1], index: 0).minutesRemaining == nil)
    }
}
