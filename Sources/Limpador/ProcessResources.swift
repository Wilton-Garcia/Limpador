import Foundation
import Darwin

struct ProcessCandidate: Sendable {
    let pid: Int32
    let name: String
}
struct ProcessResource: Identifiable, Sendable {
    let pid: Int32
    let name: String
    let start: UInt64?
    let cpuNanoseconds: UInt64?
    let residentBytes: UInt64?
    let readBytes: UInt64?
    let writtenBytes: UInt64?
    let observedUptime: UInt64
    let issue: String?
    var id: String { "\(pid):\(start.map(String.init) ?? "unknown")" }
    func cpu(since previous: Self) -> Double? {
        guard pid == previous.pid, let start, start == previous.start,
              let current = cpuNanoseconds, let old = previous.cpuNanoseconds,
              current >= old, observedUptime > previous.observedUptime else { return nil }
        return Double(current - old) / Double(observedUptime - previous.observedUptime)
    }
}

enum ProcessResources {
    static func read(_ candidate: ProcessCandidate) -> ProcessResource {
        var usage = rusage_info_v2()
        let status = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(candidate.pid, RUSAGE_INFO_V2, $0) }
        }
        if status != 0 {
            let issue = POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO).localizedDescription
            return ProcessResource(pid: candidate.pid, name: candidate.name, start: nil, cpuNanoseconds: nil, residentBytes: nil, readBytes: nil, writtenBytes: nil, observedUptime: DispatchTime.now().uptimeNanoseconds, issue: issue)
        }
        return ProcessResource(pid: candidate.pid, name: candidate.name, start: usage.ri_proc_start_abstime,
                               cpuNanoseconds: usage.ri_user_time + usage.ri_system_time, residentBytes: usage.ri_resident_size,
                               readBytes: usage.ri_diskio_bytesread, writtenBytes: usage.ri_diskio_byteswritten,
                               observedUptime: DispatchTime.now().uptimeNanoseconds, issue: nil)
    }
}
