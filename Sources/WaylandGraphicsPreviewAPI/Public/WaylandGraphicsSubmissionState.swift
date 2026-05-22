import WaylandClient

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
        package var activeLeaseID: UInt64?
        package var nextLeaseID: UInt64

        package init(
            hasSubmittedFrame submitted: Bool = false,
            activeLeaseID leaseID: UInt64? = nil,
            nextLeaseID nextID: UInt64 = 1
        ) {
            hasSubmittedFrame = submitted
            activeLeaseID = leaseID
            nextLeaseID = nextID
        }
    }

    package struct SubmissionState: Equatable, Sendable {
        package var hasSubmittedFrame: Bool
        package var nextLeaseID: UInt64

        package init(hasSubmittedFrame submitted: Bool, nextLeaseID nextID: UInt64) {
            hasSubmittedFrame = submitted
            nextLeaseID = nextID
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

    package var activeLeaseID: UInt64? {
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

    package mutating func issueLease() throws -> UInt64 {
        switch state {
        case .closed:
            throw WaylandGraphicsError.backingClosed
        case .submitting:
            throw WaylandGraphicsError.frameLeaseActive
        case .open(var openState):
            guard openState.activeLeaseID == nil else {
                throw WaylandGraphicsError.frameLeaseActive
            }

            let leaseID = openState.nextLeaseID
            openState.nextLeaseID += 1
            openState.activeLeaseID = leaseID
            state = .open(openState)
            return leaseID
        }
    }

    package mutating func prepareSubmission(
        leaseID: UInt64
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
                    nextLeaseID: openState.nextLeaseID
                )
            )
            return operation
        }
    }

    package func requireSubmittable(leaseID: UInt64) throws {
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
                    nextLeaseID: submissionState.nextLeaseID
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
                nextLeaseID: submissionState.nextLeaseID
            )
        )
    }

    package mutating func cancel(leaseID: UInt64) {
        guard case .open(var openState) = state,
            openState.activeLeaseID == leaseID
        else {
            return
        }

        openState.activeLeaseID = nil
        state = .open(openState)
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
