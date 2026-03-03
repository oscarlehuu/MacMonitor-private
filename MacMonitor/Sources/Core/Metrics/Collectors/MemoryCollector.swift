import Darwin
import Foundation

protocol MemoryCollecting {
    func collect() -> MemorySnapshot?
}

struct MemoryCollector: MemoryCollecting {
    static func memoryUsedBytes(totalBytes: UInt64, cachedFilesBytes: UInt64, freeBytes: UInt64) -> UInt64 {
        let reclaimable = min(totalBytes, cachedFilesBytes + freeBytes)
        return totalBytes > reclaimable ? totalBytes - reclaimable : 0
    }

    func collect() -> MemorySnapshot? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let hostPort: mach_port_t = mach_host_self()
        var pageSize: vm_size_t = 0

        let pageSizeResult = host_page_size(hostPort, &pageSize)
        guard pageSizeResult == KERN_SUCCESS, pageSize > 0 else {
            return nil
        }

        let result: kern_return_t = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                host_statistics64(hostPort, HOST_VM_INFO64, reboundPtr, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return nil
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        let internalBytes = UInt64(stats.internal_page_count) * UInt64(pageSize)
        let wiredMemoryBytes = UInt64(stats.wire_count) * UInt64(pageSize)
        let compressedBytes = UInt64(stats.compressor_page_count) * UInt64(pageSize)
        let speculativeBytes = UInt64(stats.speculative_count) * UInt64(pageSize)
        let inactiveBytes = UInt64(stats.inactive_count) * UInt64(pageSize)
        let cachedFilesBytes = min(totalBytes, inactiveBytes + speculativeBytes)
        let freePagesExcludingSpeculative = max(Int64(stats.free_count) - Int64(stats.speculative_count), 0)
        let freeBytes = UInt64(freePagesExcludingSpeculative) * UInt64(pageSize)
        let usedBytes = Self.memoryUsedBytes(
            totalBytes: totalBytes,
            cachedFilesBytes: cachedFilesBytes,
            freeBytes: freeBytes
        )
        let fallbackAppMemoryBytes = usedBytes > wiredMemoryBytes + compressedBytes
            ? usedBytes - wiredMemoryBytes - compressedBytes
            : 0
        let appMemoryBytes = min(
            totalBytes,
            internalBytes > 0 ? internalBytes : fallbackAppMemoryBytes
        )

        let freePages = UInt64(freePagesExcludingSpeculative)
        let totalPages = max(1, UInt64(totalBytes / UInt64(pageSize)))
        let freeRatio = Double(freePages) / Double(totalPages)

        let pressure: MemoryPressureLevel
        switch freeRatio {
        case ..<0.04:
            pressure = .critical
        case ..<0.10:
            pressure = .warning
        default:
            pressure = .normal
        }

        return MemorySnapshot(
            usedBytes: usedBytes,
            totalBytes: totalBytes,
            pressure: pressure,
            inactiveBytes: inactiveBytes,
            compressedBytes: compressedBytes,
            freeBytes: freeBytes,
            appMemoryBytes: appMemoryBytes,
            wiredMemoryBytes: wiredMemoryBytes,
            cachedFilesBytes: cachedFilesBytes,
            swapUsedBytes: swapUsedBytes()
        )
    }

    private func swapUsedBytes() -> UInt64? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = withUnsafeMutablePointer(to: &usage) { usagePtr in
            usagePtr.withMemoryRebound(to: UInt8.self, capacity: size) { bytePtr in
                sysctlbyname("vm.swapusage", bytePtr, &size, nil, 0)
            }
        }

        guard result == 0 else {
            return nil
        }
        return usage.xsu_used
    }
}
