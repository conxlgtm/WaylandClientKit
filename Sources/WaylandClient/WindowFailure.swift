import WaylandRaw

package protocol WindowFailureSink: AnyObject {
    func reportWindowFailure(_ failure: WindowFailure)
}

package final class DefaultWindowFailureSink: WindowFailureSink {
    package init() {
        // Stateless fallback used by owner-thread session APIs without an event hub.
    }

    package func reportWindowFailure(_ failure: WindowFailure) {
        switch failure {
        case .diagnostic, .presentationFailure:
            return
        case .internalInvariant, .protocolViolation, .lifecycleViolation:
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

package enum WindowFailureClassifier {
    package static func classify(
        windowID: WindowID,
        operation: WindowCallbackOperation,
        error: any Error
    ) -> WindowFailure {
        if let clientError = error as? ClientError {
            return classify(
                windowID: windowID,
                operation: operation,
                clientError: clientError
            )
        }

        if let runtimeError = error as? RuntimeError {
            return classify(
                windowID: windowID,
                operation: operation,
                runtimeError: runtimeError
            )
        }

        return .internalInvariant(
            .unexpectedWindowCallbackError(
                windowID,
                operation: operation,
                detail: String(describing: error)
            )
        )
    }

    private static func classify(
        windowID: WindowID,
        operation: WindowCallbackOperation,
        clientError: ClientError
    ) -> WindowFailure {
        switch clientError {
        case .window(let errorWindowID, let windowError) where errorWindowID == windowID:
            return classify(windowID: windowID, operation: operation, windowError: windowError)
        case .display(.closed):
            return .diagnostic(
                WindowDiagnostic(
                    windowID: windowID,
                    payload: .callback(
                        WindowCallbackDiagnostic(
                            operation: operation,
                            failure: .displayClosed
                        )
                    )
                )
            )
        case .window:
            return .internalInvariant(
                .unexpectedWindowCallbackError(
                    windowID,
                    operation: operation,
                    detail: clientError.description
                )
            )
        default:
            return .internalInvariant(
                .unexpectedWindowCallbackError(
                    windowID,
                    operation: operation,
                    detail: clientError.description
                )
            )
        }
    }

    private static func classify(
        windowID: WindowID,
        operation: WindowCallbackOperation,
        windowError: WindowError
    ) -> WindowFailure {
        switch windowError {
        case .invalidConfigure(let error):
            return classify(windowID: windowID, configureError: error)
        case .invalidLifecycleTransition(let transition):
            return .lifecycleViolation(windowID, transition)
        case .initialConfigureTimedOut:
            return .lifecycleViolation(
                windowID,
                .invalidTransition(from: "callback", event: operation.description)
            )
        case .presentationFailed(let error):
            return .presentationFailure(windowID, error)
        }
    }

    private static func classify(
        windowID: WindowID,
        configureError: WindowConfigureError
    ) -> WindowFailure {
        switch configureError {
        case .negativeSuggestedDimension(let width, let height):
            .protocolViolation(
                .invalidXDGConfigureDimensions(
                    windowID: windowID,
                    width: width,
                    height: height
                )
            )
        case .invalidSerial(let serial):
            .protocolViolation(.invalidConfigureSerial(windowID: windowID, serial: serial))
        case .invalidDecorationMode(let rawValue):
            .protocolViolation(.invalidDecorationMode(rawValue: rawValue))
        case .invalidPreferredBufferScale(let factor):
            .protocolViolation(
                .invalidPreferredBufferScale(windowID: windowID, factor: factor)
            )
        case .invalidFractionalScale(let scale):
            .protocolViolation(
                .invalidFractionalScale(windowID: windowID, numerator: scale)
            )
        case .unrepresentableSurfaceBufferSize(
            let logicalDimension,
            let scaleNumerator,
            let scaleDenominator
        ):
            .protocolViolation(
                .unrepresentableSurfaceBufferSize(
                    windowID: windowID,
                    logicalDimension: logicalDimension,
                    scaleNumerator: scaleNumerator,
                    scaleDenominator: scaleDenominator
                )
            )
        case .unresolvedSize:
            .internalInvariant(
                .effectInterpreterInvariant(windowID, "configure size could not be resolved")
            )
        }
    }

    private static func classify(
        windowID: WindowID,
        operation: WindowCallbackOperation,
        runtimeError: RuntimeError
    ) -> WindowFailure {
        switch runtimeError {
        case .protocolError(let error):
            .protocolViolation(
                .display(
                    interface: error.interfaceName,
                    objectID: error.objectID,
                    code: error.code
                )
            )
        case .proxy(.queueMismatch(let interface, let objectID)):
            .protocolViolation(
                .proxyQueueMismatch(
                    interface: interface,
                    objectID: objectID.map(WaylandProtocolObjectID.init)
                )
            )
        case .invalidDecorationMode(let rawValue):
            .protocolViolation(.invalidDecorationMode(rawValue: rawValue))
        default:
            .internalInvariant(
                .unexpectedWindowCallbackError(
                    windowID,
                    operation: operation,
                    detail: runtimeError.description
                )
            )
        }
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
