import Foundation

enum ProcessCollectionError: LocalizedError {
    case pidEnumerationFailed

    var errorDescription: String? {
        switch self {
        case .pidEnumerationFailed:
            return "Unable to enumerate running processes."
        }
    }
}

protocol ProcessListCollecting {
    func collectTopProcesses(limit: Int, scope: ProcessScopeMode) throws -> [ProcessMemoryItem]
}
