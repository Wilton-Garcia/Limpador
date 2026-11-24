import Foundation
import Darwin
import Observation

struct CPUTicks: Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32
    func utilization(since previous: Self) -> Double? {
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system) + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        return total > 0 ? Double(busy) / Double(total) : nil
    }
}
struct MemoryMetrics: Sendable {
    let physical: UInt64
    let active: UInt64
    let wired: UInt64
    let compressed: UInt64
}
struct SystemSample: Sendable {
    let cpu: CPUTicks?
    let memory: MemoryMetrics?
    let disk: DiskSnapshot?
    let batteries: [BatteryMetric]?
    let date: Date
    let issues: [String]
}

enum SystemMetrics {
    static func cpu() throws -> CPUTicks {
        let host = mach_host_self()
        defer { _ = mach_port_deallocate(mach_task_self_, host) }
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count) }
        }
        guard status == KERN_SUCCESS else { throw NSError(domain: NSMachErrorDomain, code: Int(status)) }
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }
    static func memory() throws -> MemoryMetrics {
        let host = mach_host_self()
        defer { _ = mach_port_deallocate(mach_task_self_, host) }
        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let capacity = Int(count)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: capacity) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        var page: vm_size_t = 0
        guard status == KERN_SUCCESS, host_page_size(host, &page) == KERN_SUCCESS else { throw NSError(domain: NSMachErrorDomain, code: Int(status)) }
        return MemoryMetrics(physical: ProcessInfo.processInfo.physicalMemory, active: UInt64(info.active_count) * UInt64(page), wired: UInt64(info.wire_count) * UInt64(page), compressed: UInt64(info.compressor_page_count) * UInt64(page))
    }
    static func sample() -> SystemSample {
        var issues: [String] = []
        var cpu: CPUTicks?, memory: MemoryMetrics?, disk: DiskSnapshot?
        var batteries: [BatteryMetric]?
        do { cpu = try self.cpu() } catch { issues.append("CPU: " + error.localizedDescription) }
        do { memory = try self.memory() } catch { issues.append("Memória: " + error.localizedDescription) }
        do { disk = try DiskSnapshot.read() } catch { issues.append("Disco: " + error.localizedDescription) }
        do { batteries = try BatteryMetrics.read() } catch { issues.append("Bateria: " + error.localizedDescription) }
        return SystemSample(cpu: cpu, memory: memory, disk: disk, batteries: batteries, date: Date(), issues: issues)
    }
}

@MainActor @Observable
final class SystemMonitor {
    var sample: SystemSample?
    var cpuFraction: Double?
    func refresh() async {
        let previous = sample?.cpu
        let next = await Task.detached(priority: .utility) { SystemMetrics.sample() }.value
        guard !Task.isCancelled else { return }
        cpuFraction = next.cpu.flatMap { tick in previous.flatMap { tick.utilization(since: $0) } }
        sample = next
    }
}
