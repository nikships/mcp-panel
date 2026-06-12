import Foundation

enum ServerHealthStatus: Equatable {
    case unchecked
    case checking
    case reachable(String)
    case authRequired(String)
    case unreachable(String)
    case unsupported(String)

    var message: String {
        switch self {
        case .unchecked:
            return "Not checked"
        case .checking:
            return "Checking..."
        case .reachable(let message),
             .authRequired(let message),
             .unreachable(let message),
             .unsupported(let message):
            return message
        }
    }

    var isFailure: Bool {
        if case .unreachable = self {
            return true
        }
        if case .unsupported = self {
            return true
        }
        return false
    }
}
