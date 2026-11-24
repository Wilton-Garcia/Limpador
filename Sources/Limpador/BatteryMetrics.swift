import Foundation
import IOKit.ps

struct BatteryMetric: Identifiable, Sendable {
    let id: Int
    let name: String
    let fraction: Double?
    let charging: Bool?
    let source: String?
    let health: String?
    let minutesRemaining: Int?

    static func parse(_ facts: [String: Any], index: Int) -> Self {
        let current = (facts[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue
        let maximum = (facts[kIOPSMaxCapacityKey] as? NSNumber)?.doubleValue
        let fraction: Double?
        if let current, let maximum, maximum > 0, current >= 0, current <= maximum { fraction = current / maximum }
        else { fraction = nil }
        let charging = facts[kIOPSIsChargingKey] as? Bool
        let source = facts[kIOPSPowerSourceStateKey] as? String
        let remaining = (facts[kIOPSTimeToEmptyKey] as? NSNumber)?.intValue
        return Self(id: index, name: facts[kIOPSNameKey] as? String ?? "Bateria interna", fraction: fraction, charging: charging,
                    source: source, health: facts[kIOPSBatteryHealthKey] as? String,
                    minutesRemaining: source == kIOPSBatteryPowerValue && charging == false && (remaining ?? 0) > 0 ? remaining : nil)
    }
}

enum BatteryMetrics {
    static func read() throws -> [BatteryMetric] {
        guard let rawInfo = IOPSCopyPowerSourcesInfo() else { throw CocoaError(.fileReadUnknown) }
        let info = rawInfo.takeRetainedValue()
        guard let rawList = IOPSCopyPowerSourcesList(info), let sources = rawList.takeRetainedValue() as? [CFTypeRef] else { throw CocoaError(.fileReadUnknown) }
        var batteries: [BatteryMetric] = []
        for (index, source) in sources.enumerated() {
            guard let raw = IOPSGetPowerSourceDescription(info, source), let facts = raw.takeUnretainedValue() as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
            if facts[kIOPSTypeKey] as? String == kIOPSInternalBatteryType { batteries.append(.parse(facts, index: index)) }
        }
        return batteries
    }
}
