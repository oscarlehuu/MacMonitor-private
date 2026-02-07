import Darwin
import Foundation

struct LibprocProcessListCollector: ProcessListCollecting {
    private let protectionPolicy: ProcessProtecting
    private let currentUserID: uid_t

    init(
        protectionPolicy: ProcessProtecting,
        currentUserID: uid_t = getuid()
    ) {
        self.protectionPolicy = protectionPolicy
        self.currentUserID = currentUserID
    }

    func collectTopProcesses(limit: Int, scope: ProcessScopeMode) throws -> [ProcessMemoryItem] {
        guard limit > 0 else { return [] }

        if scope == .allDiscoverable {
            return try collectAllDiscoverableUsingPS(limit: limit)
        }

        var pids = [pid_t](repeating: 0, count: 4096)
        let bufferBytes = Int32(pids.count * MemoryLayout<pid_t>.stride)
        let bytesWritten = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, bufferBytes)
        guard bytesWritten > 0 else {
            throw ProcessCollectionError.pidEnumerationFailed
        }

        let pidCount = min(Int(bytesWritten) / MemoryLayout<pid_t>.stride, pids.count)
        var items: [ProcessMemoryItem] = []
        items.reserveCapacity(min(limit * 2, pidCount))

        for pid in pids.prefix(pidCount) where pid > 1 {
            guard let record = buildRecord(pid: pid) else { continue }

            if scope == .sameUserOnly, record.userID != currentUserID {
                continue
            }

            items.append(record)
        }

        items.sort {
            if $0.rankingBytes == $1.rankingBytes {
                if $0.name == $1.name {
                    return $0.pid < $1.pid
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.rankingBytes > $1.rankingBytes
        }

        return Array(items.prefix(limit))
    }

    private func collectAllDiscoverableUsingPS(limit: Int) throws -> [ProcessMemoryItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,uid=,rss=,command="]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ProcessCollectionError.pidEnumerationFailed
        }

        // Drain stdout before waiting; waiting first can deadlock if the pipe fills.
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ProcessCollectionError.pidEnumerationFailed
        }

        guard let output = String(data: data, encoding: .utf8) else {
            throw ProcessCollectionError.pidEnumerationFailed
        }

        var items: [ProcessMemoryItem] = []
        items.reserveCapacity(512)

        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(maxSplits: 3, whereSeparator: \.isWhitespace)
            guard parts.count >= 4 else { continue }

            guard let pid = Int32(parts[0]), pid > 1 else { continue }
            guard let uidValue = UInt32(parts[1]) else { continue }
            guard let rssKiB = UInt64(parts[2]) else { continue }

            let command = String(parts[3])
            let name = command.split(separator: "/").last.map(String.init) ?? command
            let userID = uid_t(uidValue)
            let decision = protectionPolicy.evaluate(
                processID: pid,
                userID: userID,
                flags: 0,
                processName: name
            )

            items.append(
                ProcessMemoryItem(
                    pid: pid,
                    name: name.isEmpty ? "pid-\(pid)" : name,
                    userID: userID,
                    userName: userName(for: userID),
                    residentBytes: rssKiB * 1024,
                    footprintBytes: nil,
                    bsdFlags: 0,
                    protectionReason: decision.reason
                )
            )
        }

        items.sort {
            if $0.rankingBytes == $1.rankingBytes {
                if $0.name == $1.name {
                    return $0.pid < $1.pid
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            return $0.rankingBytes > $1.rankingBytes
        }

        return Array(items.prefix(limit))
    }

    private func buildRecord(pid: Int32) -> ProcessMemoryItem? {
        var taskInfo = proc_taskallinfo()
        let bytesRead = withUnsafeMutableBytes(of: &taskInfo) { rawBuffer in
            proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, rawBuffer.baseAddress, Int32(rawBuffer.count))
        }

        guard bytesRead == Int32(MemoryLayout<proc_taskallinfo>.stride) else {
            return nil
        }

        let processName = resolvedName(pid: pid, fallbackName: taskInfo.pbsd.pbi_comm)
        let userID = taskInfo.pbsd.pbi_uid
        let decision = protectionPolicy.evaluate(
            processID: pid,
            userID: userID,
            flags: taskInfo.pbsd.pbi_flags,
            processName: processName
        )

        let footprintBytes = footprintForProcess(pid: pid)

        return ProcessMemoryItem(
            pid: pid,
            name: processName,
            userID: userID,
            userName: userName(for: userID),
            residentBytes: taskInfo.ptinfo.pti_resident_size,
            footprintBytes: footprintBytes,
            bsdFlags: taskInfo.pbsd.pbi_flags,
            protectionReason: decision.reason
        )
    }

    private func resolvedName(pid: Int32, fallbackName: (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)) -> String {
        var nameBuffer = [CChar](repeating: 0, count: 256)
        let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
        if nameLength > 0 {
            let bytes = nameBuffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        }

        let fallback = withUnsafePointer(to: fallbackName) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cStringPtr in
                String(cString: cStringPtr)
            }
        }

        if fallback.isEmpty {
            return "pid-\(pid)"
        }

        return fallback
    }

    private func footprintForProcess(pid: Int32) -> UInt64? {
        var usage = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &usage) { usagePtr in
            usagePtr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, reboundPtr)
            }
        }

        guard result == 0, usage.ri_phys_footprint > 0 else {
            return nil
        }

        return usage.ri_phys_footprint
    }

    private func userName(for userID: uid_t) -> String {
        guard let passwd = getpwuid(userID) else {
            return String(userID)
        }
        return String(cString: passwd.pointee.pw_name)
    }
}
