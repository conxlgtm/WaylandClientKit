package enum RawInvariantFailure: Equatable, Sendable, CustomStringConvertible {
    case callbackWithoutSwiftState(String)
    case proxyOnWrongQueue(interface: String)
    case globalBindingFailed(interface: String, name: UInt32, reason: String)
    case missingSeatName

    package var description: String {
        switch self {
        case .callbackWithoutSwiftState(let detail):
            detail
        case .proxyOnWrongQueue(let interfaceName):
            "\(interfaceName) proxy is not assigned to the display owner event queue"
        case .globalBindingFailed(let interfaceName, let name, let reason):
            "failed to bind advertised \(interfaceName) global \(name): \(reason)"
        case .missingSeatName:
            "wl_seat name callback did not include a name"
        }
    }
}

package protocol RawInvariantFailureReporter: AnyObject {
    func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure)
}

package final class RawInvariantFailureSink {
    package weak var reporter: (any RawInvariantFailureReporter)?

    package init() {
        // The client failure reporter is installed after DisplayCore exists.
    }

    package func reportFatalRawInvariantFailure(_ failure: RawInvariantFailure) {
        guard let reporter else {
            Self.trapForUnroutedFatalRawInvariantFailure(failure)
        }

        reporter.reportFatalRawInvariantFailure(failure)
    }

    package static func trapForUnroutedFatalRawInvariantFailure(
        _ failure: RawInvariantFailure
    ) -> Never {
        preconditionFailure("SwiftWayland fatal raw invariant: \(failure.description)")
    }
}
