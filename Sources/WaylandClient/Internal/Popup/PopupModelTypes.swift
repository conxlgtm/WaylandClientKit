package enum PopupEvent: Equatable, Sendable {
    case initialCommitSent
    case configureReceived(PopupConfigureSequence)
    case contentInvalidated(bufferAvailability: RedrawBufferAvailability)
    case frameBecameReady(bufferAvailability: RedrawBufferAvailability)
    case bufferBecameAvailable(bufferAvailability: RedrawBufferAvailability)
    case redrawRequestConsumed(bufferAvailability: RedrawBufferAvailability)
    case redrawRequestCanceled(bufferAvailability: RedrawBufferAvailability)
    case presentationStarted(PopupPresentationRequest)
    case presentationBlockedByBuffer
    case softwarePresentationSuperseded(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    )
    case presentationSucceeded(generation: UInt64, bufferAvailability: RedrawBufferAvailability)
    case presentationFailed(generation: UInt64, PresentationError)
    case explicitClose
    case compositorDismissed
    case transientStateReset
}

package enum PopupEffect: Equatable, Sendable {
    case ackConfigure(UInt32)
    case publishDismissed(PopupLifecycleEvent)
    case publishClosed(PopupLifecycleEvent)
    case publishRedrawRequested(PopupLifecycleEvent)
    case cancelFrameCallback
    case performSoftwarePresent(PopupPresentationRequest)
    case retireSwapchain
    case destroyRoleObjects
}

package struct PopupPresentationRequest: Equatable, Sendable {
    package let generation: UInt64
    package let placement: PopupPlacement

    var summary: PopupPresentationRequestSummary {
        PopupPresentationRequestSummary(generation: generation, placement: placement)
    }
}

package typealias PopupPresentationState = PresentationState<PopupPresentationRequest>

package enum PopupLifecycle: Equatable, Sendable, CustomStringConvertible {
    case created
    case waitingForInitialConfigure
    case active(ActivePopupState)
    case destroyed

    package var description: String {
        switch self {
        case .created:
            "created"
        case .waitingForInitialConfigure:
            "waitingForInitialConfigure"
        case .active:
            "active"
        case .destroyed:
            "destroyed"
        }
    }
}

package struct ActivePopupState: Equatable, Sendable {
    package var placement: PopupPlacement
    var redraw = WindowRedrawState()
    package var presentation = PopupPresentationState.idle
}
