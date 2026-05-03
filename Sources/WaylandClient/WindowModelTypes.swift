import WaylandRaw

package enum WindowEvent: Equatable, Sendable {
    case roleObjectsCreated
    case initialCommitSent
    case configureReceived(XDGConfigureSequence)
    case contentInvalidated(bufferAvailable: Bool)
    case frameBecameReady(bufferAvailable: Bool)
    case bufferBecameAvailable(bufferAvailable: Bool)
    case redrawRequestConsumed(bufferAvailable: Bool)
    case presentationStarted(generation: UInt64)
    case presentationBlockedByBuffer
    case presentationSucceeded(generation: UInt64, bufferAvailable: Bool)
    case presentationFailed(generation: UInt64, PresentationError)
    case compositorCloseRequested(policy: CloseRequestPolicy)
    case explicitClose
    case initialConfigureTimedOut(milliseconds: Int32)
    case transientStateReset
}

package enum WindowEffect: Equatable, Sendable {
    case ackConfigure(UInt32)
    case publishCloseRequested(WindowID)
    case publishClosed(WindowID)
    case publishRedrawRequested(WindowID)
    case cancelFrameCallback
    case performSoftwarePresent(PresentationRequest)
    case retireSwapchain
    case destroyRoleObjects
    case destroySurface
}

package struct PresentationRequest: Equatable, Sendable {
    let generation: UInt64
    let configuration: ResolvedWindowConfiguration
}

package enum XDGWindowLifecycle: Equatable, Sendable, CustomStringConvertible {
    case created(CloseRequestState)
    case roleAssigned(CloseRequestState)
    case waitingForInitialConfigure(CloseRequestState)
    case active(ActiveWindowState)
    case closing(ClosingWindowState)
    case destroyed

    package var description: String {
        switch self {
        case .created:
            "created"
        case .roleAssigned:
            "roleAssigned"
        case .waitingForInitialConfigure:
            "waitingForInitialConfigure"
        case .active:
            "active"
        case .closing:
            "closing"
        case .destroyed:
            "destroyed"
        }
    }
}

package struct ActiveWindowState: Equatable, Sendable {
    var configure: ResolvedWindowConfiguration
    var closeRequest = CloseRequestState.none
    var redraw = WindowRedrawState()
    var presentation = WindowPresentationState.idle
}

package enum CloseRequestState: Equatable, Sendable {
    case none
    case requested
}

package enum WindowPresentationState: Equatable, Sendable {
    case idle
    case drawing(generation: UInt64)
}

package enum WindowPublicationState: Equatable, Sendable {
    case notPublished
    case published(WindowID)
    case closedPublished(WindowID)
}

package enum ClosingReason: Equatable, Sendable {
    case explicitClose
    case compositorRequest
    case initializationFailed(WindowError)
    case displayClosing
}

package struct ClosingWindowState: Equatable, Sendable {
    var reason: ClosingReason
}
