import WaylandRaw

package enum WindowEvent: Equatable, Sendable {
    case roleObjectsCreated
    case decorationUnavailable(DecorationUnavailableReason?)
    case decorationObjectCreated(WindowDecorationPreference)
    case decorationPreferenceRequested(WindowDecorationPreference)
    case initialCommitSent
    case published
    case configureReceived(WindowConfigureEvent)
    case contentInvalidated(bufferAvailability: RedrawBufferAvailability)
    case frameBecameReady(bufferAvailability: RedrawBufferAvailability)
    case bufferBecameAvailable(bufferAvailability: RedrawBufferAvailability)
    case redrawRequestConsumed(bufferAvailability: RedrawBufferAvailability)
    case presentationStarted(PresentationRequest)
    case presentationBlockedByBuffer
    case presentationSucceeded(generation: UInt64, bufferAvailability: RedrawBufferAvailability)
    case externalPresentationSucceeded(
        generation: UInt64,
        bufferAvailability: RedrawBufferAvailability
    )
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
    case publishDiagnostic(WindowDiagnostic)
    case cancelFrameCallback
    case performSoftwarePresent(PresentationRequest)
    case retireSwapchain
    case destroyRoleObjects
    case destroySurface
}

package struct PresentationRequest: Equatable, Sendable {
    let generation: UInt64
    let configuration: ResolvedWindowConfiguration

    var summary: WindowPresentationRequestSummary {
        WindowPresentationRequestSummary(
            generation: generation,
            configureSerial: configuration.serial,
            size: configuration.size,
            bounds: configuration.bounds,
            states: configuration.states,
            wmCapabilities: configuration.wmCapabilities,
            decorationMode: configuration.decorationMode
        )
    }
}

package struct PreviewBufferPresentationResult: Equatable, Sendable {
    package let generation: UInt64
    package let commitPlan: SurfaceCommitPlan
    package let capabilities: SurfaceCapabilitySnapshot

    package init(
        generation commitGeneration: UInt64,
        commitPlan surfaceCommitPlan: SurfaceCommitPlan,
        capabilities surfaceCapabilities: SurfaceCapabilitySnapshot
    ) throws(PreviewBufferPresentationResultError) {
        guard commitGeneration > 0 else {
            throw PreviewBufferPresentationResultError.invalidGeneration(commitGeneration)
        }

        generation = commitGeneration
        commitPlan = surfaceCommitPlan
        capabilities = surfaceCapabilities
    }
}

package enum PreviewBufferPresentationResultError: Error, Equatable, Sendable {
    case invalidGeneration(UInt64)
}

package enum PresentationState<Request: Equatable & Sendable>: Equatable, Sendable {
    case idle
    case requested(request: Request)
    case drawing(request: Request)
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

package enum DecorationUnavailableReason: Equatable, Sendable {
    case managerMissing
    case unsupportedManagerVersion(advertised: RawVersion, minimum: RawVersion)

    package var diagnosticMessage: String {
        switch self {
        case .managerMissing:
            "Server-side decoration protocol is unavailable."
        case .unsupportedManagerVersion(let advertised, let minimum):
            "Server-side decoration protocol \(advertised) is unsupported; "
                + "requires \(minimum) or newer."
        }
    }
}

package enum DecorationState: Equatable, Sendable {
    case unavailable(reason: DecorationUnavailableReason?)
    case objectCreated(preference: WindowDecorationPreference)
    case requested(WindowDecorationPreference)
    case configured(WindowDecorationMode)

    var currentMode: WindowDecorationMode {
        switch self {
        case .configured(let mode):
            mode
        case .unavailable, .objectCreated, .requested:
            .unavailable
        }
    }
}

package enum CloseRequestState: Equatable, Sendable {
    case none
    case requested
}

package typealias WindowPresentationState = PresentationState<PresentationRequest>

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
