package protocol WindowFailureSink: AnyObject {
    func reportWindowFailure(_ failure: WindowFailure)
}

package final class DefaultWindowFailureSink: WindowFailureSink {
    package init() {
        // Stateless fallback used by owner-thread session APIs without an event hub.
    }

    package func reportWindowFailure(_ failure: WindowFailure) {
        guard case .diagnostic = failure else {
            preconditionFailure(failure.description)
        }
    }
}

package final class WeakWindowFailureSink: WindowFailureSink {
    private weak var target: (any WindowFailureSink)?
    private let fallback = DefaultWindowFailureSink()

    package init(_ targetSink: any WindowFailureSink) {
        target = targetSink
    }

    package func reportWindowFailure(_ failure: WindowFailure) {
        guard let target else {
            fallback.reportWindowFailure(failure)
            return
        }

        target.reportWindowFailure(failure)
    }
}

package enum WindowFailure: Equatable, Sendable, CustomStringConvertible {
    case internalInvariant(InternalInvariantViolation)
    case protocolViolation(WaylandProtocolError)
    case lifecycleViolation(WindowID, WindowLifecycleTransitionError)
    case presentationFailure(WindowID, PresentationError)
    case diagnostic(WindowDiagnostic)

    package var description: String {
        switch self {
        case .internalInvariant(let violation):
            violation.description
        case .protocolViolation(let error):
            error.description
        case .lifecycleViolation(let windowID, let transition):
            "Window \(windowID) lifecycle violation: \(transition.description)"
        case .presentationFailure(let windowID, let error):
            "Window \(windowID) presentation failed: \(error.description)"
        case .diagnostic(let diagnostic):
            "Window \(diagnostic.windowID) diagnostic: \(diagnostic.message)"
        }
    }
}
