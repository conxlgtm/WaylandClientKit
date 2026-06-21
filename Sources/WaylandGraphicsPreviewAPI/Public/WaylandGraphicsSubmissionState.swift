import WaylandClient

package struct WaylandGraphicsFrameLeaseID:
    Equatable,
    Hashable,
    Sendable,
    ExpressibleByIntegerLiteral,
    CustomStringConvertible,
    UInt64WaylandEntityID
{
    package let rawValue: UInt64

    package init(rawValue leaseRawValue: UInt64) {
        rawValue = leaseRawValue
    }

    package init(integerLiteral value: UInt64) {
        self.init(rawValue: value)
    }

    package var description: String {
        "graphics-frame-lease-\(rawValue)"
    }
}

package enum WaylandGraphicsErrorMapper {
    package static func callerDrawError(from error: any Error) -> (any Error)? {
        guard let drawFailure = error as? WindowSoftwareDrawFailure else {
            return nil
        }

        return drawFailure.underlying
    }

    package static func mapWindowLifecycleError(
        _ error: any Error,
        windowID: WindowID
    ) -> WaylandGraphicsError? {
        switch error {
        case ClientError.display(.unknownWindow(let unknownWindowID)):
            guard unknownWindowID == windowID else {
                return nil
            }

            return .windowClosed
        case ClientError.window(
            let thrownWindowID,
            .invalidLifecycleTransition(let transition)
        ):
            guard thrownWindowID == windowID else {
                return nil
            }

            return transition.isManagedGraphicsClosedWindowFailure ? .windowClosed : nil
        default:
            return nil
        }
    }

    package static func mapSubmissionError(
        _ error: any Error,
        windowID: WindowID,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    ) -> WaylandGraphicsError {
        if let lifecycleError = mapWindowLifecycleError(error, windowID: windowID) {
            return lifecycleError
        }

        guard let clientError = error as? ClientError else {
            return .submissionFailed(
                .unexpected(
                    operation: operation,
                    stage: stage,
                    description: String(describing: error)
                )
            )
        }

        return .submissionFailed(
            submissionFailure(
                from: clientError,
                operation: operation,
                stage: stage
            )
        )
    }

    private static func submissionFailure(
        from clientError: ClientError,
        operation: WaylandGraphicsSubmissionOperation?,
        stage: WaylandGraphicsSubmissionStage
    ) -> WaylandGraphicsSubmissionFailure {
        switch clientError {
        case .window(let windowID, .invalidLifecycleTransition(let transition)):
            .windowLifecycle(
                windowID: windowID,
                transition: transition,
                operation: operation,
                stage: stage
            )
        case .window(let windowID, let error):
            .window(
                windowID: windowID,
                error: error,
                operation: operation,
                stage: stage
            )
        case .display(let error):
            .display(error: error, operation: operation, stage: stage)
        default:
            .client(error: clientError, operation: operation, stage: stage)
        }
    }
}

package enum WaylandGraphicsFrameSubmissionOperation: Equatable, Sendable {
    case show
    case redraw

    package var graphicsSubmissionOperation: WaylandGraphicsSubmissionOperation {
        switch self {
        case .show:
            .show
        case .redraw:
            .redraw
        }
    }
}

package struct WaylandGraphicsFrameLeaseState: Equatable, Sendable {
    package enum State: Equatable, Sendable {
        case open(OpenState)
        case submitting(SubmissionState)
        case closed
    }

    package struct OpenState: Equatable, Sendable {
        package var hasSubmittedFrame: Bool
        package var activeLeaseID: WaylandGraphicsFrameLeaseID?
        package var leaseIDGenerator: IDGenerator<WaylandGraphicsFrameLeaseID>

        package init(
            hasSubmittedFrame submitted: Bool = false,
            activeLeaseID leaseID: WaylandGraphicsFrameLeaseID? = nil,
            nextLeaseID nextID: UInt64 = 1
        ) {
            hasSubmittedFrame = submitted
            activeLeaseID = leaseID
            leaseIDGenerator = IDGenerator(startingAt: nextID)
        }

        package init(
            hasSubmittedFrame submitted: Bool,
            activeLeaseID leaseID: WaylandGraphicsFrameLeaseID?,
            leaseIDGenerator nextLeaseIDGenerator: IDGenerator<WaylandGraphicsFrameLeaseID>
        ) {
            hasSubmittedFrame = submitted
            activeLeaseID = leaseID
            leaseIDGenerator = nextLeaseIDGenerator
        }
    }

    package struct SubmissionState: Equatable, Sendable {
        package var hasSubmittedFrame: Bool
        package var leaseIDGenerator: IDGenerator<WaylandGraphicsFrameLeaseID>

        package init(
            hasSubmittedFrame submitted: Bool,
            leaseIDGenerator nextLeaseIDGenerator: IDGenerator<WaylandGraphicsFrameLeaseID>
        ) {
            hasSubmittedFrame = submitted
            leaseIDGenerator = nextLeaseIDGenerator
        }
    }

    package private(set) var state: State

    package init(state initialState: State = .open(OpenState())) {
        state = initialState
    }

    package var isClosed: Bool {
        switch state {
        case .open, .submitting:
            false
        case .closed:
            true
        }
    }

    package var hasSubmittedFrame: Bool {
        switch state {
        case .open(let openState):
            openState.hasSubmittedFrame
        case .submitting(let submissionState):
            submissionState.hasSubmittedFrame
        case .closed:
            false
        }
    }

    package var activeLeaseID: WaylandGraphicsFrameLeaseID? {
        guard case .open(let openState) = state else {
            return nil
        }

        return openState.activeLeaseID
    }

    package func requireNotClosed() throws {
        guard !isClosed else {
            throw WaylandGraphicsError.backingClosed
        }
    }

    package mutating func issueLease() throws -> WaylandGraphicsFrameLeaseID {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .submitting:
            throw WaylandGraphicsError.frameLeaseActive
        case .open(var openState):
            guard openState.activeLeaseID == nil else {
                throw WaylandGraphicsError.frameLeaseActive
            }

            let leaseID = openState.leaseIDGenerator.next()
            openState.activeLeaseID = leaseID
            state = .open(openState)
            return leaseID
        }
    }

    package mutating func prepareSubmission(
        leaseID: WaylandGraphicsFrameLeaseID
    ) throws -> WaylandGraphicsFrameSubmissionOperation {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .submitting:
            throw WaylandGraphicsError.frameLeaseConsumed
        case .open(let openState):
            guard openState.activeLeaseID == leaseID else {
                throw WaylandGraphicsError.frameLeaseConsumed
            }

            let operation: WaylandGraphicsFrameSubmissionOperation
            if openState.hasSubmittedFrame {
                operation = .redraw
            } else {
                operation = .show
            }

            state = .submitting(
                SubmissionState(
                    hasSubmittedFrame: openState.hasSubmittedFrame,
                    leaseIDGenerator: openState.leaseIDGenerator
                )
            )
            return operation
        }
    }

    package func submissionOperation(
        leaseID: WaylandGraphicsFrameLeaseID
    ) throws -> WaylandGraphicsFrameSubmissionOperation {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .submitting:
            throw WaylandGraphicsError.frameLeaseConsumed
        case .open(let openState):
            guard openState.activeLeaseID == leaseID else {
                throw WaylandGraphicsError.frameLeaseConsumed
            }

            return openState.hasSubmittedFrame ? .redraw : .show
        }
    }

    package func requireSubmittable(leaseID: WaylandGraphicsFrameLeaseID) throws {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .submitting:
            throw WaylandGraphicsError.frameLeaseConsumed
        case .open(let openState):
            guard openState.activeLeaseID == leaseID else {
                throw WaylandGraphicsError.frameLeaseConsumed
            }
        }
    }

    package mutating func finishSubmission() throws {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .open:
            throw WaylandGraphicsError.frameLeaseConsumed
        case .submitting(let submissionState):
            state = .open(
                OpenState(
                    hasSubmittedFrame: true,
                    activeLeaseID: nil,
                    leaseIDGenerator: submissionState.leaseIDGenerator
                )
            )
        }
    }

    package mutating func failSubmission() {
        guard case .submitting(let submissionState) = state else {
            return
        }

        state = .open(
            OpenState(
                hasSubmittedFrame: submissionState.hasSubmittedFrame,
                activeLeaseID: nil,
                leaseIDGenerator: submissionState.leaseIDGenerator
            )
        )
    }

    package mutating func cancel(leaseID: WaylandGraphicsFrameLeaseID) -> Bool {
        guard case .open(var openState) = state,
            openState.activeLeaseID == leaseID
        else {
            return false
        }

        openState.activeLeaseID = nil
        state = .open(openState)
        return true
    }

    package mutating func close() {
        state = .closed
    }
}

extension WindowLifecycleTransitionError {
    package var isManagedGraphicsClosedWindowFailure: Bool {
        switch self {
        case .redrawAfterDestroyed,
            .presentWhileClosing,
            .closeAfterDestroyed,
            .presentAfterDestroyed:
            true
        case .mapBeforeInitialConfigure,
            .presentWithoutRedrawRequest,
            .nestedPresentation,
            .inactivePresentationCompletion,
            .presentationRequestMismatch,
            .presentationGenerationMismatch,
            .invalidTransition:
            false
        }
    }
}
