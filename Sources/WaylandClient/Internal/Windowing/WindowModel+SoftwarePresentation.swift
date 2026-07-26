extension WindowModel {
    func isCurrentSoftwarePresentation(_ request: PresentationRequest) -> Bool {
        guard case .active(let activeState) = lifecycle else { return false }

        return activeState.presentation == .drawing(request: request)
            && activeState.configure == request.configuration
            && activeState.redraw.generationForCurrentDraw == request.generation
    }

    mutating func reduceSoftwarePresentationSuperseded(
        _ generation: UInt64,
        _ bufferAvailability: RedrawBufferAvailability
    ) throws -> [WindowEffect] {
        let windowID = id
        return try transitionActiveWindowState { activeState in
            try Self.requireActivePresentation(
                generation: generation,
                in: activeState,
                windowID: windowID
            )
            activeState.presentation = .idle
            return Self.mapRedrawEffects(
                activeState.redraw.supersedeSoftwarePresentation(
                    bufferAvailability: bufferAvailability
                ),
                in: activeState,
                windowID: windowID
            )
        }
    }
}
