import Darwin
import Foundation

enum ProcessTerminationOutcome: Equatable {
    case terminated
    case skippedProtected(ProcessProtectionReason)
    case permissionDenied
    case notFound
    case failed(errno: Int32)
}

struct ProcessTerminationResult: Equatable {
    let pid: Int32
    let processName: String
    let outcome: ProcessTerminationOutcome

    var isSuccess: Bool {
        if case .terminated = outcome {
            return true
        }
        return false
    }

    var isSkipped: Bool {
        if case .skippedProtected = outcome {
            return true
        }
        return false
    }
}

struct ProcessTerminationSummary: Equatable {
    let results: [ProcessTerminationResult]

    var terminatedCount: Int {
        results.filter(\.isSuccess).count
    }

    var skippedCount: Int {
        results.filter(\.isSkipped).count
    }

    var failedCount: Int {
        results.count - terminatedCount - skippedCount
    }

    var message: String {
        "Terminated \(terminatedCount), skipped \(skippedCount), failed \(failedCount)."
    }
}

protocol ProcessTerminating {
    func terminate(processes: [ProcessMemoryItem], selectedProcessIDs: Set<Int32>) -> ProcessTerminationSummary
}

struct SignalProcessTerminator: ProcessTerminating {
    typealias SignalSender = (_ pid: Int32, _ signal: Int32) -> (result: Int32, errno: Int32)

    private let signalSender: SignalSender

    init(signalSender: @escaping SignalSender = SignalProcessTerminator.defaultSignalSender) {
        self.signalSender = signalSender
    }

    func terminate(processes: [ProcessMemoryItem], selectedProcessIDs: Set<Int32>) -> ProcessTerminationSummary {
        let targets = processes.filter { selectedProcessIDs.contains($0.pid) }

        var results: [ProcessTerminationResult] = []
        results.reserveCapacity(targets.count)

        for process in targets {
            if let reason = process.protectionReason {
                results.append(
                    ProcessTerminationResult(
                        pid: process.pid,
                        processName: process.name,
                        outcome: .skippedProtected(reason)
                    )
                )
                continue
            }

            let signalResult = signalSender(process.pid, SIGTERM)
            if signalResult.result == 0 {
                results.append(
                    ProcessTerminationResult(
                        pid: process.pid,
                        processName: process.name,
                        outcome: .terminated
                    )
                )
                continue
            }

            let outcome: ProcessTerminationOutcome
            switch signalResult.errno {
            case EPERM:
                outcome = .permissionDenied
            case ESRCH:
                outcome = .notFound
            default:
                outcome = .failed(errno: signalResult.errno)
            }

            results.append(
                ProcessTerminationResult(
                    pid: process.pid,
                    processName: process.name,
                    outcome: outcome
                )
            )
        }

        return ProcessTerminationSummary(results: results)
    }

    private static func defaultSignalSender(pid: Int32, signal: Int32) -> (result: Int32, errno: Int32) {
        let result = kill(pid, signal)
        return (result, Darwin.errno)
    }
}
